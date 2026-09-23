#!/bin/bash
# cleanup-worktree.sh
#
# 目的: 完了(closeされた)Issueに紐づくworktreeを一覧・削除する。
#       削除時はブランチも削除し、spawn-worktree.sh での再作成を妨げないようにする。
#
# 使い方:
#   ./scripts/cleanup-worktree.sh           # 削除候補の一覧のみ(作業ツリー・Git参照・GitHub状態を変更しない。
#                                           #  GitHub の Issue 状態は読み取る)
#   ./scripts/cleanup-worktree.sh --force   # 実際に削除する(クリーンなworktreeのみ)。prune と fetch もこのときだけ
#
# 安全装置:
#   - 未コミット変更が残っているworktreeは --force でも削除せずスキップする
#     (Issueが早期closeされた場合の作業データ消失を防ぐ)
#   - needs-human(人間の判断待ち)が付いたIssueは、CLOSEDでも --force でも削除しない
#     (保全・調査のために止めた作業を消さない。判断が記録されラベルが外れてから掃除する)
#   - ラベルを取得できなかったIssueも削除しない(停止中かどうか判定できないため)
#   - ブランチ削除は「デフォルトブランチに統合済み」を証明できたときだけ行う:
#     先端が origin/<default> の祖先(通常マージ)、または先端 == <default> 向けマージ済みPRの head
#     (squash/rebase マージ)。git branch -d は upstream への到達性でも成功するため使わない
#     (PRマージ後にブランチへ積んで push した追加コミットを失わないため)
#   - 強制的に消したい場合は手動で: git worktree remove <path> --force
#
# 互換性: macOS(BSD grep/sed)とLinux(GNU)の両方で動作する。grep -P は使わない。

set -euo pipefail

# 物理パス(pwd -P)で持つ。git worktree list は symlink を解決した実パスを返す
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$REPO_DIR"

FORCE="${1:-}"

if [ -n "$FORCE" ] && [ "$FORCE" != "--force" ]; then
  echo "エラー: 不明なオプション: $FORCE(使えるのは --force のみ)" >&2
  exit 1
fi

# 統合先(デフォルトブランチ)を検出する。spawn-worktree.sh と同じ手順
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || true)
fi
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

TARGET="origin/$DEFAULT_BRANCH"
if [ "$FORCE" = "--force" ]; then
  # 実行時だけ、消えたworktreeの残骸を掃除し、統合先を最新にする(一覧時は参照を変更しない)
  git worktree prune
  git fetch origin "$DEFAULT_BRANCH" >/dev/null 2>&1 || echo "警告: git fetch に失敗しました。手元の origin/$DEFAULT_BRANCH 参照で統合済みを判定します。" >&2
else
  echo "(一覧のみ。手元の参照で見積もる — --force 実行時は fetch して再評価する)"
fi
# 統合済みの証明はリモートの default(origin/<default>)に対してのみ行う。ローカルの <default> には
# 未 push の作業コミットが混ざりうるため、fallback にしない(参照が無ければ祖先判定を使わない)
if ! git rev-parse --verify -q "$TARGET^{commit}" >/dev/null; then
  echo "警告: $TARGET が見つかりません。祖先判定は行わず、マージ済みPRの head 一致だけでブランチ削除を判定します。" >&2
  TARGET=""
fi

# パイプ+whileのサブシェル問題を避けるため、一時変数に展開してから回す。
# パスにスペースが含まれてもよいよう、for+word splittingではなくwhile readを使う。
worktrees=$(git worktree list --porcelain | grep '^worktree ' | sed 's/^worktree //')

while IFS= read -r wt_path; do
  [ -z "$wt_path" ] && continue
  # メインリポジトリ自身はスキップ
  [ "$wt_path" = "$REPO_DIR" ] && continue

  wt_name=$(basename "$wt_path")

  # "<repo>-issue-<N>" 形式のみ対象(grep -P不使用)
  issue_number=$(printf '%s' "$wt_name" | sed -nE 's/.*-issue-([0-9]+)$/\1/p')
  [ -z "$issue_number" ] && continue

  state=$(gh issue view "$issue_number" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
  [ "$state" != "CLOSED" ] && continue

  # 停止フラグの確認。取得できなければ削除対象にしない
  labels=$(gh issue view "$issue_number" --json labels -q '.labels[].name' 2>/dev/null | tr '\n' ' ') || labels="?"
  if [ "$labels" = "?" ]; then
    echo "スキップ: $wt_path (issue #$issue_number のラベルを取得できません。停止中か判定できないため削除しません)"
    continue
  fi
  case " $labels " in
    *" needs-human "*)
      echo "スキップ: $wt_path (issue #$issue_number は needs-human — 人間の判断待ち。ラベルが外れてから掃除します)"
      continue
      ;;
  esac

  # 未コミット変更のチェック(作業データ消失防止)
  dirty=""
  if [ -d "$wt_path" ]; then
    dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null || echo "?")
  fi

  # worktreeのブランチ名を取得(worktree削除後にブランチも消すため)
  branch=$(git -C "$wt_path" symbolic-ref --short HEAD 2>/dev/null || true)

  if [ "$FORCE" = "--force" ]; then
    if [ -n "$dirty" ]; then
      echo "スキップ: $wt_path (issue #$issue_number は CLOSED だが未コミット変更あり)"
      echo "         内容を確認のうえ、必要なら手動で: git worktree remove $wt_path --force"
      continue
    fi
    echo "削除: $wt_path (issue #$issue_number は CLOSED)"
    # 1件の失敗(ロック中・権限等)で残りの掃除を止めない
    if ! git worktree remove "$wt_path"; then
      echo "警告: $wt_path の削除に失敗しました。スキップします。" >&2
      continue
    fi
    # ブランチも削除する(残すとspawn-worktree.shの再作成時に衝突する)。
    # 削除は「$TARGET に統合済み」を証明できたときだけ:
    #   (a) 先端が $TARGET の祖先(通常マージ)
    #   (b) 先端 == $DEFAULT_BRANCH 向けにマージ済みのPRの head(squash/rebase マージ)
    # git branch -d は upstream/HEAD への到達性で成功してしまうため使わない。
    # (b) は PRマージ後にブランチへ積んだコミットがあると一致しないので、そのブランチは残る。
    if [ -n "$branch" ]; then
      branch_tip=$(git rev-parse --verify -q "refs/heads/$branch^{commit}" 2>/dev/null || true)
      reason=""
      if [ -n "$branch_tip" ] && [ -n "$TARGET" ] && git merge-base --is-ancestor "$branch_tip" "$TARGET" 2>/dev/null; then
        reason="$TARGET に統合済み(祖先)"
      elif [ -n "$branch_tip" ]; then
        merged_head=$(gh pr list --head "$branch" --base "$DEFAULT_BRANCH" --state merged --json headRefOid -q '.[0].headRefOid' 2>/dev/null || true)
        [ -n "$merged_head" ] && [ "$branch_tip" = "$merged_head" ] && reason="$DEFAULT_BRANCH 向けマージ済みPRの head と先端が一致(squash/rebase)"
      fi
      if [ -n "$reason" ]; then
        git branch -D "$branch"
        echo "ブランチ削除: $branch ($reason)"
      else
        echo "注意: ブランチ $branch は origin/$DEFAULT_BRANCH への統合を証明できないため残しました(未マージ、またはマージ後に追加コミットあり)。確認のうえ不要なら: git branch -D $branch"
      fi
    fi
  else
    if [ -n "$dirty" ]; then
      echo "削除候補(要注意): $wt_path (issue #$issue_number は CLOSED / 未コミット変更あり — --force でもスキップされます)"
    else
      echo "削除候補: $wt_path (issue #$issue_number は CLOSED) — 実行するには --force を付けてください"
    fi
  fi
done <<< "$worktrees"

echo "done."
