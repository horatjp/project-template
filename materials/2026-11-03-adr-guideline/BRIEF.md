# ADR 執筆ガイドライン記事を決定記録テンプレートに取り込むかの検討(2026-11-03)

依頼者: ユーザー(template-cc が取りまとめ)
参加者: review-fable(Claude Code・Claude Fable 5.1)、review-astra(Codex CLI・Astra)。agmsg のチームは project-template。

## 目的

外部記事(TOKIUM「ADR 執筆ガイドライン」、下に要約)から、project-template の決定記録テンプレートに
**取り込むべきもの・取り込まないべきもの**を決める。ユーザーの指示は「話し合って、必要とあれば修正して」。
修正は template-cc が合意に基づいて行う。あなたたちは意見と根拠を出す(反対・「直さない」も歓迎)。

## 対象ファイル(リポジトリ /Users/horatjp/projects/project-template、main)

- `templates/repo/docs/decisions/_template.md`(リポジトリ層。技術決定=ADR)
- `docs/decisions/_template.md`(ワークスペース層。事業・運営判断)
- 関連: `templates/repo/AGENTS.md`(記録の境界・changes/ の運用)、`AGENTS.md`、`templates/repo/docs/rules/README.md`、
  `templates/repo/changes/_template/`、`.agents/skills/` 内で決定記録を扱うもの(lens-review 等)

## 記事の要約(ネットワーク取得はしないこと。必要ならこの要約を前提にする)

背景: AI に ADR を書かせたら移行計画・進捗表・実装詳細・ADR 単体で読めない文面が増え、人間がレビューで読み解けなくなった。
過去の PR 34本・レビューコメント830件から32規約(A〜G、MUST/SHOULD と ID 付き)を抽出。
- 書かない: 移行計画・進捗・タスク表(D-1)/チケット・PR番号(A-1)/会議だけを根拠にした記述(C-1)/完了で陳腐化する情報(F)/実装詳細(D-4)
- 粒度の判定(D-4): 「決定した実現方式を別方式へ置き換えたとき、ADR 本文を書き換える必要があるか。必要ならその記述は ADR ではなく DR(PR description 等)か仕様書に属する」
- 書く: 適用範囲と「本 ADR で決定しないこと」節(委譲先を名指し、辿れること)(D-3)/例外の失効条件/前提事実の出典と確認日・一次資料と照合(C-1,C-3)/ADR 単体で読めること(仮定形の一般論でなく、このプロジェクトで実際に起きている問題を書く)/他 ADR 参照は「ADR-NNN の Decision 項 2(章題)」形式(B-2)
- 状態: Proposed/Accepted/Deprecated/Superseded。Accepted 前に未確定事項を残さない(G)。一覧・参照元を追従(E)
- 運用: 執筆スキル・path-scoped rule・CI の AI レビューが同じガイドラインを参照(本文は複製しない)。規約は実レビューで繰り返される指摘から更新。ID で「D-1 違反」と短く指摘できる
- 失敗例: Decision に23行のタスク表/Context が一般論/Decision にメソッド名・環境変数形式まで

## template-cc の暫定案(批判してよい。鵜呑みにしない)

既にある(取り込み不要): status ライフサイクル+superseded_by、代替案、影響範囲・再検討の条件、stale_after、AI だけで stable にしない。
取り込み案(両層の `_template.md` のコメントに数行ずつ):
1. 書かないもの: 進捗・タスク・チケット番号(→ changes/ の tasks や STATUS)。置き換えテスト(D-4)を判定の問いとして
2. 「決定と理由」末尾に「この決定で決めないこと」(委譲先をリンク)
3. 「背景」注記: 前提事実には出所を書く、一般論でなくこのプロジェクトで実際に起きていることを書く
見送り案: 32規約と ID 体系(実指摘の無い段階で先回りすると守られない)、他 ADR 参照書式(小規模ではファイル名で足りる)、
docs/rules/decisions.md への切り出し(育ってから)

## 見てほしい観点

1. 暫定案 1〜3 は本当に必要か(既存の規範・AGENTS.md の記録の境界で既に足りていないか)。足りないなら、どこに・どの文言で書くのが最小か
2. 暫定案が見落としている、取り込むべき項目(例: 未確定事項を残したまま stable にしない、例外の失効条件)
3. ワークスペース層(事業判断)にも同じものが要るか、片方だけでよいか
4. 既存規範との矛盾・二重記述にならないか(AGENTS.md は100行以下、_template はコメントが既に長い)

## 進め方

1. 相手のファイルを読まず、独立に `_devlog/materials/2026-11-03-adr-guideline/<fable|astra>.md` に書く。
   各項目は「採る/採らない/修正案」・ファイル:行・具体的な文言案・根拠。推測は「要確認」と明記。最終行を飾りなしで `採る=n 採らない=n`
2. 書き終えたら agmsg で template-cc と相手に知らせ、さらに `hc send t16 '報告した'` と一言知らせる
3. 両方そろったら相手と最大2往復で賛否をやり取りする
4. review-fable が `joint.md` に「合意した変更(ファイルと文言案)・割れた点・見送るもの」をまとめ、
   最終行を `合意 採る=n` にして template-cc に agmsg で知らせ、`hc send t16 '合意した'` と一言知らせる

## 守ること

- やってよいのは読むことと、上記の報告ファイルを書くことだけ。リポジトリのファイル変更・commit・push・削除・ネットワーク取得・有料の実行はしない
- 秘密を読まない(`.env`・`~/.codex/auth.json` 等)
- 受信箱は知らせを受けたときに確認する
