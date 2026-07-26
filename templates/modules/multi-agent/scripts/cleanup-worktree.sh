#!/bin/bash
# cleanup-worktree.sh
#
# 目的: 完了(closeされた)Issueに紐づくworktreeを一覧・削除する。
#       削除時はブランチも削除し、spawn-worktree.sh での再作成を妨げないようにする。
#
# 使い方:
#   ./scripts/cleanup-worktree.sh           # 削除候補を一覧表示のみ
#   ./scripts/cleanup-worktree.sh --force   # 実際に削除する(クリーンなworktreeのみ)
#
# 安全装置:
#   - 未コミット変更が残っているworktreeは --force でも削除せずスキップする
#     (Issueが早期closeされた場合の作業データ消失を防ぐ)
#   - 強制的に消したい場合は手動で: git worktree remove <path> --force
#
# 互換性: macOS(BSD grep/sed)とLinux(GNU)の両方で動作する。grep -P は使わない。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

FORCE="${1:-}"

# 消えたworktreeの残骸を先に掃除しておく
git worktree prune

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
    # マージ済みなら -d。squash/rebase mergeはコミットグラフ上マージ済みに見えず
    # -d が失敗するため、PRのマージ状態を確認できたものは -D で削除する。
    # どちらでも確認できないもの(push/merge前など)は残して警告。
    if [ -n "$branch" ]; then
      if git branch -d "$branch" 2>/dev/null; then
        echo "ブランチ削除: $branch"
      else
        merged_prs=$(gh pr list --head "$branch" --state merged --json number -q 'length' 2>/dev/null || echo 0)
        if [ "${merged_prs:-0}" -ge 1 ]; then
          git branch -D "$branch"
          echo "ブランチ削除: $branch (squash/rebase mergeのPRマージ済みを確認)"
        else
          echo "注意: ブランチ $branch は未マージのため残しました。不要なら: git branch -D $branch"
        fi
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
