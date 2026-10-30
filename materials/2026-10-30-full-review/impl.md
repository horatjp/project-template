# J-01〜J-12 実装報告

- 実装担当: impl-sol / 2026-10-30
- 作業場所: `/Users/horatjp/projects/project-template`、main、基点 `0f515ef`
- PLAN の順序で実施: J-08 → J-09 → J-07 → J-01 → J-02 → J-05 → J-06 → J-12 → J-10 → J-11 → J-04 → J-03。
- commit・push・ネットワーク取得・有料実行・既存ファイルの削除は未実施。selftest 既存の終了処理による一時 fixture の消去のみ実行。`_devlog/` は本ファイル以外変更していない。STATUS・journal は leader 管理。

## 各指摘の変更箇所

| ID | 変更箇所 | 実装内容 |
|---|---|---|
| J-01 | `AGENTS.md`、`templates/repo/AGENTS.md` の安全節 | 承認が必要な変更対象に hooks が参照する `scripts/check-proposal-approved.sh`・`scripts/check-credentials.sh` の2本を追加。scripts 全体には拡大しない |
| J-02 | `templates/repo/AGENTS.md` の安全節、`README.md` の worktree 注意2箇所 | ワークスペース配下のリポジトリの worktree はその `repos/` 直下に作成。単体リポジトリへの条件は増やさず、`../../AGENTS.md` の参照理由を説明 |
| J-03 | 両層 `scripts/check-credentials.sh`・`check-proposal-approved.sh`・`hooks-selftest.sh`、`README.md`、`templates/repo/docs/PROJECT.md` | パーサが無ければ形式判定前に理由付き exit 2。生 JSON からの tool_name / file_path 抽出およびパーサ不在時の全体走査への退避を除去。jq または python3 の依存を明記。Unicode 復号が必要な合成入力と拒否理由の検証を追加 |
| J-04 | 両層 `scripts/check-proposal-approved.sh`・`hooks-selftest.sh` | 同一パッチ内で同じ change の proposal と design/tasks を触る場合は拒否。proposal の Add/Update/Move 元先/Delete を比較対象に含める。design/tasks の Delete のみは従来どおり対象外。承認解除・proposal 削除の回帰と別 change を巻き込まないケースを追加 |
| J-05 | `templates/repo/.agents/skills/lens-review/SKILL.md` correctness | 契約・副作用の検査を「業務ルール・計算を担うコードでは」に限定 |
| J-06 | `templates/repo/AGENTS.md` コードの設計 | 契約の書き先を標準は design、軽量は proposal 実装メモ、スペック不要はテスト名・docstring と明示。既存の受け皿のみ使用 |
| J-07 | `templates/repo/AGENTS.md`、`README.md` 変更管理 | active / 既存の決定という表現を `stable` な決定記録へ統一 |
| J-08 | `AGENTS.md` 構成表 | 存在しない `templates/modules/` の案内を除去 |
| J-09 | `templates/repo/AGENTS.md` 保守節 | 結合していた2つの箇条書きを別行へ修正。保守節見出しも維持 |
| J-10 | `materials/README.md` ルール | 秘密入り原本は保存せず、秘密を除いた受領版だけを保存・変換。第三者の個人情報に関する事前確認と変換版マスクは別項に記載 |
| J-11 | `.devcontainer/README.md` 初回セットアップ | サンドボックス無しへの自動切り替えをやめ、共有領域・認証情報・通信への影響とファイアウォール節を人が確認して判断する説明に変更 |
| J-12 | `templates/repo/AGENTS.md` 変更の進め方 | 承認ゲート hooks は編集ツール経路のみ、シェル経由の書き込みは対象外と再掲。新たな禁止や matcher は追加しない |

## 回帰の失敗確認 → 修正

- J-04: selftest を先に両層へ追加し、スクリプト修正前にワークスペース層で実行。`pass=29 fail=2`。承認解除 + design 更新、tasks 更新 + proposal 削除がともに exit 0 (期待 exit 2) で失敗。修正後 `pass=31 fail=0`。
- J-03: J-04 修正後、先に両層 selftest を更新してワークスペース層で実行。`pass=31 fail=5`。対象外 Claude Write、old_string のみの Edit の理由表示、Unicode パス・トークン、無害な Claude Write のパーサ不在ケースで失敗を確認。スクリプト修正後 `pass=36 fail=0`。
- Unicode パス・トークンはパーサありの検出ケースも追加。パーサ不在ケースは exit 2 に加え「jq または python3」と「検査できないため」を含む理由表示を検証。

## 最終検証

- `/bin/bash scripts/hooks-selftest.sh`: **pass=36 fail=0**、exit 0。
- `/bin/bash templates/repo/scripts/hooks-selftest.sh`: **pass=36 fail=0**、exit 0。
- 実行環境: macOS `/bin/bash` 3.2.57。
- `cmp`: 両層の3スクリプト、`.claude/settings.json`、`.codex/hooks.json` の全5組が一致。hooks 設定自体は未変更。
- AGENTS.md 行数: ワークスペース **77行**、リポジトリ **100行**。
- `git diff --check`: exit 0。
- main の差分は12件に対応する13ファイル。見送り6件および範囲外の改善は未実施。

## 検証の限界・引き継ぎ

- 上記は合成 hook 入力のローカル検証。実 CLI の hook 配送、CLI ごとの文書発見条件、OKF 一次仕様への適合は未確認。
- 別 AI の最終レビューと監督の独立 selftest は未実施。本報告は実装完了であり、レビュー完了・コミット許可を意味しない。
- 受信箱は通知時のみ確認する運用を維持。参加および template-cc への送信は成功したが、agmsg が既存 pane 登録の保護通知 (#1114) を出した。既存登録の変更・削除は行っていない。

実装完了


## 再修正(R-01〜R-06)

- 2026-10-30 / impl-sol。review-fable-impl.md の全6件(任意2件を含む)を対応。

| ID | 変更箇所 | 再修正内容 |
|---|---|---|
| R-01 | 両層 `scripts/check-proposal-approved.sh`・`check-credentials.sh`・`hooks-selftest.sh` | `set -euo pipefail` 直後に EXIT トラップを追加。0/2 以外の終了は内部エラーの終了値と検査不能の理由を stderr に示し、exit 2 に変換。空入力も理由付き exit 2。jq のみ・python3 のみ・空入力をそれぞれ両ゲートで検証する6ケースを先に追加。理由検証はパーサ不在時の依存表記チェックを維持し、内部エラー・空入力は検査不能とブロックの文言をチェック |
| R-02 | 両層 `scripts/check-proposal-approved.sh` ヘッダー | design/tasks の Delete 自体は対象外だが、proposal の Add/Update/Move/Delete と同 change の design/tasks の同時変更は拒否する、と実挙動に合わせて明記 |
| R-03 | `templates/repo/AGENTS.md` 変更の進め方 | hooks の適用範囲の注記を「上記に該当しない変更」の後ろへ移動し、スペック必須条件からの参照を連続させた |
| R-04 | `templates/repo/AGENTS.md` コードの設計・末尾 | (a) 保守節を、上限・削除基準・手順と規約の移し先を残した1行へ圧縮。(b)「書き先は…」を次行へ折り返し。100行から98行になり、99行以下を満たす |
| R-05 | `templates/repo/docs/PROJECT.md` 開発環境 | exit 2 等の実装詳細を除去し、jq または python3 が無いと編集ツール経由の書き込みがすべてブロックされる、という利用者向けの説明へ短縮 |
| R-06 | 両層 `scripts/hooks-selftest.sh` | proposal を Move で退避 + design 更新、および CRLF の proposal Delete + tasks 更新の2ケースを追加 |

### 修正前の失敗確認

- R-01 は両層 selftest に先に回帰ケースを追加し、ゲート本体を変える前に `/bin/bash scripts/hooks-selftest.sh` を実行: **pass=36 fail=6**、exit 1。
- 両ゲートで、不正 JSON + jq のみは exit 5 / stderr 空、不正 JSON + python3 のみは exit 1 / stderr 空、空入力は exit 0 / stderr 空。すべて期待する「理由付き exit 2」に反して失敗した。
- R-02〜R-05 は文書修正のため失敗テストなし。R-06 は既存実装で対応済みの境界を継続検証する追加で、失敗を作るための本体変更はしていない。

### 最終検証

- `/bin/bash scripts/hooks-selftest.sh`: **pass=44 fail=0**、exit 0。
- `/bin/bash templates/repo/scripts/hooks-selftest.sh`: **pass=44 fail=0**、exit 0。
- 実行は macOS `/bin/bash` 3.2.57。jq のみ / python3 のみの PATH を一時 fixture 内の symlink で模擬し、ネットワーク取得は行っていない。
- 両層の3スクリプト + hooks 設定2組は `cmp` で全5組一致。hooks 設定自体は未変更。
- AGENTS.md: ワークスペース **77行** / リポジトリ **98行**。
- `/bin/bash -n` による3スクリプトの構文検査および `git diff --check`: 成功。
- commit・push・既存ファイル削除・ネットワーク取得は未実施。selftest が作る一時 fixture の終了処理以外の削除はしていない。`_devlog/` は impl.md への追記のみ。
- 実 CLI の hook 配送と終了値の扱いは未確認。今回もローカル合成入力の検証であり、別 AI の再レビュー・監督の独立検証は未実施。

再修正完了


## 再々修正(R2-01〜R2-03)

- 2026-10-30 / impl-sol。review-fable-impl-r2.md の全3件(任意の R2-03 を含む)を対応。

| ID | 変更箇所 | 内容 |
|---|---|---|
| R2-01 | 両層 `scripts/check-credentials.sh`・`hooks-selftest.sh` | apply_patch 追加行抽出の `|| true` を、不一致(exit 1)だけ許す分岐へ変更。それ以外は EXIT トラップが理由付き exit 2 にする。パターン走査は終了値を保存し、0=検出、1=不一致、2以上=検査エラーとして理由付き exit 2。grep 不在 / exit 2 の模擬コマンド × Claude Write / apply_patch の4ケースを追加 |
| R2-02 | `templates/repo/AGENTS.md` | 保守ルールの1行を条件付き「ワークスペース配下の場合」節から「安全」節末尾(worktree 項の後)へ移動。98行を維持 |
| R2-03 | 両層 `scripts/hooks-selftest.sh` | jq の実在を確認して fixture を作成。jq が無い場合は該当2ケースを `skip … (jq 無し)` と表示し、pass/fail に数えない |

### 修正前の失敗確認

- R2-01 は先に両層 selftest に4ケースを追加し、本体修正前にワークスペース層で実行: **pass=44 fail=4**、exit 1。
- grep 不在の2ケースは command not found を出しながら exit 0、grep が exit 2 を返す2ケースは理由なし exit 0。いずれも期待する理由付き exit 2 に反して失敗した。

### 最終検証

- `/bin/bash scripts/hooks-selftest.sh`: **pass=48 fail=0**、exit 0。
- `/bin/bash templates/repo/scripts/hooks-selftest.sh`: **pass=48 fail=0**、exit 0。
- jq だけを PATH から除いた一時 fixture で selftest 全体を両層それぞれ実行: 各 **pass=46 fail=0、skip 2件**、exit 0。skip は両ゲートの「不正 JSON(jq のみ)」のみで、空振りの pass として計上されないことを確認。
- macOS `/bin/bash` 3.2.57、ローカル合成入力のみ。模擬 grep は一時 fixture 内に作成。
- 両層の3スクリプト + hooks 設定2組は `cmp` で全5組一致。hooks 設定自体は未変更。
- AGENTS.md はワークスペース **77行** / repo **98行**。
- `/bin/bash -n` による3スクリプトの構文検査、`git diff --check`: 成功。
- commit・push・既存ファイル削除・ネットワーク取得は未実施。一時テスト fixture の終了処理以外の削除はしていない。`_devlog/` は impl.md への追記のみ。
- 実 CLI の hook 配送と終了値の扱いは未確認。別 AI の最終レビュー・監督の独立検証は未実施。

再々修正完了
