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
  # 理由表示ケースは終了値だけでなく、依存と拒否理由も検証する。
  case "$label" in
    *パーサ無し*) if ! [[ "$out" == *'jq または python3'* && "$out" == *'検査できないため'* ]]; then got="${got}(理由なし)"; fi ;;
    *理由表示*) if ! [[ "$out" == *'検査できないため'* && "$out" == *'ブロック'* ]]; then got="${got}(理由なし)"; fi ;;
  esac
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
# J-04: ディスク上が承認済みでも、同じパッチ内の proposal 更新とは併用できない
run "同一パッチ内で承認解除 + design 更新 → block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/ok/proposal.md\n@@\n-- [x] ユーザー承認(2026-09-23)\n+- [ ] ユーザー承認\n*** Update File: changes/ok/design.md\n@@\n+b\n*** End Patch')"
run "同一パッチ内で tasks 更新 + proposal 削除 → block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/ok/tasks.md\n@@\n+b\n*** Delete File: changes/ok/proposal.md\n*** End Patch')"
run "別 change の proposal 更新 + 承認済み design 更新 → pass" 0 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/foo/proposal.md\n@@\n+x\n*** Update File: changes/ok/design.md\n@@\n+b\n*** End Patch')"
# R-06: proposal の Move 元と、CRLF の Delete も旧承認の根拠にできない。
run "proposal を Move で退避 + design 更新 → block" 2 $A "$(patch_json "$T" $'*** Begin Patch\n*** Update File: changes/ok/proposal.md\n*** Move to: changes/ok/old-proposal.md\n@@\n+x\n*** Update File: changes/ok/design.md\n@@\n+b\n*** End Patch')"
run "CRLF: proposal 削除 + tasks 更新 → block" 2 $A "$(patch_json "$T" $'*** Begin Patch\r\n*** Delete File: changes/ok/proposal.md\r\n*** Update File: changes/ok/tasks.md\r\n@@\r\n+b\r\n*** End Patch\r\n')"
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
run "パーサ無し + Claude Write 対象外パス → block(理由表示)" 2 $A "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/notes.md\",\"content\":\"x\"}}" PATH="$NP"
run "パーサ無し + Claude Edit(old にトークン)→ block(理由表示)" 2 $C '{"tool_name":"Edit","tool_input":{"file_path":"a.md","old_string":"ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123","new_string":"env"}}' PATH="$NP"
# Unicode エスケープは JSON の復号後に判定する必要がある(合成入力)。
ESC_PATH="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$T/changes/foo/\\u0064esign.md\",\"content\":\"x\"}}"
ESC_TOKEN='{"tool_name":"Write","tool_input":{"file_path":"a.md","content":"\u0067hp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij0123"}}'
run "Unicode パス + パーサあり → block" 2 $A "$ESC_PATH"
run "Unicode トークン + パーサあり → block" 2 $C "$ESC_TOKEN"
run "Unicode パス + パーサ無し → block(理由表示)" 2 $A "$ESC_PATH" PATH="$NP"
run "Unicode トークン + パーサ無し → block(理由表示)" 2 $C "$ESC_TOKEN" PATH="$NP"
run "パーサ無し + Claude Write 無害な内容 → block(理由表示)" 2 $C '{"tool_name":"Write","tool_input":{"file_path":"a.md","content":"harmless"}}' PATH="$NP"
# R-01: jq / python3 各経路の復号失敗と、空入力を両ゲートで検証する。
JQ_ONLY="$T/jq-only"; PY_ONLY="$T/python-only"; mkdir -p "$JQ_ONLY" "$PY_ONLY"
for b in bash grep sed cat dirname head printf env; do
  p=$(command -v "$b") && ln -s "$p" "$JQ_ONLY/$b" && ln -s "$p" "$PY_ONLY/$b"
done
JQ_BIN=$(command -v jq || true)
[ -z "$JQ_BIN" ] || ln -s "$JQ_BIN" "$JQ_ONLY/jq"
ln -s "$(command -v python3)" "$PY_ONLY/python3"
for gate in "$A" "$C"; do
  if [ -n "$JQ_BIN" ]; then
    run "$gate: 不正 JSON(jq のみ) → block(理由表示)" 2 "$gate" '{invalid' PATH="$JQ_ONLY"
  else
    echo "  skip $gate: 不正 JSON(jq のみ) (jq 無し)"
  fi
  run "$gate: 不正 JSON(python3 のみ) → block(理由表示)" 2 "$gate" '{invalid' PATH="$PY_ONLY"
  run "$gate: 空入力 → block(理由表示)" 2 "$gate" ''
done
# R2-01: grep の不在・実行エラーを、パターン不一致と区別する。
NO_GREP="$T/no-grep"; BAD_GREP="$T/bad-grep"; mkdir -p "$NO_GREP" "$BAD_GREP"
for b in bash sed cat dirname env python3; do
  p=$(command -v "$b") && ln -s "$p" "$NO_GREP/$b" && ln -s "$p" "$BAD_GREP/$b"
done
printf '#!/bin/bash\nexit 2\n' > "$BAD_GREP/grep"; chmod +x "$BAD_GREP/grep"
for grep_path in "$NO_GREP" "$BAD_GREP"; do
  run "grep 異常($grep_path): Claude Write → block(理由表示)" 2 "$C" '{"tool_name":"Write","tool_input":{"content":"harmless"}}' PATH="$grep_path"
  run "grep 異常($grep_path): apply_patch → block(理由表示)" 2 "$C" "$(patch_json "$T" $'*** Begin Patch\n*** Add File: a.md\n+harmless\n*** End Patch')" PATH="$grep_path"
done
echo; echo "pass=$PASS fail=$FAIL"; [ "$FAIL" -eq 0 ]
