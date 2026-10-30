#!/bin/bash
# check-proposal-approved.sh — 承認ゲート(PreToolUse フック。Claude Code / Codex CLI 共用)
#
# 目的: changes/<name>/design.md・tasks.md への書き込みを、同じ change の
#       proposal.md に承認チェックが記入されるまでブロックする。
#       (AGENTS.md「変更の進め方」の承認ゲートを機械的に強制する)
#
# 設置: Claude Code — .claude/settings.json の hooks.PreToolUse に matcher "Write|Edit"(同梱済み)
#       Codex CLI   — .codex/hooks.json の hooks.PreToolUse に matcher "apply_patch|Edit|Write"(同梱済み。
#                     初回は Codex が hook の信頼確認を求める)
# 入出力: stdin にフック JSON。
#       Claude Code: tool_input.file_path で対象を判定
#       Codex:       tool_name "apply_patch" の tool_input.command(パッチ本文)から、生の行頭
#                    "*** Add File: " / "*** Update File: " / "*** Move to: " のパスを全て抽出し、
#                    hook 入力の cwd を基準に正規化して判定(複数ファイルは全件検査)。
#                    "*** Delete File:" は design/tasks のゲート対象外。
#                    ただし同じ change の proposal.md を Add / Update / Move / Delete するパッチでは、
#                    その change の design/tasks の変更をブロックする(旧承認を根拠にしない)。
#       対象外パスは exit 0(通す)、承認未記入は exit 2(ブロック。stderr がAIに渡る)。
#       承認の根拠は実行前にディスク上にある proposal.md だけ — 同じ編集で承認欄を書くことは根拠にしない。
#
# 互換性: macOS(BSD)/ Linux(GNU)両対応。JSON の解析は jq → python3 の順。どちらも無い場合、
#       両形式とも検査できない理由を表示して exit 2 でブロックする。

set -euo pipefail
# 想定外の終了も hook の非ブロックエラーにせず、検査不能として理由付きで拒否する。
trap 'rc=$?; if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then echo "承認ゲート: 内部エラー(exit $rc)で検査できないため書き込みをブロックします。" >&2; exit 2; fi' EXIT

input=$(cat)
[ -n "$input" ] || {
  echo "承認ゲート: フック入力が空です。検査できないため書き込みをブロックします。" >&2
  exit 2
}

json_get() { # $1: jq フィルタ, $2: 同等の python 式(変数 d が JSON)
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); v=($2); print(v if isinstance(v,str) else '')" 2>/dev/null
  else
    return 1
  fi
}

# 相対パスを base 基準で絶対化し、. と .. を文字列として畳む(存在しないパスでも扱えるように)
normalize_path() { # $1: path, $2: base dir
  local p="$1" base="$2" out=() seg
  case "$p" in /*) ;; *) p="$base/$p" ;; esac
  IFS='/' read -r -a parts <<< "$p"
  for seg in "${parts[@]}"; do
    case "$seg" in
      ""|".") ;;
      "..") [ "${#out[@]}" -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$seg") ;;
    esac
  done
  printf '/%s' "${out[@]}" | sed 's|^//|/|'
  echo
}

# 復号できない入力は検査済みと扱わない。入力形式を問わず同じ依存を要求する。
if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "承認ゲート: JSON を解析できません(jq または python3 が必要)。検査できないため書き込みをブロックします。" >&2
  exit 2
fi
tool_name=$(json_get '.tool_name // empty' "d.get('tool_name','')")

paths=()
proposal_paths=()
if [ "$tool_name" = "apply_patch" ]; then
  patch=$(json_get '.tool_input.command // empty' "d.get('tool_input',{}).get('command','')") || {
    echo "承認ゲート: apply_patch の内容を解析できません(jq または python3 が必要)。検査できないため書き込みをブロックします。jq を導入してください。" >&2
    exit 2
  }
  cwd=$(json_get '.cwd // empty' "d.get('cwd','')" || echo "")
  [ -z "$cwd" ] && cwd=$(pwd)
  # 生の行頭にだけ一致させる(本文の "+*** Update File:" 等はヘッダーではない)。
  # CRLF のパッチは実パーサと同様に末尾の CR を落としてから判定する(design.md\r で素通りさせない)
  while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in
      "*** Add File: "*)    paths+=("$(normalize_path "${line#\*\*\* Add File: }" "$cwd")") ;;
      "*** Update File: "*) paths+=("$(normalize_path "${line#\*\*\* Update File: }" "$cwd")") ;;
      "*** Move to: "*)     paths+=("$(normalize_path "${line#\*\*\* Move to: }" "$cwd")") ;;
      "*** Delete File: "*) proposal_paths+=("$(normalize_path "${line#\*\*\* Delete File: }" "$cwd")") ;;
    esac
  done <<< "$patch"
  # 末尾スラッシュは落とす(dir/ 形式で渡されても design.md には一致しないが、比較を素直にする)
  paths=("${paths[@]%/}")
  # 削除は design/tasks のゲート対象にはしないが、proposal の失効判定には含める。
  proposal_paths=("${proposal_paths[@]-}" "${paths[@]-}")
else
  fp=$(json_get '.tool_input.file_path // empty' "d.get('tool_input',{}).get('file_path','')")
  [ -n "$fp" ] && paths+=("$fp")
fi

# file_path を持たないツール入力・パス無しのパッチは対象外
[ "${#paths[@]}" -eq 0 ] && exit 0

for file_path in "${paths[@]}"; do
  case "$file_path" in
    */changes/_template/*) continue ;;  # 雛形の編集は対象外
    */changes/*/design.md | */changes/*/tasks.md) ;;
    *) continue ;;
  esac

  proposal="$(dirname "$file_path")/proposal.md"

  # 旧承認を根拠にしない: 同一操作で proposal を触るなら、先に変更と再承認を確定させる。
  for changed_path in "${proposal_paths[@]-}"; do
    if [ "$changed_path" = "$proposal" ]; then
      echo "承認ゲート: $proposal と同じ change の design / tasks は同一パッチで変更できません。proposal の変更と再承認を先に確定させてください。" >&2
      exit 2
    fi
  done

  if [ ! -f "$proposal" ]; then
    echo "承認ゲート: $proposal がありません。先に proposal を書き、ユーザーの承認を得てください。" >&2
    exit 2
  fi

  # proposal.md の「- [x] ユーザー承認」が記入済みかを検査
  if ! grep -qE '^[[:space:]]*-[[:space:]]*\[[xX]\][[:space:]]*ユーザー承認' "$proposal"; then
    echo "承認ゲート: $proposal の承認チェックが未記入です。ユーザーの承認を得てから design / tasks に進んでください。" >&2
    exit 2
  fi
done

exit 0
