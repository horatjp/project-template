#!/bin/bash
# 合成テスト: 両 hook を Claude 形式 / Codex apply_patch 形式の入力で検証
set -u
G="$(cd "$(dirname "$0")" && pwd)"; SCRIPTS="${1:-$G}"  # 既定: このファイルと同じ scripts/
T=$(mktemp -d "${TMPDIR:-/tmp}/hooks-test.XXXXXX"); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/changes/foo" "$T/changes/ok" "$T/sub"; printf -- '- [x] ユーザー承認(2026-09-23)\n' > "$T/changes/ok/proposal.md"
PASS=0; FAIL=0
patch_json() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"apply_patch","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$1" "$2"; }
run() { # run <label> <want_exit> <script> <json> [env...]
  local label="$1" want="$2" script="$3" json="$4"; shift 4
  local out got; out=$(printf '%s' "$json" | env "$@" bash "$SCRIPTS/$script" 2>&1); got=$?
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); echo "  ok   $label"; else FAIL=$((FAIL+1)); echo "  FAIL $label (exit $got, want $want)"; printf '%s\n' "$out" | sed 's/^/       | /'; fi
}
A=check-proposal-approved.sh; C=check-credentials.sh; NOPARSER="PATH=/usr/bin:/bin"  # jq/python3 が無い環境の模擬(下で確認)
echo "check-proposal-approved.sh"
run "Update design.md(未承認・相対パス)→ block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/foo/design.md\n@@\n+x\n*** End Patch')"
run "Add tasks.md(承認済み)→ pass" 0 $A "$(patch_json "$T" $'*** Begin Patch\n*** Add File: changes/ok/tasks.md\n+- [ ] 1.\n*** End Patch')"
run "cwd=sub + ../ の正規化 → block" 2 $A "$(patch_json "$T/sub" $'*** Begin Patch\n*** Update File: ../changes/foo/tasks.md\n@@\n+x\n*** End Patch')"
run "本文中の偽ヘッダー(+付き)は無視 → pass" 0 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: notes.md\n@@\n+*** Update File: changes/foo/design.md\n*** End Patch')"
run "Move to design.md(未承認)→ block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: notes.md\n*** Move to: changes/foo/design.md\n@@\n+x\n*** End Patch')"
run "Delete は対象外 → pass" 0 $A "$(patch_json "$T" $'*** Begin Patch\n*** Delete File: changes/foo/design.md\n*** End Patch')"
run "複数ファイル(1件未承認)→ block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/ok/design.md\n@@\n+a\n*** Update File: changes/foo/design.md\n@@\n+b\n*** End Patch')"
run "_template は対象外 → pass" 0 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/_template/design.md\n@@\n+a\n*** End Patch')"
run "同一パッチ内の承認は根拠にしない → block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Add File: changes/foo/proposal.md\n+- [x] ユーザー承認\n*** Update File: changes/foo/design.md\n@@\n+b\n*** End Patch')"
run "Claude Write(未承認)→ block" 2 $A "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/changes/foo/design.md\",\"content\":\"x\"}}"
run "Claude Write(承認済み)→ pass" 0 $A "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/changes/ok/design.md\",\"content\":\"x\"}}"
run "Claude Bash(file_path 無し)→ pass" 0 $A '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
echo "check-credentials.sh"
run "追加行にトークン → block" 2 $C "$(patch_json "$T" $'*** Begin Patch\n*** Update File: a.md\n@@\n+ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123\n*** End Patch')"
run "削除行のトークン(除去修正)→ pass" 0 $C "$(patch_json "$T" $'*** Begin Patch\n*** Update File: a.md\n@@\n-ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123\n+token = env(GITHUB_TOKEN)\n*** End Patch')"
run "文脈行のトークン → pass" 0 $C "$(patch_json "$T" $'*** Begin Patch\n*** Update File: a.md\n@@\n ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123\n+harmless\n*** End Patch')"
run "Add File 本文に秘密鍵 → block" 2 $C "$(patch_json "$T" $'*** Begin Patch\n*** Add File: k.pem\n+-----BEGIN RSA PRIVATE KEY-----\n+abc\n*** End Patch')"
run "Claude Edit old_string のみ → pass" 0 $C '{"tool_name":"Edit","tool_input":{"file_path":"a.md","old_string":"ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123","new_string":"env"}}'
run "Claude Write AWS → block" 2 $C '{"tool_name":"Write","tool_input":{"file_path":"a.md","content":"AKIAJ3XK7QW2ZP9M5T1B"}}'
run "CRLF パッチ: Update design.md(未承認)→ block" 2 $A "$(patch_json "$T" $'*** Begin Patch\r\n*** Update File: changes/foo/design.md\r\n@@\r\n+x\r\n*** End Patch\r\n')"
run "CRLF パッチ: Move to tasks.md(未承認)→ block" 2 $A "$(patch_json "$T" $'*** Begin Patch\r\n*** Update File: n.md\r\n*** Move to: changes/foo/tasks.md\r\n@@\r\n+x\r\n*** End Patch\r\n')"
run "長い入力(先頭にトークン + 10万行)→ block(SIGPIPE 回帰)" 2 $C "$(python3 -c 'import json; body="+ghp_"+"A"*36+"\n"+"+x\n"*100000; print(json.dumps({"tool_name":"apply_patch","cwd":"/tmp","tool_input":{"command":"*** Begin Patch\n*** Add File: big.md\n"+body+"*** End Patch"}}))')"
run "長い入力(末尾にトークン)→ block" 2 $C "$(python3 -c 'import json; body="+x\n"*100000+"+ghp_"+"A"*36+"\n"; print(json.dumps({"tool_name":"apply_patch","cwd":"/tmp","tool_input":{"command":"*** Begin Patch\n*** Add File: big.md\n"+body+"*** End Patch"}}))')"
run "長い入力(Claude Write・先頭にトークン)→ block" 2 $C "$(python3 -c 'import json; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"a.md","content":"ghp_"+"A"*36+"\n"+"x\n"*100000}}))')"
run "Claude Write 既知ダミー(EXAMPLE)→ pass" 0 $C '{"tool_name":"Write","tool_input":{"file_path":"a.md","content":"AKIAIOSFODNN7EXAMPLE"}}'
# パーサ無し環境: jq と python3 を隠す(PATH を最小化)
NP="$T/nopath"; mkdir -p "$NP"; for b in bash grep sed cat dirname head printf env; do p=$(command -v $b) && ln -s "$p" "$NP/$b"; done
run "パーサ無し + apply_patch(承認ゲート)→ block(理由表示)" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: x.md\n@@\n+a\n*** End Patch')" PATH="$NP"
run "パーサ無し + apply_patch(認証情報)→ block(理由表示)" 2 $C "$(patch_json "$T" $'*** Begin Patch\n*** Update File: x.md\n@@\n+a\n*** End Patch')" PATH="$NP"
run "パーサ無し + Claude Write 対象外パス → pass(sed 代替)" 0 $A "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/notes.md\",\"content\":\"x\"}}" PATH="$NP"
run "パーサ無し + Claude Edit(old にトークン)→ 全体走査で block(安全側)" 2 $C '{"tool_name":"Edit","tool_input":{"file_path":"a.md","old_string":"ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123","new_string":"env"}}' PATH="$NP"
echo; echo "pass=$PASS fail=$FAIL"; [ "$FAIL" -eq 0 ]
