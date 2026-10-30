# J-01〜J-12 実装レビュー — review-fable(Claude Code / Claude Fable 5.1)2026-10-30

- 対象: main の未コミット差分(13 ファイル)。`impl.diff` と作業ツリーの `git diff` は一致(index 行を除き同一)
- 実行したもの: 両層 `hooks-selftest.sh`(`/bin/bash` 3.2.57)→ いずれも **pass=36 fail=0**。両層の 3 スクリプト + 2 設定を `cmp` → 5 組とも一致。
  `git diff --check` → 問題なし。AGENTS.md 行数: ワークスペース 77 / リポジトリ **100**(上限ちょうど)
- 追加で、selftest に無い 22 ケースの合成入力を自作して走らせた(結果は末尾 §C)。コードは変更していない
- 重さの定義は joint.md と同じ(P1 直ちに重大 / P2 特定条件で承認・安全の契約が破れる / P3 局所的な不整合・文書改善)

## A. 指摘

### R-01 【P2】パーサがあっても復号できない入力・空入力が「理由なしの exit 1/5」または「exit 0」で終わり、Claude Code では書き込みが続行される
- 場所: `scripts/check-proposal-approved.sh:53-58`、`scripts/check-credentials.sh:37-42`(両層同一)、`scripts/hooks-selftest.sh`(未カバー)
- 何が起きるか: J-03 で足した早期終了は「jq も python3 も無い」場合だけを止める。パーサがあって JSON を復号できないとき、
  `tool_name=$(json_get …)` が非ゼロになり `set -e` で即終了する。結果(実測):
  - jq 1.8.1 あり + 不正 JSON → **exit 5、stderr 空**(承認ゲート・シークレット検出とも)
  - python3 のみ + 不正 JSON → **exit 1、stderr 空**
  - 空入力 → **exit 0**(jq が空入力に何も出さず正常終了するため、対象外として通る)
  Claude Code の hook は exit 2 だけがブロックで、それ以外の非ゼロは「非ブロックのエラー(stderr を表示して続行)」(公式ドキュメントの記述。
  **要確認**: 現行版での再確認と Codex 側の扱いは未検証)。つまりこの経路では、スクリプト内コメントの「復号できない入力は検査済みと扱わない」が
  成り立たず、しかも理由が一切表示されない。不正 JSON は通常ハーネスから来ないが、同じ経路は bash 3.2 の unbound 変数など
  想定外の失敗すべてに共通で、J-03 が掲げた「検査不能 ≠ 対象外」の契約が実装で閉じていない。
- 直し方(bash 3.2 で動作確認済みのパターン):
  1. 両スクリプトの `set -euo pipefail` 直後に EXIT トラップを置き、0 と 2 以外の終了を理由付き exit 2 に変換する:
     ```bash
     trap 'rc=$?; if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then echo "承認ゲート: 内部エラー(exit $rc)のため検査できません。書き込みをブロックします。" >&2; exit 2; fi' EXIT
     ```
     (check-credentials.sh は接頭辞を「シークレット検出:」に)
  2. `input=$(cat)` の直後に空入力を止める: `[ -n "$input" ] || { echo "…フック入力が空です。検査できないため書き込みをブロックします。" >&2; exit 2; }`
  3. selftest に 3 ケースを足す: 「不正 JSON(jq あり)→ block(理由表示)」「python3 のみ + 不正 JSON → block(理由表示)」「空入力 → block(理由表示)」。
     python3 のみの環境は、既存の `$NP` と同様に python3 だけ symlink した PATH で模擬できる。
     理由表示の判定文字列は既存の `*理由表示*` 分岐に合わせ「検査できないため」を含める(「jq または python3」は内部エラー文に入らないので、分岐の条件を見直すか文言に含める)

### R-02 【P3】check-proposal-approved.sh のヘッダーコメントが J-04 後の挙動と食い違う
- 場所: `scripts/check-proposal-approved.sh:13-16`(両層)
- 何が起きるか: 16 行目は「`*** Delete File:` はゲート対象外」のままで、同一パッチ内の proposal 失効ルール(Delete を含めて判定)に触れていない。
  次に触る AI が仕様をコメントから読むと、J-04 の分岐を「不要なコード」と誤読し得る
- 直し方: 16 行目に続けて「ただし同じ change の proposal.md を Add / Update / Move / Delete するパッチでは、その change の design / tasks の
  変更をブロックする(旧承認を根拠にしない)」を 1〜2 行で追記

### R-03 【P3】J-12 の挿入位置で「上記に該当しない変更」の「上記」が hooks の注記を指すように読める
- 場所: `templates/repo/AGENTS.md:33-34`
- 何が起きるか: スペック必須の条件(22-32 行)と「上記に該当しない変更はスペック不要」(34 行)の間に J-12 の 1 行が入り、
  「上記」の参照先が切れる。読み手が一拍迷う程度だが、毎セッション読む行
- 直し方: J-12 の行を 34 行目の後ろ(「完了した change は…」の前)へ移す

### R-04 【P3】リポジトリ層 AGENTS.md が 100 行ちょうど(余裕ゼロ)+ 294 文字の行
- 場所: `templates/repo/AGENTS.md`(全体)、`:41`(J-06 を末尾に足した行、294 文字)、`:33`(J-12)
- 何が起きるか: 上限内だが、次の 1 行追加で即超過し、tanaoroshi の上限チェックが毎回「接近」を出す。J-12 は 63-64 行目の
  「(編集ツール経由の書き込みだけを検査)」と部分的に重複している。41 行目は 1 行に 3 文が入り、読みにくい
- 直し方(どれか 1 つで 1〜2 行の余裕が出る): (a)「このファイルの保守」節の 2 項目を 1 行に畳む(例:「100行以下を保つ。『消したらAIがミスするか?』で No の行は削除し、手順は `.agents/skills/`、パス限定の規約は `docs/rules/` へ逃がす」)
  (b) 41 行目の「書き先は…」を次行に折り返し、(a) と合わせて 100 行以内に収める。joint F-10 の圧縮候補どおり

### R-05 【P3・任意】PROJECT.md の追記文が実装詳細
- 場所: `templates/repo/docs/PROJECT.md:23`
- 何が起きるか: プロジェクトの安定情報を書く文書に「理由付き exit 2 でブロックする」という hooks の実装詳細が入る。利用者に必要なのは結果だけ
- 直し方: 「hooks の依存: `jq` または `python3`(どちらも無いと、編集ツール経由の書き込みがすべてブロックされる)」程度に短くする

### R-06 【P3・任意】selftest に J-04 の Move・CRLF 経路が無い
- 場所: `scripts/hooks-selftest.sh:29-32`
- 何が起きるか: 承認解除・削除・別 change の 3 ケースは的確だが、proposal を `*** Move to:` で退避する経路と CRLF パッチの Delete 経路は
  未検証(私の自作ケースでは正しくブロックされた)。将来 normalize や Move の扱いを変えたときに回帰が見えない
- 直し方: 「proposal を Move で退避 + design 更新 → block」を 1 件足す(CRLF は既存 2 件で normalize 経路を押さえているので任意)

## B. 問題なしを確認した事項

- **joint どおり・範囲外なし**: 13 ファイルの変更はすべて J-01〜J-12 に対応し、見送り 6 件(F-02/04/09/10/11/12)には手を付けていない。
  J-01(両層・2 本に限定)/ J-02(AGENTS + README 2 箇所、ワークスペース配下に限定)/ J-05(「業務ルール・計算を担うコードでは」)/
  J-06(design・実装メモ・テスト名の 3 受け皿のみ)/ J-07(AGENTS と README を `stable` に統一)/ J-08 / J-09(改行復元)/
  J-10(秘密と個人情報を別項に分離)/ J-11(自動切替をやめ、共有ワークスペース・認証情報・外部通信を確認して人が判断)/ J-12(再掲のみ、新しい禁止なし)
- **安全・承認の境目**: 弱めた箇所なし。J-03 は厳しくなる方向(パーサ無しで全 Write/Edit がブロックされる)で、その帰結は README と PROJECT.md に書かれている。
  J-04 は同一パッチの proposal(Add/Update/Move 元先/Delete)と design/tasks の併用だけを止め、Delete のみ・proposal のみ・別 change・`_template` は従来どおり通す
- **J-04 の境界(自作 12 ケース、すべて期待どおり)**: `./` 付き proposal / `cwd=sub` の `../` / proposal を Move で退避 / 別ファイルを proposal.md へ Move /
  CRLF の Delete → すべて block。proposal 更新のみ / design + tasks 同時更新(承認済み)/ ok の proposal + ok2 の design / proposal Delete のみ /
  design Delete + proposal 更新 / `_template` の proposal + design / Claude Write で proposal 単体 → すべて pass
- **J-03 の境界**: `*** Update File` のように JSON エスケープで書いたヘッダーは復号後に判定され block。パーサ無しは両形式・両スクリプトとも
  exit 2 で「jq または python3」「検査できないため」を含む理由を出す(selftest の `*理由表示*` 分岐が文言まで検証している点は良い)
- **両層の同一性・互換性**: 3 スクリプト + 2 設定が一致。hooks 設定(matcher・コマンド)は未変更。`git diff --check` クリーン。bash 3.2 で selftest 36/36

## C. 自作ケースの結果(再現用: 期待値は私の仮説)

| ケース | 結果 | 判定 |
|---|---|---|
| jq あり + 不正 JSON(承認ゲート / シークレット検出) | exit 5、stderr 空 | **R-01** |
| python3 のみ + 不正 JSON(承認ゲート / シークレット検出) | exit 1、stderr 空 | **R-01** |
| 空入力(承認ゲート) | exit 0 | **R-01** |
| python3 のみ + 正常入力(未承認 design / トークン) | exit 2、理由あり | ok |
| J-04 境界 12 件(§B 参照) | 期待どおり | ok |
| `*** Update File`(jq) | exit 2 | ok |
| tool_name 無し + file_path 無し | exit 0 | ok |

## 集計

| 重さ | 件 | ID |
|---|---|---|
| P1 | 0 | — |
| P2 | 1 | R-01 |
| P3 | 5 | R-02, R-03, R-04, R-05(任意), R-06(任意) |

P1=0 P2=1 P3=5
