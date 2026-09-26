---
name: tanaoroshi
description: >
  ナレッジと現在地の定期棚卸し(月1目安)。「棚卸しして」と言われたとき、
  stale_after 超過や deprecated の記録が溜まってきたとき、learnings.md や AGENTS.md が
  行数上限に近づいたときに使用。鮮度点検・昇格候補の抽出・上限チェックを行い、
  変更はすべて提案としてまとめてユーザーの承認後に実行する。
---

# tanaoroshi — 定期棚卸し

古い・未検証の記録を放置すると、AIがそれに自信満々に従う。定期的に鮮度を点検し、
育った学びを恒常層へ昇格させ、恒常層の肥大化を防ぐ。

## 範囲

- ワークスペース直下で実行: ワークスペースの `docs/decisions/`・`STATUS.md` に加え、
  `repos/` 配下の各リポジトリも対象にするかユーザーに確認する
  (`docs/knowledge/` はリポジトリ層のみ — 手順 1 の knowledge はリポジトリを対象に含めたときだけ。
  `docs/learnings.md` と AGENTS.md の上限は両層で見る)
- リポジトリ直下で実行: そのリポジトリのみ(現在地は `docs/STATUS.md`)

## 手順(結果は提案としてまとめ、承認後に実行する)

1. **決定・ナレッジの鮮度点検** — `docs/decisions/`・`docs/knowledge/`
   (`_template.md` は除く)を走査する:
   - `stale_after` 超過 → 内容を現状と照合し、更新か `status: deprecated` 化を提案
   - `deprecated` なのに `superseded_by` が無い → 後継の明記を提案
   - `draft` のまま動きが無い → ユーザー承認を取って `stable` 化、または破棄を提案
2. **learnings の昇格** — `docs/learnings.md` を読み、繰り返し効いている学びを
   昇格候補として提案する: 機械的に強制できる → hooks / パス限定 → `docs/rules/` /
   多段階の手順 → `.agents/skills/`(+ `.claude/skills/` の symlink)/ それ以外の恒常ルール → AGENTS.md。
   昇格が承認されたら learnings 側のエントリを `→ 昇格: <昇格先>(YYYY-MM-DD)` の1行に畳む
   (毎セッション読むので本文は残さない。経緯は git と昇格先に残る)。
   multi-agent 導入済みなら `docs/learnings/*.md`(1エントリ1ファイル)が統合されずに
   残っていないかも見る
3. **上限チェック** — AGENTS.md(ワークスペース100行 / リポジトリ100行、multi-agent
   モジュール導入済みなら150行)・learnings.md(100行)の行数を確認し、
   超過・接近していたら「この行を消したらAIがミスするか?」で削除候補と逃がし先を提案
4. **現在地の整理** — `STATUS.md`(リポジトリなら `docs/STATUS.md`。ワークスペースなら
   宿題欄も)から、済んでいるのに残っている項目・動きの無い「次の一手」を洗い出し、
   消し込み・見直しを提案
5. **実行と記録** — 承認された分だけ実行する。ワークスペース配下なら `journal/` に
   実施の1行を残す

## 原則

- 勝手に削除・deprecated 化しない。すべて根拠付きの提案 → ユーザー承認 → 実行
- 本文を変更した記録の既存 `verified` は削除する(検証は失効する。誤字修正は除く)
