#!/bin/bash
# tests/synthetic.sh — multi-agent スクリプトの合成テスト(gh スタブ + 一時 bare リポジトリ)
#
# 目的: spawn-worktree.sh / cleanup-worktree.sh / check-blocked.sh の分岐を、実 GitHub に
#       触れずに検証する。gh はスタブ(環境変数で応答を制御)、git は一時ディレクトリの
#       bare origin + clone で本物を使う。本物の gh には fallback しない(PATH 先頭に固定)。
#
# 使い方: ./tests/synthetic.sh          # 全ケース実行。失敗があれば exit 1
#         ./tests/synthetic.sh -v       # 各ケースの出力も表示
#
# 対象: このファイルと同じモジュール内の scripts/*.sh(モジュールをリポジトリへ展開した後も
#       <repo>/tests/synthetic.sh として動く。scripts/ が同じ親にあればよい)

set -uo pipefail

# 準備(fixture 作成)の失敗は即終了する。安全境界「一時ディレクトリの中だけで git を動かす」は
# 準備が成功していることに依存するため、set -e に頼らず各段階を明示的に検査する。
die() { echo "テスト準備に失敗: $1" >&2; exit 2; }

VERBOSE="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)" || die "テストディレクトリを解決できない"
SCRIPTS="$(cd "$HERE/../scripts" && pwd)" || die "scripts/ が見つからない($HERE/../scripts)"
REAL_GIT="$(command -v git)" || die "git が無い"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/multi-agent-test.XXXXXX")" || die "mktemp に失敗"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL $1"; [ -n "$2" ] && printf '%s\n' "$2" | sed 's/^/       | /'; }
run()  { # run <label> <expect-exit> <expect-substr-or-empty> -- <cmd...>
  local label="$1" want_exit="$2" want_sub="$3"; shift 3; [ "$1" = "--" ] && shift
  local out; out=$("$@" 2>&1); local got=$?
  [ -n "$VERBOSE" ] && printf '%s\n' "$out" | sed 's/^/       > /'
  if [ "$got" != "$want_exit" ]; then fail "$label (exit $got, want $want_exit)" "$out"; return; fi
  if [ -n "$want_sub" ] && ! printf '%s' "$out" | grep -q -- "$want_sub"; then fail "$label (missing: $want_sub)" "$out"; return; fi
  ok "$label"
}

# ---- gh スタブ: 環境変数で応答を制御 --------------------------------------
mkdir -p "$WORK/bin" || die "bin ディレクトリを作れない"
cat > "$WORK/bin/gh" <<'STUB' || die "gh スタブを書けない"
#!/bin/bash
# GH_STATE (default OPEN) / GH_STATE_<n> (Issue 別) / GH_LABELS / GH_BODY / GH_MERGED_HEAD / GH_EDIT_FAIL
# GH_LIST_BLOCKED / GH_LIST_TODO / GH_LOG(edit 呼び出しを追記)
case "$1 $2" in
  "issue view")
    n="$3"
    case "$*" in *".title"*) echo "Fix Login Bug";; esac
    case "$*" in *".state"*) v="GH_STATE_$n"; echo "${!v:-${GH_STATE:-OPEN}}";; esac
    case "$*" in *".labels[].name"*) [ "${GH_LABELS_FAIL:-0}" = 1 ] && exit 1; printf '%s\n' ${GH_LABELS:-};; esac
    case "$*" in *".body"*) printf '%s\n' "${GH_BODY:-}";; esac ;;
  "issue edit") [ "${GH_EDIT_FAIL:-0}" = 1 ] && exit 1; echo "edit $*" >> "${GH_LOG:-/dev/null}" ;;
  "issue comment") echo "comment $*" >> "${GH_LOG:-/dev/null}" ;;
  "issue list") case "$*" in *blocked*) printf '%s\n' ${GH_LIST_BLOCKED:-};; *todo*) printf '%s\n' ${GH_LIST_TODO:-};; esac ;;
  "pr list") echo "${GH_MERGED_HEAD:-}" ;;
  "repo view") echo "main" ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/gh" || die "gh スタブに実行権限を付けられない"
# git シム: サブコマンドを記録してから本物の git を実行する(一覧モードが fetch/prune を呼ばないことの観測用)
cat > "$WORK/bin/git" <<SHIM || die "git シムを書けない"
#!/bin/bash
[ -n "\${GIT_LOG:-}" ] && printf '%s\n' "\$*" >> "\$GIT_LOG"
exec "$REAL_GIT" "\$@"
SHIM
chmod +x "$WORK/bin/git" || die "git シムに実行権限を付けられない"
export PATH="$WORK/bin:$PATH"
[ "$(command -v gh)" = "$WORK/bin/gh" ] || die "gh スタブが PATH 先頭にない(本物の gh を呼ぶ恐れ)"
export GH_LOG="$WORK/gh.log"

# ---- 一時リポジトリ: bare origin + clone(scripts/ を配置) ------------------
fresh_repo() { # 標準出力に repo パス。準備のどこかが失敗したら非ゼロで返す
  local d="$WORK/case-$RANDOM$RANDOM"
  mkdir -p "$d" || return 1
  git init -q --bare "$d/origin.git" || return 1
  # bare の HEAD を main に固定する(init.defaultBranch が master の環境でも fixture が完結するように)
  git --git-dir "$d/origin.git" symbolic-ref HEAD refs/heads/main || return 1
  git clone -q "$d/origin.git" "$d/repo" 2>/dev/null || return 1
  ( cd "$d/repo" && git config user.email t@t && git config user.name t && git checkout -q -b main \
    && echo a > a && git add a && git commit -qm init && git push -q -u origin main \
    && mkdir scripts && cp "$SCRIPTS"/*.sh scripts/ ) || return 1
  echo "$d/repo"
}
enter_fresh_repo() { # 一時 repo を作ってそこへ移動。失敗したら即終了(元の cwd で git を動かさない)
  R=$(fresh_repo) || die "一時リポジトリの作成に失敗"
  cd "$R" || die "一時リポジトリへ移動できない: $R"
}

echo "spawn-worktree.sh"
enter_fresh_repo; : > "$GH_LOG"
run "needs-human は拒否" 1 "needs-human" -- env GH_LABELS="todo needs-human" ./scripts/spawn-worktree.sh 5
run "依存 Issue が OPEN なら拒否" 1 "依存Issue #2" -- env GH_LABELS="todo" GH_BODY="Depends on: #2" GH_STATE_2=OPEN ./scripts/spawn-worktree.sh 5
run "claim 失敗は停止(worktree を作らない)" 1 "claim" -- env GH_LABELS="todo" GH_EDIT_FAIL=1 ./scripts/spawn-worktree.sh 5
[ "$(git worktree list | wc -l)" -eq 1 ] && ok "  claim 失敗後に worktree が無い" || fail "  claim 失敗後に worktree がある" ""
run "正常: claim して worktree 作成" 0 "worktree作成完了" -- env GH_LABELS="todo" ./scripts/spawn-worktree.sh 5
grep -q "add-label in-progress" "$GH_LOG" && ok "  claim が記録されている" || fail "  claim が記録されていない" ""
run "再実行(in-progress + 既存 worktree)は再開案内" 1 "cd " -- env GH_LABELS="in-progress" ./scripts/spawn-worktree.sh 5
run "再実行でも依存 OPEN なら再開案内を出さない" 1 "依存Issue #2" -- env GH_LABELS="in-progress" GH_BODY="Depends on: #2" GH_STATE_2=OPEN ./scripts/spawn-worktree.sh 5
enter_fresh_repo; git branch issue-6-fix-login-bug && git worktree add -q ../other issue-6-fix-login-bug || die "占有 fixture の準備に失敗"
run "既存ブランチが別 worktree で占有中なら claim 前に停止" 1 "別の worktree" -- env GH_LABELS="todo" ./scripts/spawn-worktree.sh 6

echo "cleanup-worktree.sh"
enter_fresh_repo
git worktree add -q -b issue-5-x ../repo-issue-5 main || die "worktree fixture の準備に失敗"
( cd ../repo-issue-5 && echo x > x && git add x && git commit -qm A && git push -q -u origin issue-5-x ) || die "fixture A の準備に失敗"
A=$(git rev-parse issue-5-x); git merge --squash -q issue-5-x >/dev/null && git commit -qm squash && git push -q origin main || die "squash fixture の準備に失敗"
( cd ../repo-issue-5 && echo y > y && git add y && git commit -qm B && git push -q origin issue-5-x ) || die "fixture B の準備に失敗"
# 一覧モードの副作用検査: origin/main を意図的に古くし(別 clone から push)、prune 対象の消えた worktree も用意する
( cd "$(dirname "$R")" && git clone -q --branch main origin.git other 2>/dev/null && cd other && git config user.email t@t && git config user.name t \
  && echo n > n && git add n && git commit -qm newer && git push -q origin HEAD:main ) || die "古い参照 fixture の準備に失敗"
git worktree add -q -b issue-8-gone ../repo-issue-8 main && rm -rf ../repo-issue-8 || die "stale worktree fixture の準備に失敗"
before=$(git rev-parse origin/main); : > "$WORK/git.log"; export GIT_LOG="$WORK/git.log"
run "引数なしは一覧のみ(CLOSED を候補表示)" 0 "削除候補" -- env GH_STATE=CLOSED GH_LABELS="in-progress" ./scripts/cleanup-worktree.sh
unset GIT_LOG
[ "$(git rev-parse origin/main)" = "$before" ] && [ -d ../repo-issue-5 ] && ok "  一覧で参照・worktree が変わらない" || fail "  一覧で参照または worktree が変わった" ""
grep -Eq "^(fetch|worktree prune)( |$)" "$WORK/git.log" && fail "  一覧モードが fetch/prune を呼んだ" "$(cat "$WORK/git.log")" || ok "  一覧モードは fetch/prune を呼ばない"
git worktree list --porcelain | grep -q "repo-issue-8" && ok "  一覧では stale 登録も残る(prune しない)" || fail "  一覧で stale 登録が消えた" ""
git worktree prune; git branch -D -q issue-8-gone
run "needs-human は --force でも削除しない" 0 "needs-human" -- env GH_STATE=CLOSED GH_LABELS="needs-human" ./scripts/cleanup-worktree.sh --force
run "ラベル取得失敗は削除しない" 0 "取得できません" -- env GH_STATE=CLOSED GH_LABELS_FAIL=1 ./scripts/cleanup-worktree.sh --force
run "squash 後の追加コミットがあるブランチは残す" 0 "残しました" -- env GH_STATE=CLOSED GH_LABELS="in-progress" GH_MERGED_HEAD="$A" ./scripts/cleanup-worktree.sh --force
[ -n "$(git branch --list issue-5-x)" ] && ok "  ブランチが残っている" || fail "  ブランチが消えた" ""
enter_fresh_repo
git worktree add -q -b issue-6-y ../repo-issue-6 main && ( cd ../repo-issue-6 && echo z > z && git add z && git commit -qm Z && git push -q -u origin issue-6-y ) || die "fixture Z の準備に失敗"; Z=$(git rev-parse issue-6-y)
git merge --squash -q issue-6-y >/dev/null && git commit -qm squash6 && git push -q origin main || die "squash6 fixture の準備に失敗"
run "squash で PR head == 先端なら削除" 0 "ブランチ削除" -- env GH_STATE=CLOSED GH_LABELS="in-progress" GH_MERGED_HEAD="$Z" ./scripts/cleanup-worktree.sh --force
enter_fresh_repo
git worktree add -q -b issue-7-w ../repo-issue-7 main && ( cd ../repo-issue-7 && echo w > w && git add w && git commit -qm W ) || die "fixture W の準備に失敗"
git merge -q --no-ff issue-7-w -m merge7 && git push -q origin main || die "merge7 fixture の準備に失敗"
run "通常マージ(origin/main の祖先)なら削除" 0 "統合済み" -- env GH_STATE=CLOSED GH_LABELS="in-progress" ./scripts/cleanup-worktree.sh --force
R="$WORK/noorigin"; mkdir -p "$R" || die "noorigin ディレクトリを作れない"
( cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t && echo a > a && git add a && git commit -qm init && mkdir scripts && cp "$SCRIPTS"/*.sh scripts/ && git worktree add -q -b issue-9-q ../noorigin-issue-9 main && cd ../noorigin-issue-9 && echo q > q && git add q && git commit -qm Q && cd "$R" && git merge -q --no-ff issue-9-q -m m ) || die "noorigin fixture の準備に失敗"
cd "$R" || die "noorigin へ移動できない"
run "origin/<default> が無ければローカル main で判定しない(残す)" 0 "残しました" -- env GH_STATE=CLOSED GH_LABELS="in-progress" ./scripts/cleanup-worktree.sh --force

echo "check-blocked.sh"
enter_fresh_repo; : > "$GH_LOG"
run "needs-human 付き blocked は同期しない" 0 "スキップ" -- env GH_LIST_BLOCKED=7 GH_LABELS="blocked needs-human" GH_BODY="Depends on: #2" GH_STATE_2=CLOSED ./scripts/check-blocked.sh
grep -q "remove-label" "$GH_LOG" && fail "  ラベルが変更された" "" || ok "  ラベル変更なし"
run "依存が全て CLOSED の blocked は todo へ" 0 "todoに付け替え" -- env GH_LIST_BLOCKED=7 GH_LABELS="blocked" GH_BODY="Depends on: #2" GH_STATE_2=CLOSED ./scripts/check-blocked.sh
grep -q "add-label todo" "$GH_LOG" && ok "  todo が付与された" || fail "  todo が付与されていない" ""

echo
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
