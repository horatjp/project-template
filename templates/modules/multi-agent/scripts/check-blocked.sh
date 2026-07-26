#!/bin/bash
# check-blocked.sh
#
# 目的:
#   1. label "blocked" のIssueについて、本文中の "Depends on: #A, #B" を解析し、
#      依存Issueが全てCLOSEDになっていたら label を blocked -> todo に付け替える。
#   2. 逆方向チェック: label "todo" のIssueの依存が再オープンされていたら
#      todo -> blocked に戻す(再オープン対応の自己修復)。
#
# 使い方: cron等で定期実行する(例: 5分おき)
#   */5 * * * * cd /path/to/repo && ./scripts/check-blocked.sh >> /var/log/check-blocked.log 2>&1
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
# 2. todo -> blocked (依存Issueが再オープンされたものを差し戻す)
# ------------------------------------------------------------------
log "checking reopened dependencies..."

todo_numbers=$(gh issue list --label "todo" --state open --limit "$LIMIT" --json number -q '.[].number')

for issue_number in $todo_numbers; do
  [[ "$issue_number" =~ ^[0-9]+$ ]] || continue

  body=$(gh issue view "$issue_number" --json body -q '.body' 2>/dev/null) || continue

  deps=$(extract_deps "$body")
  [ -z "$deps" ] && continue  # 依存の無いtodoは対象外

  # shellcheck disable=SC2086
  if [ "$(deps_state $deps)" = "open" ]; then
    log "issue #$issue_number: 依存Issueが再オープンされています。blockedに戻します。"
    if gh issue edit "$issue_number" --remove-label "todo" --add-label "blocked"; then
      gh issue comment "$issue_number" --body "警告: 依存Issueが再オープンされたため \`blocked\` に戻しました。既に着手している場合は作業を中断し、人間の判断を仰いでください。" \
        || log "issue #$issue_number: コメント投稿に失敗しました(ラベルは変更済み)。"
    else
      log "issue #$issue_number: ラベル差し戻しに失敗しました。"
    fi
  fi
done

log "done."
