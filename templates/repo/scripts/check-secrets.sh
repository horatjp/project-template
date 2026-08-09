#!/bin/bash
# check-secrets.sh — シークレット検出ゲート(PreToolUse フック)
#
# 目的: Write / Edit で書き込もうとしている内容に認証情報らしき文字列
#       (AWSキー・各種APIトークン・秘密鍵ブロック等)が含まれていたらブロックする。
#       (AGENTS.md 安全節「認証情報をどこにも書かない」の Write / Edit 経路の防御層)
#
# 設置: .claude/settings.json の hooks.PreToolUse に matcher "Write|Edit" で登録する(同梱済み)。
# 入出力: stdin に Claude Code のフック JSON。「これから書き込む内容」
#       (Write: content / Edit: new_string / MultiEdit: edits[].new_string)を検査し、
#       検出したら exit 2(ブロック。stderr がAIに渡る)、なければ exit 0。
#       old_string は検査しない — 漏えい済みの値を無害化する置換編集を妨げないため。
# 方針: 誤検知を抑えるため、形式が一意に決まる高確度パターンのみを検出する。
#       汎用の password=... 等は検出しない(そこは AGENTS.md のルールで守る)。
#
# 互換性: macOS(BSD)/ Linux(GNU)両対応。jq があれば使い、無ければ入力全体を走査する
#       (安全側のフォールバック。旧値の置換編集までブロックし得る)。

set -euo pipefail

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  scan=$(printf '%s' "$input" | jq -r \
    '[.tool_input.content?, .tool_input.new_string?, (.tool_input.edits[]?.new_string?)]
     | map(select(. != null)) | join("\n")' 2>/dev/null) || scan=$input
else
  scan=$input
fi

[ -z "$scan" ] && exit 0

# 公式ドキュメントの既知ダミーキーは除外する(例示・テストfixtureをブロックしない)
scan=$(printf '%s' "$scan" | sed -E 's/A(KIA|SIA)IOSFODNN7EXAMPLE//g')

patterns=(
  'A(KIA|SIA)[0-9A-Z]{16}'                # AWS アクセスキーID(長期 AKIA / 一時 ASIA)
  '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}' # GitHub トークン
  'github_pat_[A-Za-z0-9_]{22,}'          # GitHub fine-grained PAT
  'sk-[A-Za-z0-9_-]{32,}'                 # OpenAI / Anthropic 系 APIキー
  '(sk|rk)_live_[0-9a-zA-Z]{20,}'         # Stripe 本番キー
  'x(ox[baprs]|app)-[0-9A-Za-z-]{10,}'    # Slack トークン(bot / user / アプリレベル)
  'AIza[0-9A-Za-z_-]{35}'                 # Google APIキー
  '-----BEGIN( [A-Z]+)* PRIVATE KEY-----' # 秘密鍵ブロック
)

for pattern in "${patterns[@]}"; do
  if printf '%s' "$scan" | grep -qE -e "$pattern"; then
    echo "シークレット検出: 書き込もうとしている内容に認証情報らしき文字列(パターン: $pattern)が含まれています。実値は書かず、環境変数やシークレットマネージャへの参照に置き換えてください。" >&2
    exit 2
  fi
done

exit 0
