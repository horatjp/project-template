# R-01〜R-06 再修正の再確認 — review-fable(Claude Code / Claude Fable 5.1)2026-10-30

- 対象: main の未コミット差分(13 ファイル)。`impl-r2.diff` と作業ツリーの `git diff` は一致(index 行を除き同一)
- 実行したもの: 両層 `hooks-selftest.sh`(`/bin/bash` 3.2.57)→ いずれも **pass=44 fail=0**。両層の 3 スクリプト + 2 設定を `cmp` → 5 組一致。
  `bash -n` 3 本 OK、`git diff --check` クリーン。AGENTS.md: ワークスペース 77 行 / リポジトリ **98 行**
- 追加で: (a) 前回の自作 22 ケースを再実行、(b) 正常経路(exit 0 / 2)の stderr 行数を EXIT トラップ導入前後で比較、
  (c) jq を外した PATH(python3 のみのマシンの模擬)で selftest 全体を実行。コードは変更していない

## A. 前回指摘(R-01〜R-06)の確認 — すべて直っている

| ID | 確認結果 |
|---|---|
| R-01 | 両ゲートとも `set -euo pipefail` 直後に EXIT トラップ(0/2 以外 → 理由付き exit 2)と空入力の exit 2 が入った。自作ケースで実測: jq あり + 不正 JSON → exit 2 / python3 のみ + 不正 JSON → exit 2 / 空入力 → exit 2、いずれも「検査できないため…ブロックします」を表示。selftest にも両ゲート × 3 の 6 ケースが入り、ゲート修正前に fail=6 を確認した旨が impl.md にある |
| R-02 | ヘッダー 16-18 行目が実挙動(design/tasks の Delete は対象外、同 change の proposal を Add/Update/Move/Delete するパッチは design/tasks をブロック)に一致 |
| R-03 | J-12 の行を「上記に該当しない変更」の後ろへ移動。スペック必須条件 → 「上記に該当しない」が連続する |
| R-04 | 41 行目を折り返し、保守節を 1 行に圧縮して 98 行。ただし置き場所に副作用(下記 R2-02) |
| R-05 | PROJECT.md:23 は「jq または python3(どちらも無いと、編集ツール経由の書き込みがすべてブロックされる)」に短縮 |
| R-06 | selftest に「proposal を Move で退避 + design 更新 → block」「CRLF: proposal 削除 + tasks 更新 → block」を追加。両方 ok |

## B. EXIT トラップが既存の挙動を壊していないか — 壊していない

| 経路 | exit | stderr 行数 | 判定 |
|---|---|---|---|
| 未承認 design への Claude Write | 2 | 1(承認未記入の理由のみ。内部エラー文の重複なし) | ok |
| 承認済み design への Claude Write | 0 | 0 | ok |
| トークンを含む Claude Write | 2 | 1(検出理由のみ) | ok |
| 無害な Claude Write / Bash(file_path 無し) | 0 | 0 | ok |
| 20 万行の無害な Write(SIGPIPE 回帰の経路) | 0 | 0 | ok |
| パーサ無し(両形式)/ Unicode パス・トークン | 2 | 1(「jq または python3」「検査できないため」を含む) | ok |

- トラップは `exit 2` 経路では rc=2 で何もせず、`exit 0` でも何もしない。`$(…)` 内の失敗(normalize_path 等)は親の `set -e` で止まり、親のトラップが 1 回だけ理由を出す。
  コマンド置換のサブシェルには EXIT トラップが継承されないので、二重表示は起きない(実測でも 1 行)
- selftest の理由判定は `*パーサ無し*`(依存表記 + 検査できないため)と `*理由表示*`(検査できないため + ブロック)の 2 段で、R-01 の内部エラー文・空入力文も後者に一致する
- jq を PATH から外し python3 だけにした環境で selftest 全体を実行 → **pass=44 fail=0**(python3 経路が J-03/J-04/R-01 を含め一通り動く)

## C. 新しい指摘(いずれも P3)

### R2-01 【P3】check-credentials.sh は grep 自体のエラーを「不一致」と同一視して exit 0 になる
- 場所: `scripts/check-credentials.sh:56`(`grep -E '^\+' | sed … || true`)、`:91`(`if printf … | grep -E -e "$pattern" >/dev/null; then`)(両層同一)
- 何が起きるか: EXIT トラップは `if` 条件や `|| true` の中の失敗を拾えない(`set -e` の対象外)。grep が無い・実行に失敗する(exit 127 / 2)と、
  91 行目は「一致なし」として全パターンを通過し **exit 0**、56 行目は scan が空になり `[ -z "$scan" ] && exit 0` で **exit 0**。
  私の fixture で grep を欠いた PATH にしたとき、トークン・秘密鍵の全ケースが stderr に `grep: command not found` を出しつつ exit 0 で通った
  (承認ゲート側の `if ! grep -qE` は同条件で「承認未記入」扱いの exit 2 になり、閉じる方向)。
  grep が無い環境は非現実的なので重さは P3 にしたが、R-01 と同じ原則(エラーと不一致を区別する)の取りこぼし
- 直し方: 終了値を取ってから分岐する。例(91 行目):
  ```bash
  rc=0; printf '%s' "$scan" | grep -E -e "$pattern" >/dev/null || rc=$?
  case "$rc" in 0) echo "シークレット検出: …" >&2; exit 2 ;; 1) ;; *) exit "$rc" ;; esac   # 1 以外の失敗はトラップが理由付き exit 2 に変換
  ```
  56 行目は `|| true` を `|| [ $? -eq 1 ]` にする(追加行なし = 1 は正常、それ以外は `set -e` → トラップ)。
  selftest で模擬するなら、ゲート側の PATH だけ grep を外した fixture を 1 件(selftest 自身は grep を使うので全体の PATH は変えない)

### R2-02 【P3】保守ルールの行が「## ワークスペース配下の場合」節の末尾に入っている
- 場所: `templates/repo/AGENTS.md:98`
- 何が起きるか: R-04 で見出し「## このファイルの保守」を削った結果、100 行上限と削除基準の行が、条件付きの節(ワークスペース配下のときだけ読む)の
  最後の段落の直後に置かれた。単体リポジトリで使う読み手がこの節を読み飛ばすと、保守ルールも一緒に落ちる。Markdown 上も段落直後の箇条書きで見出しに属さない
- 直し方: その 1 行を「## 安全」節の末尾(83 行目の worktree の項の後)へ移す(行数は 98 のまま)。見出しを戻す案(100 行)より余裕が残る

### R2-03 【P3・任意】jq が無いマシンでは selftest の「jq のみ」2 ケースが空振りで ok になる
- 場所: `scripts/hooks-selftest.sh:60-66`(`ln -s "$(command -v jq)" "$JQ_ONLY/jq"`)
- 何が起きるか: jq が無いと JQ_ONLY fixture は「パーサ無し」と同じになり、「不正 JSON(jq のみ)→ block(理由表示)」は no-parser の理由文で
  `*理由表示*` 判定を満たして ok になる(python3 のみの PATH で実測。エラー表示も出ない)。jq 経路(exit 5 → トラップ)の回帰は検出されない
- 直し方: `command -v jq` が空なら該当 2 ケースを `skip (jq 無し)` と表示して pass/fail に数えない(python3 は patch_json が必須なので同じ退化は起きない)

## D. 問題なしを確認したその他

- 範囲外の変更なし(13 ファイルは前回と同じ。R-01〜R-06 以外の差分は入っていない)。J-01〜J-12 の内容は前回レビューどおり維持
- 安全・承認を弱めた箇所なし。R-01 で両ゲートはさらに閉じる方向(復号不能・空入力・想定外終了がすべて exit 2)
- 補足: この harness のシェルでは `command -v grep` が関数名 `grep` を返すため、selftest の no-parser fixture の grep symlink が dangling になるが、
  no-parser ケースは grep に到達する前に exit 2 するので結果に影響しない(通常のシェルでは起きない)

## 集計

| 重さ | 件 | ID |
|---|---|---|
| P1 | 0 | — |
| P2 | 0 | — |
| P3 | 3 | R2-01, R2-02, R2-03(任意) |

再確認 P1=0 P2=0 P3=3
