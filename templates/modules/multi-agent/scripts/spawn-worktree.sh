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

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
cd "$REPO_DIR"

# ------------------------------------------------------------------
# 1. Issueの状態確認とclaim(排他制御)
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

case " $LABELS " in
  *" blocked "*)
    echo "エラー: Issue #$ISSUE_NUMBER は blocked です。依存Issueの完了を待ってください。" >&2
    exit 1
    ;;
  *" in-progress "*)
    echo "エラー: Issue #$ISSUE_NUMBER は既に in-progress(他のエージェントが着手中)です。" >&2
    echo "       本当に自分の担当なら --no-claim ではなく、assigneeを確認してください:" >&2
    echo "       gh issue view $ISSUE_NUMBER --json assignees" >&2
    exit 1
    ;;
esac

# 本文の依存Issueもチェックする。依存付きIssueがtask.md経由で作られた直後は
# blockedラベルがまだ同期されていない(check-blocked.shの次回実行待ち)ことがあるため、
# ラベルだけでなく本文も見る。抽出ロジックは check-blocked.sh の extract_deps と同一に保つこと。
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
    echo "エラー: Issue #$ISSUE_NUMBER は依存Issue #$dep が未完了です(blockedラベルの同期前の可能性があります)。" >&2
    exit 1
  fi
done

if [ "$NO_CLAIM" != "--no-claim" ]; then
  # claim: in-progressラベル+自分をassign。失敗したら(ラベル未作成等)警告して続行。
  # 注意: ラベル確認→付与は非アトミックなので、複数エージェントが全く同時にspawnすると
  # 稀に両方claimが通る。多数エージェントで運用する場合は作業開始前にassigneeが
  # 自分だけであることを確認すること: gh issue view <番号> --json assignees
  if gh issue edit "$ISSUE_NUMBER" --add-label "in-progress" --add-assignee "@me" 2>/dev/null; then
    echo "Issue #$ISSUE_NUMBER をclaimしました(in-progress + assignee)。"
  else
    echo "警告: claim(ラベル/assign)に失敗しました。scripts/setup-labels.sh 実行済みか確認してください。" >&2
  fi
fi

# ------------------------------------------------------------------
# 2. ブランチ名の決定
# ------------------------------------------------------------------
SLUG=$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')
# 日本語のみのタイトル等でslugが空になる場合のフォールバック
[ -z "$SLUG" ] && SLUG="task"

BRANCH="issue-${ISSUE_NUMBER}-${SLUG}"
WORKTREE_DIR="../${REPO_NAME}-issue-${ISSUE_NUMBER}"

# ------------------------------------------------------------------
# 3. worktree作成
# ------------------------------------------------------------------
# 既にworktreeとして登録済みなら何もしない(登録の有無で判定。単なるディレクトリ存在では判定しない)
WT_ABS="$(cd .. && pwd)/${REPO_NAME}-issue-${ISSUE_NUMBER}"
if git worktree list --porcelain | grep -qx "worktree $WT_ABS"; then
  echo "worktree は既に存在します: $WORKTREE_DIR"
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
git rev-parse --verify -q "$BASE" >/dev/null || BASE="$DEFAULT_BRANCH"

if git rev-parse --verify -q "refs/heads/$BRANCH" >/dev/null; then
  # ブランチが既に存在する(前回のworktreeがcleanup済み等) → 再利用する
  echo "ブランチ $BRANCH は既に存在するため再利用します。"
  git worktree add "$WORKTREE_DIR" "$BRANCH"
else
  git worktree add -b "$BRANCH" "$WORKTREE_DIR" "$BASE"
fi

echo "worktree作成完了: $WORKTREE_DIR (branch: $BRANCH, base: $BASE)"
echo ""
echo "次の手順:"
echo "  cd $REPO_DIR/$WORKTREE_DIR"
echo "  # ここでbuilderエージェント(Claude Code等)を起動し、Issue #$ISSUE_NUMBER の作業を開始してください"
echo ""
echo "作業完了後の流れ(AGENTS.md「並列運用」節参照):"
echo "  1. PRを作成し、本文に 'Closes #$ISSUE_NUMBER' を含める"
echo "  2. verifierのレビュー承認後にマージする(Issueはマージで自動closeされる)"
echo "  ※ gh issue close で手動closeしないこと。close = 'コードがmainに入った' を意味させるため。"
