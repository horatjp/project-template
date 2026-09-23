#!/bin/bash
# check-blocked.sh
#
# 目的:
#   1. label "blocked" のIssueについて、本文中の "Depends on: #A, #B" を解析し、
#      依存Issueが全てCLOSEDになっていたら label を blocked -> todo に付け替える。
#   2. 逆方向チェック: label "todo" / "in-progress" のIssueの依存が再オープンされていたら
#      blocked に戻す(再オープン対応の自己修復)。in-progress(着手済み)は blocked に加えて
#      needs-human を付け、継続/破棄を人間が判断する(担当・worktree は残る)。
#
# 使い方: cron等で定期実行する(例: 5分おき)
#   */5 * * * * cd /path/to/repo && ./scripts/check-blocked.sh >> /var/log/check-blocked.log 2>&1
#
# 停止フラグ:
#   label "needs-human" が付いたIssueは両方向とも触らない(人間の判断待ち)。
#   人間が判断をコメントに記録してラベルを外したら、このスクリプトを1回手動実行して
#   停止中に変化した依存関係を同期する(workflow は close/reopen でしか起動しないため)。
#
# 前提:
#   - gh CLI がインストール済み・認証済みであること (gh auth login)
#   - ラベル blocked / todo が存在すること (scripts/setup-labels.sh で作成)
#
# 互換性: macOS(BSD grep/sed)とLinux(GNU)の両方で動作する。grep -P は使わない。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

LIMIT=200

# date -I はmacOSの古いBSD dateに無いため、ポータブルなフォーマット指定を使う
log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] $*"; }

# Issue本文から自リポジトリの依存Issue番号を抽出する。
# - "Depends on:" 行(大文字小文字無視)のみを対象にする
# - "owner/repo#12" のようなクロスリポジトリ参照は除外する
# - 出力は改行区切りの数字のみ
extract_deps() {
  # $1: issue body (複数行可)
  printf '%s\n' "$1" \
    | grep -iE '^[[:space:]]*depends[[:space:]]+on[[:space:]]*:' \
    | sed -E 's|[[:alnum:]_.-]+/[[:alnum:]_.-]+#[0-9]+||g' \
    | grep -oE '#[0-9]+' \
    | tr -d '#' \
    | sort -un \
    || true
}

# 依存Issueが全てCLOSEDなら "closed"、そうでなければ "open" を出力
deps_state() {
  # $@: 依存Issue番号のリスト
  local dep state
  for dep in "$@"; do
    state=$(gh issue view "$dep" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
    if [ "$state" != "CLOSED" ]; then
      echo "open"
      return 0
    fi
  done
  echo "closed"
}

# needs-human(人間の判断待ち)は進捗ラベルと直交する停止フラグ。付いている間はラベル同期を止める。
# 取得に失敗したら "?" を返し、呼び出し側はスキップ扱いにする(停止中かどうか判定できないため)。
issue_labels() {
  # $1: issue number → 出力: ラベル名をスペース区切り(先頭・末尾にスペース付き)
  local names
  names=$(gh issue view "$1" --json labels -q '.labels[].name' 2>/dev/null | tr '\n' ' ') || { echo "?"; return 0; }
  printf ' %s ' "$names"
}

is_needs_human() {
  # $1: issue number → 0=停止中(または判定不能)、1=通常
  local labels
  labels=$(issue_labels "$1")
  [ "$labels" = "?" ] && return 0
  case "$labels" in *" needs-human "*) return 0 ;; esac
  return 1
}

# ------------------------------------------------------------------
# 1. blocked -> todo (依存が全て解消したものを着手可能にする)
# ------------------------------------------------------------------
log "checking blocked issues..."

blocked_numbers=$(gh issue list --label "blocked" --state open --limit "$LIMIT" --json number -q '.[].number')

if [ -z "$blocked_numbers" ]; then
  log "no blocked issues."
else
  for issue_number in $blocked_numbers; do
    # 番号はgh CLIのJSON出力からのみ取得しているが、念のため検証する
    [[ "$issue_number" =~ ^[0-9]+$ ]] || { log "skip invalid issue number: $issue_number"; continue; }

    if is_needs_human "$issue_number"; then
      log "issue #$issue_number: needs-human(人間の判断待ち)またはラベル取得不能のため同期をスキップします。"
      continue
    fi

    body=$(gh issue view "$issue_number" --json body -q '.body' 2>/dev/null) || {
      log "issue #$issue_number: 本文の取得に失敗しました。スキップします。"
      continue
    }

    deps=$(extract_deps "$body")
    if [ -z "$deps" ]; then
      log "issue #$issue_number: 依存Issueの記載が見つかりません。スキップします。"
      continue
    fi

    # shellcheck disable=SC2086
    if [ "$(deps_state $deps)" = "closed" ]; then
      log "issue #$issue_number: 依存($(echo $deps | tr ' ' ','))が全てクローズ済み。todoに付け替えます。"
      # ラベル操作の失敗(ラベル未作成・権限不足等)でループ全体を止めない
      if gh issue edit "$issue_number" --remove-label "blocked" --add-label "todo"; then
        gh issue comment "$issue_number" --body "依存Issue(#$(echo $deps | sed 's/ /, #/g'))の完了を確認しました。着手可能です。" \
          || log "issue #$issue_number: コメント投稿に失敗しました(ラベルは変更済み)。"
      else
        log "issue #$issue_number: ラベル付け替えに失敗しました。scripts/setup-labels.sh の実行と権限を確認してください。"
      fi
    else
      log "issue #$issue_number: まだ依存が未完了です。"
    fi
  done
fi

# ------------------------------------------------------------------
# 2. todo / in-progress -> blocked (依存Issueが再オープンされたものを差し戻す)
#    claim 済み(in-progress)の Issue も対象にする — 着手中に依存が再オープンされたら止める必要がある
# ------------------------------------------------------------------
log "checking reopened dependencies..."

# 2つの一覧はそれぞれ取得の成否を検査する(片方の失敗を和集合で握りつぶさない)
todo_list=$(gh issue list --label "todo" --state open --limit "$LIMIT" --json number -q '.[].number') || {
  log "todo 一覧の取得に失敗しました。差し戻しチェックを中止します。"; exit 1; }
inprogress_list=$(gh issue list --label "in-progress" --state open --limit "$LIMIT" --json number -q '.[].number') || {
  log "in-progress 一覧の取得に失敗しました。差し戻しチェックを中止します。"; exit 1; }
todo_numbers=$(printf '%s\n%s\n' "$todo_list" "$inprogress_list" | grep -E '^[0-9]+$' | sort -un || true)

for issue_number in $todo_numbers; do
  [[ "$issue_number" =~ ^[0-9]+$ ]] || continue

  if is_needs_human "$issue_number"; then
    log "issue #$issue_number: needs-human(人間の判断待ち)またはラベル取得不能のため同期をスキップします。"
    continue
  fi

  body=$(gh issue view "$issue_number" --json body -q '.body' 2>/dev/null) || continue

  deps=$(extract_deps "$body")
  [ -z "$deps" ] && continue  # 依存の無いtodoは対象外

  # shellcheck disable=SC2086
  if [ "$(deps_state $deps)" = "open" ]; then
    # 差し戻し直前にラベルを取り直す。取得失敗・needs-human 付与済み・想定外の状態は編集せずスキップ
    # (fail-open にしない: 取得できないものを todo 扱いで blocked にすると in-progress と併存する)
    labels=$(issue_labels "$issue_number")
    if [ "$labels" = "?" ]; then
      log "issue #$issue_number: ラベルの再取得に失敗したため差し戻しをスキップします(次回実行で再評価)。"
      continue
    fi
    case "$labels" in
      *" needs-human "*)
        log "issue #$issue_number: needs-human が付いたため差し戻しをスキップします。"
        continue
        ;;
    esac
    case "$labels" in
      *" in-progress "*)
        # 着手済み: 担当と worktree は残し、blocked + needs-human で人間の判断(継続/破棄)を待つ
        log "issue #$issue_number: 依存Issueが再オープンされました(着手済み)。blocked + needs-human にします。"
        if gh issue edit "$issue_number" --remove-label "in-progress" --add-label "blocked" --add-label "needs-human"; then
          gh issue comment "$issue_number" --body "警告: 依存Issueが再オープンされたため \`blocked\` + \`needs-human\` にしました。着手済みの作業を中断し、継続/破棄を人間が判断してください。判断をコメントに記録して \`needs-human\` を外すと、依存の完了後に todo へ戻ります(再開は spawn-worktree.sh を再実行)。" \
            || log "issue #$issue_number: コメント投稿に失敗しました(ラベルは変更済み)。"
        else
          log "issue #$issue_number: ラベル差し戻しに失敗しました。"
        fi
        ;;
      *" todo "*)
        log "issue #$issue_number: 依存Issueが再オープンされています。blockedに戻します。"
        if gh issue edit "$issue_number" --remove-label "todo" --add-label "blocked"; then
          gh issue comment "$issue_number" --body "警告: 依存Issueが再オープンされたため \`blocked\` に戻しました。" \
            || log "issue #$issue_number: コメント投稿に失敗しました(ラベルは変更済み)。"
        else
          log "issue #$issue_number: ラベル差し戻しに失敗しました。"
        fi
        ;;
      *)
        log "issue #$issue_number: 進捗ラベルが todo / in-progress のいずれでもないため差し戻しをスキップします(現在:$labels)。"
        ;;
    esac
  fi
done

log "done."
