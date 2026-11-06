# review-fable: 決定論ガードレールの棚卸し提案のレビュー(2026-11-06)

レビュアー: review-fable(Claude Code・Claude Fable 5.1)。review-astra のファイルは未読。
読んだもの: BRIEF.md の要約、proposal.md、両層 AGENTS.md、`scripts/{check-proposal-approved,check-credentials,hooks-selftest}.sh`、
両層 `.claude/settings.json`・`.codex/hooks.json`、`.agents/skills/*`(両層)、`templates/repo/changes/_template/proposal.md`、
`templates/repo/docs/decisions/_template.md`、`_archive/decisions/`(2026-07-25 × 6・2026-09-23 × 2)。
ネットワークは ctx7 CLI で Claude Code 公式ドキュメント(code.claude.com)と openai/codex のソース(main)を参照。

## 結論

- 指摘 #2(AI が自分で `[x]` を書けば承認ゲートが通る)は**正しい**。2 を今入れることに賛成
- ただし **Codex の `ask` は「未対応で deny に落ちる」のではなく「未対応で素通り(fail-open)」**。proposal の
  「Codex で効かなければ deny」は、スクリプトが CLI を確実に見分けられる形でないと成立しない
- 2 には `ask` を使わない**より小さい形**(deny のみ+人間が1文字書く)があり、未確認事項が全部消える。まずそれを勧める
- 1・4 は Claude Code なら `permissions.ask`(設定数行・スクリプト無し)で足りる。1・3 を (b) に回す推奨には賛成

## 観点2: 指摘 #2 の事実確認

- **正しい。** ゲートの対象は `*/changes/*/design.md | tasks.md` だけで、`proposal.md` への書き込みは対象外(`check-proposal-approved.sh:101-105`)。
  承認の検査は行頭 `- [x] ユーザー承認` の有無だけ(同 `:123`)。同一パッチ内での記入を根拠にしない規則(同 `:19-20`・`:109-115`)は
  Codex の1パッチにしか効かず、「1回目: proposal に `[x]` を書く → 2回目: design を書く」の2回の呼び出しは両 CLI とも通る
- 雛形自身が「このチェックは…**AI が記入する**」と書いている(`templates/repo/changes/_template/proposal.md:53`)。
  つまり決定論で検査しているのは「順序」(proposal が先)だけで、「人間が承認したか」は AI の判断のまま。
  記事の「検査は AI でなく処理系」に最も反する箇所という proposal の評価に同意
- `ask`(Claude Code)で塞ぐ筋はよい。ただし `ask` が返すのは**判断**だけで、日付・承認発言の原文は AI が打ったまま
  (2026-11-03 の書式を前提にすれば許容範囲だが、「記録が決定論になる」とは言わないこと)
- 別案「承認原文の欄の必須化」(正規表現で日付と「…」の非空を要求)は AI が埋められるので人間ゲートの代わりにならない。
  監査性は上がるので、2 の**補助**として入れるなら可(正規表現1行+ケース2件)。全角括弧などで脆くなる点は要注意

## 観点3: `ask` の実現性

### Claude Code(公式ドキュメント)

- **確認できた**: stdout に `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"…"}}` を出して exit 0。
  `ask` は利用者に確認を求め、reason はプロンプトに表示される(https://code.claude.com/docs/en/hooks「PreToolUse decision control」)。
  プラグイン例の「stderr + exit 2」はブロック専用で、`ask` には使えない
- **確認できた**: `-p`(非対話)で答えられる人がいない場合、呼び出しは**拒否**され、reason が tool result で Claude に渡る(同上)。fail-closed
- **確認できた**: auto モードでは hook の `ask` は分類器を経ずに権限プロンプトへ行く(同「PreToolUse ask decisions in auto mode」)
- **要確認**: `bypassPermissions`・`dontAsk` での hook `ask` の扱い。ドキュメントで確認できたのは `permissions.ask` **ルール**が
  bypassPermissions でも問い、dontAsk では拒否されること(https://code.claude.com/docs/en/settings-reference)。hook の `ask` についての明記は見つけていない
- **要確認**: hooks-guide に「exit 2 と stdout JSON は hook ごとにどちらか一方(choose one approach per hook)」とある。
  既存スクリプトは exit 2 流儀なので、同じスクリプト内に `ask` の JSON 分岐を足す形は要検証

### Codex(openai/codex main のソース。ローカル版は review-astra の確認待ち)

- `ask` はスキーマの enum にはあるが、出力パーサが **`unsupported permissionDecision:ask` として invalid 扱い**にする
  (`codex-rs/hooks/src/engine/output_parser.rs`)
- invalid な出力は status `Failed` になり `should_block` は false のまま → **ツール呼び出しは実行される(fail-open)**
  (`codex-rs/hooks/src/events/pre_tool_use.rs` `parse_completed`)。同じく fail-open: exit 0/2 以外、タイムアウト、
  未知フィールドを含む JSON(`deny_unknown_fields`)。ブロックできるのは `deny`+非空 reason、または exit 2+stderr のみ
- 帰結: **Codex に `ask` を出すと黙って通る。** 「効かなければ deny」ではなく、スクリプトが Claude Code だと**確実に分かるときだけ** `ask`、
  不明なら deny にしなければならない
- CLI の見分け方は環境変数に頼れない。`.claude/settings.json:7` は `$CLAUDE_PROJECT_DIR` で hook を呼ぶが、codex スキルは Claude Code の
  セッション内から `codex exec` を起動する(`.agents/skills/codex/SKILL.md:22-28`)ので、Codex の hook にもこの変数が継承される。
  見分けるなら各 hooks 設定で明示引数(例: `--cli claude-code` / `--cli codex`、無指定は deny)
- proposal の deny 時メッセージ「ユーザーの承認を得てから再実行してください」は**成立しない**。再実行しても同じ deny になる。
  「承認欄はユーザー自身が記入する」と返す必要がある

## #2 の形: 2案

| | A: `ask`(proposal 案+修正) | B: deny のみ |
|---|---|---|
| 仕組み | Claude Code: `[x]` を新たに入れる編集で `ask`。Codex: deny。CLI は明示引数で判定、不明は deny | 両 CLI とも、編集ツールが `changes/*/proposal.md` に `[x] ユーザー承認` を**新たに持ち込む**なら exit 2。AI は `- [ ] ユーザー承認(日付 / 対象 / 原文:「…」)` まで書き、`[ ]`→`[x]` の1文字はユーザーが書く(エディタ、または Claude Code の `!` 行) |
| 人間の操作 | プロンプトで承認 | 1文字の編集 |
| 未確認事項 | bypass/dontAsk での hook `ask`、exit 2 と JSON の混在、CLI 判定、Codex 版差 | なし(deny は両 CLI の既存経路そのもの) |
| 費用 | スクリプト分岐+両 hooks 設定の変更+selftest に stdout 検証の追加(`hooks-selftest.sh:9-18` の `run()` は終了値しか見ない) | 既存ゲートに分岐1つ+ケース5件程度。`run()` そのまま |
| 弱点 | Codex では結局 B と同じ | ユーザーの手間がわずかに増える。`ask` より体裁は劣る |

推奨: **まず B。** A は (b) の実 CLI 検証と一緒に、Claude Code 向けの改善として後から足せる(B の上に `ask` を重ねる形で両立する)。
判定ロジックは B・A 共通: Claude Write は disk の proposal と比較して「新規」を判定、Edit は old_string に無く new_string にある、
Codex は `+` 行。`[x]`→`[ ]`(再承認のための解除)は通す。`_template/` は除外

## 観点1: 表の漏れ・判定

- 判定に異論なし(1〜15)。10 は 2 の判定ロジックを (glob, パターン) の表で持てば追加費用は小さいが、stable 化のたびに
  プロンプトか手編集が入る摩擦はユーザーに確認したい。tanaoroshi の「勝手に deprecated 化しない」(`tanaoroshi/SKILL.md:40`)も同じ型
- 表に無いもの:
  - 「承認後にスコープが変わったらチェックを外して再承認」(`_template/proposal.md:56`・`templates/repo/AGENTS.md:31`)— 機械判定は
    曖昧(完了報告の追記は正当)。見送りだが表には載せる
  - ワークスペース AGENTS.md §4「実プロジェクトは private で運用」— `gh repo create --public`・`gh repo edit --visibility` はシェル経路。4 の束に入れる
  - git-commit スキル「ユーザーの未コミット変更を `git add .` で一括しない」(`git-commit/SKILL.md:14`)— シェル経路。同じく 4 の束
  - 「本文変更時は既存 verified を削除」(`decisions/_template.md`)— 曖昧。見送り
- 1 と 4 は Claude Code なら **`permissions.ask` で足りる**(スクリプト不要): `Edit(path)` ルールは Write・NotebookEdit も含む全編集ツールに効き、
  `Write(path)` は一致しない(https://code.claude.com/docs/en/permissions)。例: `"ask": ["Edit(AGENTS.md)", "Edit(.agents/skills/**)", "Edit(.claude/**)", "Edit(.codex/**)", "Edit(scripts/check-proposal-approved.sh)", "Edit(scripts/check-credentials.sh)"]`。
  4 は `Bash(git push *)` がドキュメントの例そのもの。いずれも acceptEdits・bypassPermissions でも問う(settings-reference)。
  Codex に同等物は無く、1 を deny hook にすると AI が AGENTS.md を一切編集できなくなるので、Codex は規則(AGENTS.md)のまま
  — 2026-09-23 の「同じスクリプトを両 CLI に」からは外れるが、同決定の「hooks を持たない CLI の規範は AGENTS.md」には沿う
- proposal 内の矛盾: 「新しいスクリプトは作らず」と「新しいスクリプト `check-human-gate.sh`(仮)」が並んでいる。2 は承認ゲートの穴なので
  `check-proposal-approved.sh` に入れるのが自然(1・3 を後で入れるときに分けるか決めればよい)

## 観点4: 既存の決定との整合

- 2026-09-23「義務は増やさない」: 2 は既存ゲートの保証の穴を塞ぐ修正で、AI の義務は増えない。1・3 は新しい hook 対象で、
  規則は既にあるが人間側の確認が増える(予防的)。proposal の整理に同意
- 2026-07-25「learnings から昇格」: 既存の2 hook も learnings 由来ではない(承認ゲートは 2026-07-25 changes-spec-driven、認証情報検出は 2026-09-23)。
  「昇格」は学びが規範に育つ経路であって、設計時のガードの唯一の入口ではない。よって 2 を (a) にするのに 07-25 の例外扱いは不要。
  1・3 を (b) に回すのは、摩擦が未観測だから — 推奨に賛成
- 前提3(編集経路のみ)は維持。B 案でも `sed` でチェックを入れる抜け道は残る(今と同じ)

## 観点5: 費用

- B 案の 2: 分岐1つ+ケース5件程度。A 案はこれに hooks 設定 2×2 ファイルの変更と selftest の stdout 検証が乗る
- 1・4 は `permissions.ask` ならケース0件(hooks-selftest の対象外)。保守時の確認の多さは実案件で測る
- 3 は日付比較と除外(`_template.md`・README)で小さくないわりに害が小さい。(b) 以降でよい

## 判断してほしいこと 1〜4 への意見

1. 時期: 2 は (a)、1・3 は (b) — 賛成。ただし 2 は B 案(deny のみ)で入れ、`ask` は (b) で実 CLI を確かめてから
2. 範囲: 2(+補助として承認行の書式検査を入れるなら可)。10 は表駆動なら安価だが摩擦はユーザー判断。1 を入れるなら `permissions.ask`
3. シェル経路: 別提案に賛成。Claude Code 側は `permissions.ask` 数行で済むので、小さい提案で早く出せる
4. 実装前の独立レビュー: 2 を B 案で入れるなら diff が小さく、selftest で検証できるので、実装後の確認で足りる

採る=2 見送り=3,6,7,8,9,11,12,13,14,15 推奨=修正
