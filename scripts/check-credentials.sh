#!/bin/bash
# check-credentials.sh — シークレット検出ゲート(PreToolUse フック。Claude Code / Codex CLI 共用)
#
# 目的: これから書き込む内容に認証情報らしき文字列(AWSキー・各種APIトークン・秘密鍵ブロック等)が
#       含まれていたらブロックする(AGENTS.md 安全節「認証情報をどこにも書かない」の編集経路の防御層)。
#
# 設置: Claude Code — .claude/settings.json の hooks.PreToolUse に matcher "Write|Edit"(同梱済み)
#       Codex CLI   — .codex/hooks.json の hooks.PreToolUse に matcher "apply_patch|Edit|Write"(同梱済み。
#                     初回は Codex が hook の信頼確認を求める)
# 入出力: stdin にフック JSON。検査対象は「今回持ち込む内容」だけ:
#       Claude Code: Write の content / Edit の new_string / MultiEdit の edits[].new_string
#       Codex:       tool_name "apply_patch" の tool_input.command(パッチ本文)のうち追加行(先頭 "+")
#       old_string や削除行(-)・文脈行は検査しない — 漏えい済みの値を除去する編集を妨げないため。
#       検出したら exit 2(ブロック。stderr がAIに渡る)、なければ exit 0。
# 方針: 誤検知を抑えるため、形式が一意に決まる高確度パターンのみを検出する。
#       汎用の password=... 等は検出しない(そこは AGENTS.md のルールで守る)。
#       シェル等の別経路(echo > file 等)は対象外 — 完全な防壁ではなく編集ツール経路の補助。
#
# 互換性: macOS(BSD)/ Linux(GNU)両対応。JSON の解析は jq → python3 の順で使う。
#       どちらも無い場合: Claude 形式は入力全体を走査(安全側。旧値の置換編集までブロックし得る)、
#       apply_patch 形式は追加行だけを取り出せないため、理由を表示してブロックする(検査不能≠対象外)。

set -euo pipefail

input=$(cat)

# --- JSON から必要なフィールドを取り出す(jq → python3) --------------------------------
json_get() { # $1: jq フィルタ, $2: 同等の python 式(変数 d が JSON)。取り出せなければ非ゼロ
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); v=($2); print(v if isinstance(v,str) else '')" 2>/dev/null
  else
    return 1
  fi
}

# パーサが無くても tool_name だけは生の JSON から拾う(apply_patch を Claude 形式と誤認しないため)
tool_name=$(json_get '.tool_name // empty' "d.get('tool_name','')") \
  || tool_name=$(printf '%s' "$input" | sed -nE 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)

if [ "$tool_name" = "apply_patch" ]; then
  patch=$(json_get '.tool_input.command // empty' "d.get('tool_input',{}).get('command','')") || {
    echo "シークレット検出: apply_patch の内容を解析できません(jq または python3 が必要)。検査できないため書き込みをブロックします。jq を導入してください。" >&2
    exit 2
  }
  # 追加行(先頭 "+")だけを検査。ファイル追加(*** Add File)の本文も "+" 行で表現される
  scan=$(printf '%s\n' "$patch" | grep -E '^\+' | sed -E 's/^\+//' || true)
else
  # Claude Code 形式
  if command -v jq >/dev/null 2>&1; then
    scan=$(printf '%s' "$input" | jq -r \
      '[.tool_input.content?, .tool_input.new_string?, (.tool_input.edits[]?.new_string?)]
       | map(select(. != null)) | join("\n")' 2>/dev/null) || scan=$input
  elif command -v python3 >/dev/null 2>&1; then
    scan=$(printf '%s' "$input" | python3 -c '
import json,sys
d=json.load(sys.stdin); t=d.get("tool_input",{}) or {}
parts=[t.get("content"), t.get("new_string")] + [e.get("new_string") for e in (t.get("edits") or [])]
print("\n".join(p for p in parts if isinstance(p,str)))' 2>/dev/null) || scan=$input
  else
    scan=$input
  fi
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

# grep -q は一致した時点で終了し、長い入力では printf が SIGPIPE(141)になってパイプ全体が
# 非ゼロ → 検出しても通してしまう。出力を捨てる形で全入力を消費させる(pipefail 下でも安全)
for pattern in "${patterns[@]}"; do
  if printf '%s' "$scan" | grep -E -e "$pattern" >/dev/null; then
    echo "シークレット検出: 書き込もうとしている内容に認証情報らしき文字列(パターン: $pattern)が含まれています。実値は書かず、環境変数やシークレットマネージャへの参照に置き換えてください。" >&2
    exit 2
  fi
done

exit 0
