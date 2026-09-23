#!/bin/bash
# spawn-worktree.sh
#
# 目的: GitHub Issue番号を指定して、そのIssue専用のgit worktreeとブランチを作成する。
#       同時に in-progress ラベルと担当者(自分)を付けてIssueをclaimし、
#       複数エージェントが同じIssueを掴む事故を防ぐ。
#
# 使い方:
#   ./scripts/spawn-worktree.sh <issue番号>
#   ./scripts/spawn-worktree.sh <issue番号> --no-claim   # claim(ラベル・assign)を行わない
#
# 例:
#   ./scripts/spawn-worktree.sh 12
#   -> ../repo-issue-12 に worktree を作成し、branch issue-12-<slug> をチェックアウトする
#
# 実行順序(claim 後に失敗して in-progress だけが残る事故を減らすため):
#   Issue の状態確認 → worktree/ブランチ/base の事前確認 → claim → worktree 作成。
#   claim 後に失敗した場合は自動で戻さない(同じ GitHub アカウントを複数AIが使うと
#   自分の claim かどうかを検証できないため)。回収手順を表示するので手動で戻す。
#
# 互換性: macOS(BSD sed)とLinux(GNU)の両方で動作する。

set -euo pipefail

ISSUE_NUMBER="${1:-}"
NO_CLAIM="${2:-}"

if [ -z "$ISSUE_NUMBER" ] || ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <issue番号> [--no-claim]" >&2
  exit 1
fi

# 不明なオプションは黙って無視せずエラーにする(意図しない claim を防ぐ)
if [ -n "$NO_CLAIM" ] && [ "$NO_CLAIM" != "--no-claim" ]; then
  echo "エラー: 不明なオプション: $NO_CLAIM" >&2
  echo "Usage: $0 <issue番号> [--no-claim]" >&2
  exit 1
fi

# 物理パス(pwd -P)で持つ。git worktree list は symlink を解決した実パスを返すため、
# /tmp → /private/tmp のような環境で論理パスと比較すると既存 worktree を見逃す
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
REPO_NAME="$(basename "$REPO_DIR")"
cd "$REPO_DIR"

WORKTREE_DIR="../${REPO_NAME}-issue-${ISSUE_NUMBER}"
WT_ABS="$(cd .. && pwd -P)/${REPO_NAME}-issue-${ISSUE_NUMBER}"

# ------------------------------------------------------------------
# 1. Issueの状態確認(着手してよいか)
# ------------------------------------------------------------------
TITLE=$(gh issue view "$ISSUE_NUMBER" --json title -q '.title') || {
  echo "エラー: Issue #$ISSUE_NUMBER を取得できません。番号と gh auth status を確認してください。" >&2
  exit 1
}
STATE=$(gh issue view "$ISSUE_NUMBER" --json state -q '.state')
LABELS=$(gh issue view "$ISSUE_NUMBER" --json labels -q '.labels[].name' | tr '\n' ' ')

if [ "$STATE" = "CLOSED" ]; then
  echo "エラー: Issue #$ISSUE_NUMBER は既にCLOSEDです。" >&2
  exit 1
fi

# needs-human は進捗ラベル(blocked/todo/in-progress)と直交する停止フラグ。
# 人間が判断をIssueコメントに記録してラベルを外すまで、着手・再開しない。
case " $LABELS " in
  *" needs-human "*)
    echo "エラー: Issue #$ISSUE_NUMBER は needs-human(人間の判断待ち)です。" >&2
    echo "       判断がコメントに記録され、ラベルが外れるまで着手しないでください。" >&2
    exit 1
    ;;
esac

# 本文の依存Issueもチェックする。依存付きIssueがtask.md経由で作られた直後は
# blockedラベルがまだ同期されていない(check-blocked.shの次回実行待ち)ことがあるため、
# ラベルだけでなく本文も見る。抽出ロジックは check-blocked.sh の extract_deps と同一に保つこと。
# in-progress の再開案内より前に行う(依存が再オープンされた作業を再開させないため)。
BODY=$(gh issue view "$ISSUE_NUMBER" --json body -q '.body')
DEPS=$(printf '%s\n' "$BODY" \
  | grep -iE '^[[:space:]]*depends[[:space:]]+on[[:space:]]*:' \
  | sed -E 's|[[:alnum:]_.-]+/[[:alnum:]_.-]+#[0-9]+||g' \
  | grep -oE '#[0-9]+' \
  | tr -d '#' \
  | sort -un \
  || true)
for dep in $DEPS; do
  dep_state=$(gh issue view "$dep" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
  if [ "$dep_state" != "CLOSED" ]; then
    echo "エラー: Issue #$ISSUE_NUMBER は依存Issue #$dep が未完了(または取得不能)です。着手・再開しないでください(blockedラベルの同期前の可能性があります)。" >&2
    exit 1
  fi
done

case " $LABELS " in
  *" blocked "*)
    echo "エラー: Issue #$ISSUE_NUMBER は blocked です。依存Issueの完了を待ってください。" >&2
    exit 1
    ;;
  *" in-progress "*)
    echo "エラー: Issue #$ISSUE_NUMBER は既に in-progress(claim 済み)です。" >&2
    echo "       assignee を確認してください: gh issue view $ISSUE_NUMBER --json assignees" >&2
    if git worktree list --porcelain | grep -qx "worktree $WT_ABS"; then
      echo "       assignee が自分で、作業を再開するなら既存の worktree に戻ってください: cd $WT_ABS" >&2
      echo "       (同じアカウントを複数AIが使う場合、assignee は所有権の保証にならない。担当を人間に確認する)" >&2
    else
      echo "       自分の claim が失敗の残骸なら回収してから再実行: gh issue edit $ISSUE_NUMBER --remove-label in-progress --remove-assignee @me" >&2
    fi
    exit 1
    ;;
esac

# ------------------------------------------------------------------
# 2. ブランチ名の決定と、worktree 作成の事前確認(claim より前に行う)
# ------------------------------------------------------------------
SLUG=$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')
# 日本語のみのタイトル等でslugが空になる場合のフォールバック
[ -z "$SLUG" ] && SLUG="task"

BRANCH="issue-${ISSUE_NUMBER}-${SLUG}"

# 既にworktreeとして登録済みなら何もしない(登録の有無で判定。単なるディレクトリ存在では判定しない)
if git worktree list --porcelain | grep -qx "worktree $WT_ABS"; then
  echo "worktree は既に存在します: $WORKTREE_DIR(再開するなら cd $WT_ABS)"
  exit 0
fi

if [ -e "$WORKTREE_DIR" ]; then
  echo "エラー: $WORKTREE_DIR が存在しますが、worktreeとして登録されていません。" >&2
  echo "       中身を確認して手動で削除するか、git worktree prune を実行してください。" >&2
  exit 1
fi

# デフォルトブランチを検出する(main固定にせず、master等のリポジトリにも対応)
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
if [ -z "$DEFAULT_BRANCH" ]; then
  # origin/HEADが未設定のローカルclone向けフォールバック
  DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || true)
fi
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

# fetchの失敗は握りつぶさず警告する(古いorigin/<default>から分岐するリスクを可視化)
if ! git fetch origin "$DEFAULT_BRANCH"; then
  echo "警告: git fetch に失敗しました。ローカルの origin/$DEFAULT_BRANCH が古い可能性があります。" >&2
fi

BASE="origin/$DEFAULT_BRANCH"
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || BASE="$DEFAULT_BRANCH"

# claim より前に、worktree 作成が成功する条件を確認しておく(事前に分かる失敗で claim を残さない)
REUSE_BRANCH=0
if git rev-parse --verify -q "refs/heads/$BRANCH" >/dev/null; then
  REUSE_BRANCH=1
  if git worktree list --porcelain | grep -qx "branch refs/heads/$BRANCH"; then
    echo "エラー: ブランチ $BRANCH は別の worktree でチェックアウト中です。git worktree list で確認してください。" >&2
    exit 1
  fi
else
  git rev-parse --verify -q "$BASE^{commit}" >/dev/null || {
    echo "エラー: 分岐元 $BASE が見つかりません。git fetch origin $DEFAULT_BRANCH を確認してください。" >&2
    exit 1
  }
fi

# ------------------------------------------------------------------
# 3. claim(排他制御)
# ------------------------------------------------------------------
CLAIMED=0
if [ "$NO_CLAIM" != "--no-claim" ]; then
  # claim: in-progressラベル+自分をassign。失敗したら(ラベル未作成・権限不足等)ここで止める。
  # 注意: ラベル確認→付与は非アトミックなので、複数エージェントが全く同時にspawnすると
  # 稀に両方claimが通る。多数エージェントで運用する場合は作業開始前にassigneeが
  # 自分だけであることを確認すること: gh issue view <番号> --json assignees
  if gh issue edit "$ISSUE_NUMBER" --add-label "in-progress" --add-assignee "@me" 2>/dev/null; then
    CLAIMED=1
    echo "Issue #$ISSUE_NUMBER をclaimしました(in-progress + assignee)。"
  else
    echo "エラー: claim(ラベル/assign)に失敗しました。scripts/setup-labels.sh 実行済みか、権限を確認してください。" >&2
    exit 1
  fi
fi

# ------------------------------------------------------------------
# 4. worktree作成
# ------------------------------------------------------------------
# claim 後に失敗した場合の回収手順(自動では戻さない — 冒頭コメント参照)
recovery_hint() {
  if [ "$CLAIMED" = 1 ]; then
    echo "       Issue #$ISSUE_NUMBER は claim 済み(in-progress + assignee)のままです。作業しないなら回収してください:" >&2
    echo "       gh issue edit $ISSUE_NUMBER --remove-label in-progress --remove-assignee @me" >&2
  fi
}

if [ "$REUSE_BRANCH" = 1 ]; then
  # ブランチが既に存在する(前回のworktreeがcleanup済み等) → 再利用する
  echo "ブランチ $BRANCH は既に存在するため再利用します。"
  git worktree add "$WORKTREE_DIR" "$BRANCH" || { echo "エラー: worktree の作成に失敗しました。" >&2; recovery_hint; exit 1; }
else
  git worktree add -b "$BRANCH" "$WORKTREE_DIR" "$BASE" || { echo "エラー: worktree の作成に失敗しました。" >&2; recovery_hint; exit 1; }
fi

echo "worktree作成完了: $WORKTREE_DIR (branch: $BRANCH, base: $BASE)"
echo ""
echo "次の手順:"
echo "  cd $WT_ABS"
echo "  # ここでbuilderエージェント(Claude Code等)を起動し、Issue #$ISSUE_NUMBER の作業を開始してください"
echo "  # 注意: ワークスペース共有スキルの symlink(.gitignore 済み)は worktree に引き継がれない。"
echo "  #       必要なら <workspace>/.agents/skills/<name>/SKILL.md を直接読ませる"
echo ""
echo "作業完了後の流れ(AGENTS.md「並列運用」節参照):"
echo "  1. PRを作成し、本文に 'Closes #$ISSUE_NUMBER' を含める"
echo "  2. verifierのレビュー承認後にマージする(Issueはマージで自動closeされる)"
echo "  ※ gh issue close で手動closeしないこと。close = 'コードがmainに入った' を意味させるため。"
