#!/bin/bash
# check-proposal-approved.sh — 承認ゲート(PreToolUse フック)
#
# 目的: changes/<name>/design.md・tasks.md への書き込みを、同じ change の
#       proposal.md に承認チェックが記入されるまでブロックする。
#       (AGENTS.md「変更の進め方」の承認ゲートを機械的に強制する)
#
# 設置: .claude/settings.json の hooks.PreToolUse に matcher "Write|Edit" で登録する
#       (設定例はワークスペースの README「hooks — 承認ゲートとシークレット検出」)。
# 入出力: stdin に Claude Code のフック JSON。tool_input.file_path で対象を判定し、
#       対象外パスは exit 0(通す)、承認未記入は exit 2(ブロック。stderr がAIに渡る)。
#
# 互換性: macOS(BSD)/ Linux(GNU)両対応。jq があれば使い、無ければ sed で代替。

set -euo pipefail

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
else
  file_path=$(printf '%s' "$input" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)
fi

# file_path を持たないツール入力は対象外
[ -z "$file_path" ] && exit 0

case "$file_path" in
  */changes/_template/*) exit 0 ;;  # 雛形の編集は対象外
  */changes/*/design.md | */changes/*/tasks.md) ;;
  *) exit 0 ;;
esac

proposal="$(dirname "$file_path")/proposal.md"

if [ ! -f "$proposal" ]; then
  echo "承認ゲート: $proposal がありません。先に proposal を書き、ユーザーの承認を得てください。" >&2
  exit 2
fi

# proposal.md の「- [x] ユーザー承認」が記入済みかを検査
if grep -qE '^[[:space:]]*-[[:space:]]*\[[xX]\][[:space:]]*ユーザー承認' "$proposal"; then
  exit 0
fi

echo "承認ゲート: $proposal の承認チェックが未記入です。ユーザーの承認を得てから design / tasks に進んでください。" >&2
exit 2
