# ADR 執筆ガイドラインの取り込み検討 — review-fable(Claude Code / Claude Fable 5.1)2026-11-03

依頼: BRIEF.md。対象: main `7a4b877`。読んだもの: 両層の `docs/decisions/_template.md`、両層 `AGENTS.md`、
`templates/repo/changes/_template/*`、`templates/repo/docs/rules/README.md`、`docs/knowledge/_template.md`、
lens-review / hearing / session-end / tanaoroshi の各 SKILL.md、README.md 設計思想、
`_archive/decisions/` の決定記録 8 件(経緯確認)、両 `_template.md` の git log。相手(review-astra)のファイルは未読。
記事本文は未取得(BRIEF の要約のみを前提にする)。

## 0. 判断の物差し(先に置く)

- **恒常層(AGENTS・docs/rules・hooks)には入れない。** 実指摘の無い規範を先回りで置かない方針は stable な決定
  (`_archive/decisions/2026-07-25-promotion-over-standards.md`)と README 設計思想 1 で確定済み。template-cc の
  見送り理由と同じ
- **`_template.md` のコメント・プレースホルダは別扱い。** 決定を書く瞬間だけ読む書式規則で、`682287f`
  「書式の規則を各 _template.md に寄せ、常時読む AGENTS.md の重複を減らす」で置き場として確定している。
  ここには予防的に入れてよいが、**各 1〜2 行、既存の節・規則と重複しないものだけ**
- 既存規則(出所 1 行・knowledge 相互リンク・再検討の条件・stale_after・superseded_by・連番なし)と**衝突する文言は採らない**
- 事実: `_archive/decisions/` の 8 件(40〜53 行)に、記事の失敗例(タスク表・PR 番号・進捗・一般論の背景)は**1 件も無い**。
  本テンプレートで記事の問題が起きた証拠は無く、以下の「採る」はすべて予防的な追加(要確認: 展開先の実案件は手元に無い)。
  リスクが最も高い箇所は `templates/repo/AGENTS.md:35-36` の「完了した change から decisions へ抽出」で、
  AI が完了報告・tasks をそのまま写し得る

---

## 1. 暫定案 1〜3 への回答(観点 1)

### F-01 【採る・修正】タスク・進捗・完了報告を決定記録に書かない(暫定案 1 前半、記事 D-1・F)
- 既存で足りない理由: `templates/repo/AGENTS.md:55`「今どうなっているかは生きた文書、なぜそうしたかは decisions」と
  `changes/_template/tasks.md:6`「進捗は STATUS に change 名と現在タスクだけ」は**行き先**を言うだけで、
  決定記録側に「写すな」が無い。抽出の瞬間(`AGENTS.md:35-36`)に効く禁止がどこにも無い
- 場所: `templates/repo/docs/decisions/_template.md` コメント、24 行目「なぜそう決めたかを丁寧に」の直後。F-03 と 1 箇条書きにまとめる(文言は F-03 に併記)
- ワークスペース層: `docs/decisions/_template.md:23` の既存行に追記(+0 行):
  「技術的な決定は各リポジトリの docs/decisions/ へ、宿題・進捗・次のアクションは STATUS.md と journal へ(決定記録に写さない)。」
  事業判断で AI が「次のアクション」を決定本文に並べる形は起こり得る(要確認: 未観測)

### F-02 【採らない】チケット・PR 番号を書かない(暫定案 1 の一部、記事 A-1)
- 根拠: 既存規則と衝突する。`templates/repo/docs/decisions/_template.md:25-26`「承認済みなら、その出所を本文に 1 行書く」、
  `:29`「knowledge と相互リンク」、ws `_template.md:32,37`「journal へリンク」。本テンプレートの出所(changes/archive・journal・knowledge)は
  リポジトリ内で辿れるので、記事が嫌った「トラッカーが無いと読めない番号」とは性質が違う
- 代替: 禁止ではなく「出所はリンク 1 行、理由は本文に書く(リンク先を読まないと分からない書き方をしない)」の趣旨は
  F-06 の背景プレースホルダで吸収できる。独立の行は増やさない

### F-03 【採る・修正】置き換えテスト(暫定案 1 後半、記事 D-4)
- 既存で足りない理由: 粒度の判定基準が無い。失敗例「Decision にメソッド名・環境変数形式」はそのまま起こり得る
- 修正点: 記事の問い(「実現方式を別方式へ置き換えたとき書き換えが要るか」)は、決定そのものが supersede される場合と
  区別しにくい。本テンプレートの語彙(design・生きた文書)に言い換え、**リポジトリ層のみ**に置く
  (ワークスペース層は `:23`「技術的な決定はリポジトリへ」の層分けで実装詳細が入りにくい)
- 場所と文言: `templates/repo/docs/decisions/_template.md` 24 行目の直後に 2 行(F-01 と合わせて):
  ```
  - 決定記録に書くのは「選択と理由」だけ。実装のしかたを変えただけで書き換えが要る記述(設定値・名前・手順)は
    design・生きた文書へ、タスク・進捗・完了報告は changes/ と STATUS へ(changes/ から抽出するときも写さない)
  ```
- 要確認: 記事原文の D-4 を要約から解釈した。原文が「決定の粒度を上げる」意図なら上記で合致、別の意図なら要再読

### F-04 【採る・修正】「この決定で決めないこと」(暫定案 2、記事 D-3)
- 既存で足りない理由: `changes/_template/proposal.md:22`「やらないこと」は change のスコープで、決定記録には境界を書く場所が無い。
  hearing(`SKILL.md:70-71`)・session-end 経由で change を介さず起こす決定には proposal すら無い
- 修正点: **新しい見出しは足さない**(5 節+長いコメントで既に重い。「検討した代替案」も `:49`「自明なら省略可」の運用)。
  「決定と理由」のプレースホルダに 1 句入れ、無ければ書かないことを許す
- 場所と文言:
  - `templates/repo/docs/decisions/_template.md:45`
    `(何を選び、なぜか。この決定で決めないこと・他に委ねることがあれば末尾に 1 行、委ね先(別の決定記録・生きた文書・changes)をリンク)`
  - `docs/decisions/_template.md:41`
    `(何を選び、なぜか。この決定で決めないこと・他に委ねることがあれば末尾に 1 行、委ね先(別の決定記録・生きた文書・リポジトリの decisions)をリンク)`
- 両層に要る: 事業判断ほど境界が曖昧になりやすい(例: 料金は決めるが請求時期は決めない)

### F-05 【採らない】前提事実の出所と確認日(暫定案 3 前半、記事 C-1・C-3)
- 根拠: 既に揃っている。リポジトリ層は `_template.md:29`「調査に基づく決定は knowledge と相互リンク」+ knowledge 側の
  `generated.at` / `verified` / `stale_after`(`docs/knowledge/_template.md:7-14`)が出所と確認日を持つ。
  ワークスペース層は `:37` の背景プレースホルダに「出所: journal/」が既にある。
  決定記録本文に確認日を重ねて書くと knowledge と二重管理になる
- 補足: リポジトリ層の背景プレースホルダ(`:41`)に ws と同じ「出所:」を足す案もあるが、`:29` の重複になるので見送り

### F-06 【採る・修正】一般論でなく、このプロジェクトで実際に起きている問題を書く(暫定案 3 後半)
- 既存で足りない理由: どこにも無い。AI が背景を一般論(「〜はスケーラビリティに優れるため」)で埋めるのは
  記事の主要な失敗例で、本テンプレートの既存規則では防げない
- 修正点: コメント行ではなくプレースホルダ 1 句(+0 行)
- 場所と文言:
  - `templates/repo/docs/decisions/_template.md:41`
    `(この決定が必要になった経緯・制約。一般論ではなく、このプロジェクトで実際に起きている問題を書く)`
  - `docs/decisions/_template.md:37`
    `(この決定が必要になった経緯・制約。一般論ではなく実際に起きている問題を書く。出所: [journal/YYYY-MM-DD.md](../../journal/YYYY-MM-DD.md))`

---

## 2. 暫定案が見落としている項目(観点 2)

### F-07 【採る】未確定の項目を残したまま stable にしない(記事 G)
- 既存で足りない理由: `stable` = ユーザー承認済み、までは両層にあるが、本文に「要検討」「TBD」が残ったまま会話の一言で
  承認 → stable になる経路を塞ぐ文が無い。`AGENTS.md:14`「stable は根拠にしてよい」なので、穴の空いた stable は
  そのまま判断根拠になる
- 整合: hearing の「仮案+再検討の条件で合意 → stable」(`SKILL.md:70-71`)は**未確定ではなく、条件付きで決めた状態**。
  文言はこれを壊さない形にする(仮に決めて再検討の条件へ、または決めないことへ回す)
- 場所と文言(両層、+1 行ずつ):
  - `templates/repo/docs/decisions/_template.md:25-26` の箇条書きに 3 行目を足す:
    ```
    - 決定はまず `status: draft` で起こし、ユーザーの承認が確認できたら `stable` にする(重要度によらない。
      会話や承認済み proposal で承認済みなら、その出所を本文に1行書けばよい。AI の判断だけでは stable にしない。
      未確定の項目を残したまま stable にしない — 仮に決めて「再検討の条件」に書くか、「決めないこと」へ回す)
    ```
  - `docs/decisions/_template.md:24-25` に同じ 3 行目

### F-08 【採らない】例外の失効条件
- 根拠: `:55-57`「再検討の条件」+ frontmatter `stale_after`(`:7`)で既出。例外も 1 件の決定(「やらない」決定の裏返し)として
  同じ節に書ける。専用の文は重複

### F-12 【採らない】一覧・参照元の追従(記事 E)
- 根拠: 一覧(index.md)は stable な決定で見送り済み(`_archive/decisions/2026-07-25-okf-partial-adoption.md`、10 ファイル超で再検討)。
  参照元の追従は `superseded_by` と tanaoroshi(`SKILL.md:27-29`「deprecated なのに superseded_by が無い → 提案」)が担う

### F-13 【採らない】執筆スキル・レビューが同じガイドラインを参照し、本文を複製しない
- 根拠: 本テンプレートでは `_template.md` が唯一の原典(`AGENTS.md:58-59`「書式は _template.md に従う」)で、既に複製していない。
  決定記録の検証は `verified`(別 AI・人間)が担う。lens-review に「決定記録」レンズを足すのは、同じ指摘が繰り返し出てから
  (`lens-review/SKILL.md:62-63` の規範化フローがそのまま入口)

---

## 3. 見送り案への賛否(template-cc の見送り 3 件)

### F-09 【採らない・同意】32 規約と ID 体系
- 根拠: promotion-over-standards(stable)。繰り返し指摘 → learnings → 昇格の経路が既にある。ID は指摘が溜まってから付けても遅くない

### F-10 【採らない・同意】他決定への参照書式(ADR-NNN の Decision 項 2)
- 根拠: 連番なし・topic 名参照は stable な決定(`_archive/decisions/2026-07-25-decision-record-terms.md`、再検討条件は
  「人間メンバーが増えて短い参照の需要が出たとき」)。ファイル名リンクで足りる

### F-11 【採らない・同意、ただし行き先を訂正】`docs/rules/decisions.md` への切り出し
- 根拠: 同意。加えて `templates/repo/docs/rules/README.md:18`「ここに置くのは守らないと壊れる規約のみ」なので、
  書式・文体の規約は育っても docs/rules の対象外。行き先は `.agents/skills/`(多段階の手順)か `_template.md` 本体。
  「育ってから docs/rules へ」という暫定案の前提は外しておく

---

## 4. 既存規範との矛盾・二重記述の確認(観点 4)

### F-14 【採らない】`AGENTS.md:35-36`(抽出行)・`tasks.md:31-32`(昇格コメント)への注記
- 根拠: リスクの発生箇所ではあるが、`templates/repo/AGENTS.md` は 97 行(上限 100)で、`682287f` の「書式規則は _template に寄せる」
  方針に反する。AI は決定を起こすとき `_template.md` を開く(`AGENTS.md:58-59`)ので、テンプレ側で足りる

### 行数の影響
| ファイル | コメント行(現状) | 変更後 | 内訳 |
|---|---|---|---|
| `templates/repo/docs/decisions/_template.md` | 18 行(20-37) | 21 行 | F-01+F-03 で +2、F-07 で +1。F-04・F-06 はプレースホルダで +0 |
| `docs/decisions/_template.md` | 14 行(20-33) | 15〜16 行 | F-07 で +1、F-01 は既存行への追記(長くなれば +1)。F-04・F-06 は +0 |
| 両層 `AGENTS.md` | — | 変更なし | — |

### 衝突を避けた点
- F-02 を採らない(出所 1 行・journal リンク・knowledge 相互リンクと矛盾するため)
- F-07 の文言は hearing の「仮案+再検討の条件 → stable」を未確定扱いにしない
- status の語彙は draft / stable / deprecated + superseded_by のまま(記事の Proposed / Accepted / Superseded に揃えない。decision-record-terms が stable)
- 「書式は両層で共通」(ws `:23`)は保つ。層差は F-03(リポジトリ層のみ)だけで、これは層分けの帰結

---

## 5. 要確認(推測を含む点)
- 記事本文は未読。D-4 の解釈(F-03)と、A-1 が「トラッカー依存の番号」を嫌う趣旨である点(F-02)は要約からの推測
- 記事の失敗が本テンプレートの展開先で起きているかは未観測(`_archive/decisions/` 8 件には無い)。「採る」5 件はすべて予防
- ワークスペース層での「次のアクション混入」(F-01 ws)も未観測。template-cc が不要と判断するなら ws 側の F-01 は落としてよい(他 4 件は残す)

## 6. まとめ
| 判定 | 件数 | ID |
|---|---|---|
| 採る | 5 | F-01, F-03, F-04, F-06, F-07(いずれも `_template.md` のみ。AGENTS は触らない) |
| 採らない | 9 | F-02, F-05, F-08, F-09, F-10, F-11, F-12, F-13, F-14 |

採る=5 採らない=9
