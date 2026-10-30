# R2-01〜R2-03 再々修正の最終確認 — review-fable(Claude Code / Claude Fable 5.1)2026-10-30

- 対象: main の未コミット差分(13 ファイル)。`impl-r3.diff` と作業ツリーの `git diff` は一致(index 行を除き同一)
- 実行したもの: 両層 `hooks-selftest.sh`(`/bin/bash` 3.2.57)→ いずれも **pass=48 fail=0**。両層の 3 スクリプト + 2 設定を `cmp` → 5 組一致。
  `bash -n` 3 本 OK、`git diff --check` クリーン。AGENTS.md: ワークスペース 77 行 / リポジトリ **98 行**
- 追加で: 前回までの自作ケース(22 + 正常経路 7)を再実行 → 変化なし。jq を外した python3 のみの PATH で selftest 全体を実行 → skip 2 件が表示される。
  bad-grep fixture を chmod 無しで再現して bash 3.2 の挙動を追った(下記 R3-01)。コードは変更していない

## A. 前回指摘(R2-01〜R2-03)の確認

| ID | 確認結果 |
|---|---|
| R2-01 | 直っている(ただし残存ギャップ 1 件 → R3-01)。56 行目は `\|\| [ $? -eq 1 ]` で「追加行なし」だけを許し、それ以外は `set -e` → EXIT トラップ。パターン走査は rc を取り、0 = 検出、1 = 不一致、2 以上 = 理由付き exit 2。selftest の 4 ケース(grep 不在 / exit 2 の模擬 grep × Claude Write / apply_patch)は両層で ok。grep 不在(127)と grep exit 2 は実測でも理由付き exit 2 |
| R2-02 | 直っている。保守ルールの 1 行は「## 安全」節の末尾(worktree の項の後)に移り、98 行を維持。nit: 86 行目に空行が 1 つ入り、箇条書きが途中で切れて見える(内容には影響しない。消せば 97 行) |
| R2-03 | 直っている。`JQ_BIN` が空なら「skip … (jq 無し)」を表示して pass/fail に数えない。python3 のみの PATH で実測: skip 2 件が出て、空振りの ok にはならない |

## B. 新しい問題がないか — 正常経路・既存ケースは変化なし

- 正常経路の exit / stderr 行数(未承認 2/1、承認済み 0/0、トークン 2/1、無害 0/0、Bash 0/0、20 万行 0/0)は前回と同一
- 前回の自作 22 ケース(J-04 境界・Unicode・不正 JSON・空入力)も同一結果
- R2-01 の rc 分岐は `exit 2` 経路と `exit 0` 経路のどちらにも余計な出力を足していない(stderr 行数で確認)

## C. 新しい指摘

### R3-01 【P3】PATH 上の grep が「実行不可(Permission denied)」のとき、bash 3.2 では rc=1 と記録され exit 0 で通る
- 場所: `scripts/check-credentials.sh:91-93`(両層同一)、`scripts/hooks-selftest.sh` の bad-grep fixture
- 何が起きるか: `printf … | grep … >/dev/null || rc=$?` は、grep が見つからない(127)・grep が exit 2 を返す場合は rc に 127 / 2 が入り
  期待どおり exit 2 になる。しかし PATH 上の grep が実行権限の無いファイルだった場合、`/bin/bash` 3.2.57 では
  `A || B` の B から見た `$?` が 126 ではなく **1** になる(同じ pipeline を `;` で区切って `echo $?` すると 126。`||` の右辺でだけ 1 に化ける)。
  その結果「不一致」として全パターンを通過し **exit 0**。再現: bad-grep fixture の `chmod +x` を省くと「grep 異常(bad-grep): Claude Write → block」が
  `exit 0(理由なし)` で FAIL する(私の chmod を持たない PATH で偶然発覚。`bash -x` のトレースで `Permission denied` の直後に `rc=1` を確認)。
  発生条件(実行不可の grep が PATH にある)は grep 不在と同程度に非現実的なので重さは P3。ただし「`$?` の値で失敗を分類する」方式は
  bash 3.2 ではこの穴が残る
- 直し方: 値に依存しない事前チェックを 1 行足す(`||` の右辺は「非ゼロだった」ことだけを使うので、この quirk の影響を受けない。実測で exit 2 になることを確認済み):
  ```bash
  printf 'probe' | grep -E -e 'probe' >/dev/null 2>&1 || { echo "シークレット検出: grep が使えないため検査できません。書き込みをブロックします。" >&2; exit 2; }
  ```
  置き場所は patterns の定義直後(走査ループの前)。rc>1 の分岐はそのまま残してよい。selftest には「実行権限の無い grep」fixture を 1 件足す
  (`printf … > "$NX/grep"` のまま chmod しない)。併せて fixture 作成の `chmod +x` が失敗したら中断するようにすると、
  今回のように fixture の意味が黙って変わることを防げる

## D. 総括

- joint の J-01〜J-12、R-01〜R-06、R2-01〜R2-03 はすべて実装済みで、範囲外の変更はない。安全・承認の境目は一貫して閉じる方向にしか動いていない
- 残るのは R3-01(P3)と R2-02 の空行(nit)だけ。どちらも 1〜3 行の追記・削除で済み、コミット前に直すか、learnings / 次回に回すかは template-cc の判断でよい
- 未確認のまま残るもの(前回と同じ): 実 CLI での hook 配送と終了値の扱い、Codex 側の非 2 終了値の解釈。合成テストの成功を実 CLI での有効性の証明とはしない

## 集計

| 重さ | 件 | ID |
|---|---|---|
| P1 | 0 | — |
| P2 | 0 | — |
| P3 | 1 | R3-01 |

再確認 P1=0 P2=0 P3=1
