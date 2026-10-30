# テンプレート全体レビュー — review-fable(Claude Code / Claude Fable 5.1)2026-10-30

依頼: BRIEF.md。対象: main `0f515ef` の `git ls-files` 65 ファイル(_devlog/・_archive/ は経緯確認のみ)。
相手(review-astra)のファイルは未読。

重さの定義: **P1** = 指示どおり動いた AI が事故る・承認や安全が抜ける / **P2** = 矛盾・参照切れ・判断がつかず迷う /
**P3** = 軽微な書式・用語・冗長・改善提案。推測は「要確認」と明記。

実行したもの: `bash scripts/hooks-selftest.sh` と `bash templates/repo/scripts/hooks-selftest.sh` — 両層とも
**pass=28 fail=0**(`/bin/bash` 3.2.57、PATH の bash も 3.2.57。macOS 既定の bash で動く)。
3 本のスクリプトは両層で `diff` 一致。

---

## A. 重点: `0f515ef`(契約による設計・副作用の分離)

総評: 「変更の進め方」「記録」「安全」のどれとも矛盾しない。適用範囲を業務ルールに限る 4 項目目と、
「テストは書いた条件しか保証しない」の併記で過剰適用の歯止めもある。置き場所(リポジトリ層のみ)も妥当。
噛み合っていないのは「契約をどこに書くか」が標準区分以外で決まっていない点(F-01)。

### F-01 【P2】契約の書き先が「標準」以外で未定義
- 場所: `templates/repo/AGENTS.md:39-40`、`templates/repo/changes/_template/design.md:26-28`、
  `templates/repo/changes/_template/proposal.md:42-45`、`templates/repo/AGENTS.md:33`
- 何が起きるか: AGENTS は「実装の前に事前・事後・不変条件を**書き出し**」と命じるが、受け皿は design.md の
  契約節だけ。軽量区分(design を書かない)と、スペック不要の変更(業務ルール関数のバグ修正・リファクタ)では
  書き先が無い。AI は (a) 省略する、(b) proposal の実装メモに勝手な書式で書く、(c) コードのコメントに書く、
  のどれかに割れ、lens-review の correctness(F-03)は照合先を失う。
  加えて design.md は「**主要な**関数・クラスごとに」、AGENTS は「業務ルール・計算を担う関数・クラス」(主要の限定なし)で、
  design に書かなかった関数の契約をどこに書くかも決まらない。
- 直し方: AGENTS の 1 項目目に書き先を 1 文で足す。例:
  「書き先は design の契約節(軽量は proposal の実装メモに『契約:』行、スペック不要の変更はテストコードの名前・docstring)」。
  design.md 側は「主要な」を外すか、AGENTS 側に「主要な」を入れて揃える。

### F-02 【P3】design.md 内で「契約」が 2 義
- 場所: `templates/repo/changes/_template/design.md:17`(データ・API契約の変更)と `:26`(契約(事前・事後・不変条件))
- 何が起きるか: 同じ文書に「API 契約(インターフェース仕様)」と「契約による設計(DbC)」が並び、
  AGENTS の「契約」がどちらを指すか読み手が一拍迷う。致命ではない。
- 直し方: 17 行目を「データ・API 仕様の変更」に改名するのが最小。

### F-03 【P3】lens-review correctness の追加行に「該当なし」の扱いが無い
- 場所: `templates/repo/.agents/skills/lens-review/SKILL.md:26`
- 何が起きるか: correctness は全変更種別の必須レンズ。UI 配線だけの変更(AGENTS 4 項目目で適用外)でも
  レビュアーが「契約がテストで押さえられていない」と形式的に指摘し、実装者が 3 値仕分けの手間を負う。
- 直し方: 「(design の契約節が『なし』なら対象外。業務ルールが混ざっていれば『なし』の妥当性を見る)」を添える。

### F-04 【P3】副作用の分離先が抽象的
- 場所: `templates/repo/AGENTS.md:41-42`
- 何が起きるか: 「名前とシグネチャに表れる場所へ分離」は原則としては正しいが、具体例が無いので
  判定が AI ごとに揺れる(戻り値型で表すのか、`save`/`send` の動詞で表すのか)。
- 直し方: 括弧で 1 例足す。例:「(例: `calcTotal` は DB を読まない・書かない。保存は `saveOrder` に分ける)」。
  行数が厳しければ見送ってよい(F-10 参照)。

---

## B. リポジトリ層(templates/repo/)

### F-05 【P1】自己権限拡大の対象に `scripts/`(hooks の実体)が無い
- 場所: `templates/repo/AGENTS.md:80-81`、ワークスペース `AGENTS.md:61`
- 何が起きるか: `.claude/settings.json`・`.codex/hooks.json` は承認なしの変更を禁じているが、両者は
  `scripts/check-proposal-approved.sh`・`check-credentials.sh` を呼ぶだけ。hooks が誤検知したとき
  (例: `sk-` で始まる長い識別子)、AI は列挙されていない `scripts/` 側を「バグ修正」として直せてしまい、
  承認ゲートやシークレット検出が黙って弱まる。README:148-149 は「hooks は決定的に実行される」と信頼を置いているので、
  この穴は設計の前提を崩す。
- 直し方: 両層の列挙に `scripts/`(hooks が呼ぶスクリプト)を加える。1 行で済む。
  併せてワークスペース `AGENTS.md` §1 の構成表に `scripts/` が無いので、「hooks 用スクリプト(.claude/.codex が呼ぶ)」の 1 行を足すと
  なぜ触ってはいけないかが読める。

### F-06 【P2・要確認】承認ゲートがシェル経由の書き込みで素通りする(ハーネス依存)
- 場所: `templates/repo/.claude/settings.json:5`(matcher `Write|Edit`)、`templates/repo/AGENTS.md:22-24`、`README.md:146-160`
- 何が起きるか: README は「シェル等の別経路は対象外」と明記しているが、これはシークレット検出についての注記で、
  承認ゲート側にはこの但し書きが AGENTS.md に無い。Claude Code の一部モード(今回のレビューセッションもそう)は
  ファイル変更を Edit/Write ではなく Bash の heredoc・sed で行うよう指示するため、その環境では
  design.md/tasks.md の承認ゲートが一度も発火しない。「hooks で機械的に強制」(README:41)は、そのハーネスでは成り立たない。
  要確認: どのモード・バージョンで Bash 経由の編集が既定になるかは環境差がある。
- 直し方(段階案):
  1. 最小: AGENTS「変更の進め方」に「承認ゲート hooks は編集ツール経路のみ。シェル経由で design/tasks を書かない」を 1 行
  2. 本命: `Bash` matcher の hook を 1 本足し、`tool_input.command` に `changes/<x>/(design|tasks).md` への
     リダイレクト・heredoc・`tee`・`cp`・`mv` が含まれたら同じ proposal 検査にかける(高確度パターンのみ・誤検知は exit 0 側に倒す)。
     selftest にケースを足す。

### F-07 【P3】AGENTS.md 末尾の箇条書き 2 件が 1 行に結合(実質 98 行)
- 場所: `templates/repo/AGENTS.md:97`(`…Noなら削除する- 手順・チェックリストは…`)。`b9e263e` の編集で改行が落ちた。
- 何が起きるか: 「手順は skills へ、パス限定は docs/rules へ逃がす」の規範が行末に埋もれる。`wc -l` が 97 を返し、
  tanaoroshi の上限チェックが 1 行過小評価する。全新規リポジトリにそのままコピーされる。
- 直し方: 「削除する」の後で改行する。

### F-08 【P3】「active な決定記録」が未定義の用語
- 場所: `templates/repo/AGENTS.md:23`
- 何が起きるか: decisions の status は draft / stable / deprecated。「active」が stable のみか draft も含むか決まらず、
  draft の決定を覆す変更がスペック必須かどうかで判断が割れる。
- 直し方: 「`stable` な決定記録を覆す変更」に置き換える(README:37-38 は「既存の決定を覆す変更」で、こちらも揃える)。

### F-09 【P3】push の扱いがリポジトリ層 AGENTS.md に無い
- 場所: `templates/repo/AGENTS.md:75-77`(不可逆操作の列挙)、ワークスペース `.agents/skills/session-end/SKILL.md:29`(「プッシュは提案まで」)
- 何が起きるか: 「main へのマージ・リリース・公開は人間」「コミットは節目ごと」は書かれているが push は無言。
  session-end スキルが無い単体リポジトリのセッションでは、AI が push を「外部への送信」と読むかで挙動が割れる。
- 直し方: 不可逆操作の括弧内に「push」を 1 語足す(「削除・復元不能な上書き・push を含む外部への送信・課金」)。

### F-10 【P3】100 行上限の余裕が 2 行。圧縮候補
- 場所: `templates/repo/AGENTS.md`(F-07 修正後 98 行)
- 何が起きるか: F-01・F-05・F-09 を入れると上限に触れる。
- 候補(消しても AI がミスしない見込みのもの):
  - `:95-97` 「このファイルの保守」節 → 見出しを落として安全節末尾の 1 行に畳む(−2 行)
  - `:39-44` 「コードの設計」4 項目 → 1・3 項目目を結合(「…先に書いてから実装する。テストが保証するのは書いた条件だけ — 条件が要件から読めなければ確認する」)(−1〜2 行)
  - `:82` worktree 隔離は README「運用の要点」にもあるが、AGENTS から消すと守られないので残す

### F-11 【P3】開始手順の文言: requirements.md は「作る」ではなく「記入する」
- 場所: `templates/repo/AGENTS.md:6`
- 何が起きるか: `docs/requirements.md` は雛形として既に存在する。「作り」と読んだ AI が別名で新規作成する余地がある(小)。
- 直し方: 「ヒアリングで `docs/requirements.md` を記入し」。

### F-12 【P3・要確認】check-credentials.sh のコメントと NotebookEdit
- 場所: `scripts/check-credentials.sh:11`(両層同一)、`.claude/settings.json:5`
- 何が起きるか: コメントが `MultiEdit` に言及するが、現行 Claude Code のツール一覧に MultiEdit は無い(Edit の replace_all に統合)。
  実害なし(jq 式は `edits[]?` で安全に無視)。一方 `NotebookEdit`(`new_source`)は matcher にも走査対象にも無く、
  ノートブックへのシークレット書き込みは検出されない。要確認: matcher の正規表現が部分一致なら `NotebookEdit` にも hook は
  発火するが、走査対象が空で素通りする。
- 直し方: コメントから MultiEdit を落とし、必要なら `.tool_input.new_source?` を走査対象に足す(2 行)。優先度は低い。

---

## C. ワークスペース層

### F-13 【P2】`templates/modules/` への参照が残っている
- 場所: ワークスペース `AGENTS.md:17`(「追加モジュール(`modules/`)」)
- 何が起きるか: `34cd66d` で `templates/modules/` は削除済み(`git ls-files` に無し)。毎セッション読む AGENTS.md が
  存在しないディレクトリを案内し、AI がユーザーに「追加モジュールがある」と説明したり探しに行ったりする。
  `b9e263e` の言及除去が AGENTS.md の構成表を取りこぼした(journal 2026-10-09 の grep 語に `modules/` が無かったのが原因)。
- 直し方: 「| `templates/` | 新規リポジトリ用テンプレート(`repo/`)。運用中は触らない |」。

(ワークスペース層のその他: `CLAUDE.md` symlink・`.claude/skills/` の 7 本の symlink・`.codex/hooks.json`・各 README と
`_template.md`・hearing / setup-repo / session-end / tanaoroshi / codex / git-commit / grill-me は、相互参照(「記録」節・
「宿題欄」・「記録の境界」・「テンプレートの保守」)をすべて追ったが参照切れ・矛盾は見つからなかった。)

---

## D. 層をまたぐ整合(問題なしの確認事項)

- 昇格先リスト(repo `AGENTS.md:62-65` / 両層 `docs/learnings.md` / `tanaoroshi:31-32` / `README.md:23-24`)— hooks → docs/rules → skills → AGENTS で一致
- `docs/decisions/_template.md` の両層差分 — 事業用(journal リンク・案件・関係者)と技術用(ADR・knowledge リンク・stale_after)の意図的な分岐。frontmatter は同一
- 「承認は明示的発言のみ・相槌は不可」— proposal.md:35-36 / hearing:32 / decisions _template:24-26 で一致
- 「verified は自己検証不可」— repo AGENTS:60-61 / ws AGENTS:49-50 / 両 _template / README:51-52 で一致
- 「不可逆操作の前に停止(STATUS・生きた文書の上書きは除く)」— 両層 AGENTS で同文
- hooks の設置説明(README:153-160「両層に同梱」)と実体(両層の settings.json・hooks.json・scripts/)が一致

## E. hooks・scripts の検証メモ

- 両層 selftest pass=28 fail=0(上記)。CRLF・SIGPIPE 回帰・パーサ無し環境・同一パッチ内承認の各ケースを含む
- bash 3.2 の `set -u` と空配列: `paths=("${paths[@]%/}")`(Delete のみのパッチ)は 3.2.57 で動作することを直接確認。
  `normalize_path` の `"${out[@]}"` は `..` だけで根を越えるパスでのみ unbound になるが、現実のパッチでは起きない(指摘なし・記録のみ)
- 相対パスの正規化・`*/changes/*/design.md` の glob が `changes/archive/<date>-<name>/design.md` にも当たる点は、
  archive 側に proposal.md が同居するので誤ブロックしない(確認済み)

## F. やめてよいもの(過剰・冗長)

- F-10 の圧縮候補以外に、消すべき行は見つからなかった。両 AGENTS.md の各行は「消すと AI がミスするか」で Yes 側。
  ワークスペース `AGENTS.md:49-51` は `docs/README.md` と重なるが、常時読む側に残す判断が妥当

---

## 集計

| 重さ | 件 | ID |
|---|---|---|
| P1 | 1 | F-05 |
| P2 | 3 | F-01, F-06(要確認), F-13 |
| P3 | 9 | F-02, F-03, F-04, F-07, F-08, F-09, F-10, F-11, F-12(要確認) |

P1=1 P2=3 P3=9
