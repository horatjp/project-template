# joint: 決定論ガードレールの棚卸し提案 — review-fable × review-astra の合意(2026-11-06)

まとめ: review-fable。独立稿は fable.md・astra.md(同じフォルダ)。協議は agmsg で fable 1便・astra 2便(astra の2便目で合意)。
両者とも実装・hooks の実発火・commit はしていない。Codex はローカル `codex-cli 0.166.0` の配布物と openai/codex main のソース(ctx7)、
Claude Code は公式ドキュメント(code.claude.com)で確認した。

## 合意

1. **指摘 #2 は正しい。** ゲートの対象は design/tasks だけで proposal.md は対象外(`scripts/check-proposal-approved.sh:101-105`)、
   承認の検査は `[x] ユーザー承認` の有無のみ(同 `:123`)。別々の呼び出しで「proposal に `[x]` → design」は両 CLI とも通り、
   雛形も AI が記入する前提(`templates/repo/changes/_template/proposal.md:53`)。ただし「ゲートの保証がゼロ」は広すぎる。
   正確には**「順序は強制するが、承認の出所は保証しない」**(同一パッチ内の記入拒否 `:109-115` は効いている)
2. **Codex の `ask` は fail-open。** スキーマの enum にはあるが、出力パーサが `unsupported permissionDecision:ask` として invalid 扱いにし
   (`codex-rs/hooks/src/engine/output_parser.rs`)、`parse_completed` は Failed を記録するだけで `should_block=false` のまま
   (`codex-rs/hooks/src/events/pre_tool_use.rs`)。exit 0/2 以外・タイムアウト・未知フィールド入りの JSON も同じ。
   ローカル 0.166.0 のバイナリにも同じエラー文字列がある(文字列の存在は実行経路の実証ではない。実発火は未実施)。
   → proposal の「Codex で効かなければ deny」は成立しない。**Codex に `ask` を出した時点で書き込みは通る。**
   `ask` を使うなら CLI を明示引数で判定し、不明なら deny。環境変数(`CLAUDE_PROJECT_DIR`)は codex スキルが Claude Code の
   セッション内から `codex exec` を起動するため判定に使えない
3. **Claude Code の `ask` の形は確認できた**: stdout に `hookSpecificOutput.permissionDecision: "ask"` の JSON + exit 0。reason はプロンプトに表示、
   `-p` で答える人がいなければ拒否(fail-closed)、auto モードでは分類器を経ず人間へ(https://code.claude.com/docs/en/hooks)。
   **要確認**: hook の `ask` の bypassPermissions / dontAsk での扱い(確認できたのは `permissions.ask` ルールの記述のみ)、
   exit 2 と stdout JSON を同じスクリプトで混ぜること(hooks-guide「choose one approach per hook」)。deny は全モードで止まる
4. **2 を入れるなら `ask` ではなく deny のみの形(B 案)。** 編集ツールが `changes/*/proposal.md` に `[x] ユーザー承認` を新たに持ち込む操作を
   exit 2 で拒否する。AI は `- [ ] ユーザー承認(日付 / 対象 / 原文:「…」)` まで書き、`[ ]`→`[x]` はユーザーがエディタで直接書く。
   両 CLI とも既存 hooks と同じ経路(exit 2 + stderr)なので、`ask` の未確認事項をすべて避けられる。
   `ask`(A 案)は Claude Code 向けの改善として、実 CLI で確かめてから後で重ねる
5. **B 案の判定原則**: 「編集を適用した**後の状態**に `[x] ユーザー承認` があり、適用前の disk に無い」で統一する(追加行や old/new 文字列の
   検索では `old_string="[ ]"` のような部分編集や、承認済み本文の別ファイルからの Move を取りこぼす)。
   `[x]`→`[ ]`(再承認のための解除)は通す。具体のアルゴリズム(Write は content と disk の比較、Edit は置換の模擬、Codex の Add/Update/Move の扱い)、
   除外範囲(`changes/_template/` は現行どおり。`changes/archive/` の扱い)、python3 必須化、selftest のケース数(見積もり 13 前後)は
   **design 前の見積もり**であり、今回合意した設計ではない(現 matcher は `Write|Edit` で MultiEdit は未登録)
6. **B 案が保証しないこと**(proposal と設計に明記する): `[x]` を残したままのスコープ変更(承認の陳腐化。既存の穴で B は悪化させない)/
   シェル経路(`sed` 等。前提3のとおり既存 2 hooks と同じ)/ 軽量 change の実装や実装コードの書き込み(現行ゲートの責務外)。
   「編集ツールからの新規の自己承認を抑止する」限定保証であり、「実装前に人間承認を必ず得る」保証とは言わない
7. **B 案はユーザーの操作義務を変える**(AI の転記 → ユーザーの1文字編集)。これは 09-23「義務は増やさない」の「文言が既にある」では
   済まず、ユーザーの明示的な同意が要る。既存 2 hooks 自体も実 CLI 未検証(`_devlog/STATUS.md:39`)で、B はそれを継承する
8. **1 は保留。** Claude Code なら `permissions.ask` の `Edit(path)` ルール数行で足り(`Edit` は Write・NotebookEdit も含む全編集ツールに効き、
   `Write(path)` は一致しない。https://code.claude.com/docs/en/permissions)、bypassPermissions でも問う。Codex に同等物は無く、
   deny hook にすると AI が AGENTS.md を一切編集できないので規則のまま。「承認済みの範囲でも編集のたびに確認」になる摩擦は未観測で、
   入れるなら別途ユーザーの同意
9. **3 は現案を見送り。** 日付での判定は「追記専用」の規則とずれる(規則どおりの追記にも ask が出て、当日中の過去エントリ削除は見逃す)
10. **4・5・6 は別提案(前提3の変更)。** Claude Code 側は `Bash(git push *)` 等の `permissions.ask` で小さく出せる。
    ワークスペースの「private で運用」(`gh repo create --public` / `--visibility`)、git-commit の「`git add .` で一括しない」も同じ束
11. **7・8・9・11〜15 は見送り**(proposal の判定どおり)。10 は 2 と同時には入れない(YAML の状態変更・承認済み事項の転記・本文変更の扱いが別で、
    費用は小さいとは限らない)
12. **表の漏れ**: 承認後のスコープ変更時の再承認(`templates/repo/AGENTS.md:31`)/ 本文変更時の verified 失効 / private 運用 /
    標準 change の独立レビュー・契約先行(履行は検査できない)/ setup-repo の名前検査(手順側で検査する性質)。
    「網羅」と呼ぶならこれらを足すか、重要候補の抜粋と明記する
13. **proposal の記述の修正**: 「新しいスクリプトは作らず」と「新しいスクリプト check-human-gate.sh(仮)」の矛盾(2 は承認ゲートの穴なので
    `check-proposal-approved.sh` に入れるのが自然だが、design で決めればよい)/ Codex の deny 時メッセージ「承認を得てから再実行」は
    再実行しても deny なので「承認欄はユーザー自身が記入する」に/ 記事の証明検査と承認チェックの出所確認を同一視しない
14. **既存決定との整合**: 既存 2 hooks も learnings 由来ではない(承認ゲートは 2026-07-25 changes-spec-driven、認証情報検出は 2026-09-23)。
    07-25 は学びの昇格経路であって、設計時ガードの唯一の入口ではない。2 を既存ゲートの修正として扱うのは可。
    09-23 は「文言が既にある」だけでは満たされず、人間側の確認・操作が増える分(1・10・B 案の手編集)はユーザーの同意が要る

## 割れた点(協議で解消)

- **2 の導入時期**: fable は「B 案なら未確認事項が無いので今入れる」、astra は「要検証に戻し実案件の後」。
  協議の結果、fable は「未確認なし」「selftest で足りる」を撤回し、astra は「実案件を待つ必然性」を撤回。
  **条件付きで 2 を採る**で一致: 導入前条件は (i) 手編集への明示的な同意、(ii) 事後状態と対象範囲を定めた設計、
  (iii) 両 CLI での実発火検証(次の実案件を待たず、使い捨てリポジトリで template-cc かユーザーが行う。既存 hooks の未検証項目も同時に消化できる)。
  3条件が未充足の現時点で「導入可」ではなく、実施は別途許可の後
- 残る相違はない。fable の当初案の判定ロジック(old/new 検索・+行のみ)は astra の反例で撤回した

## 見送るもの

- 1・3・4・5・6・7・8・9・10・11・12・13・14・15(理由は合意 8〜11)
- `ask` 形式(A 案)。Claude Code の実 CLI で bypass/dontAsk・混在の扱いを確かめるまで入れない
- 承認原文の書式検査(非空・日付)は AI が埋められるので人間ゲートの代わりにならない。入れるなら 2 の補助として任意

## ユーザーへの推奨(proposal「判断してほしいこと」1〜4)

1. **時期**: 2 だけを B 案で、上の3条件を満たしてから入れる((a) と (b) の中間。実案件を待つ必要はない)。1・3 は今回入れない
2. **範囲**: 2 のみ。10 は同時に入れない。1 を将来入れるなら Claude Code は `permissions.ask`
3. **シェル経路**: 別提案に賛成。Claude Code 側は `permissions.ask` 数行なので小さく早く出せる
4. **実装前レビュー**: B 案の design(事後状態の判定・対象範囲・除外・メッセージ)を1画面で書いて Fable・Astra が見る。
   実装後は diff・selftest・実発火の結果を確認する

ユーザーに決めてもらうこと: (i) 承認欄の `[x]` をユーザー自身が書く運用にしてよいか(AI の転記からの変更)、
(ii) 使い捨てリポジトリでの両 CLI 実発火検証の実施、(iii) proposal の修正(保証範囲・Codex メッセージ・矛盾・表の漏れの扱い)

合意 採る=2 推奨=修正
