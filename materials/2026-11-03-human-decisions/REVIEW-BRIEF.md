# 実装レビューの依頼(2026-11-03)

依頼者: ユーザー(template-cc が実装)。レビュアー: review-astra(Codex CLI・Astra)。

## 対象

joint.md(同じフォルダ)の合意「条件付き賛成」を template-cc が実装した未コミット差分。
`git diff`(main 作業ツリー。写しは impl.diff)— 3ファイル:
- `templates/repo/changes/_template/proposal.md`(「ユーザーの判断」節・承認欄の原文化・完了報告の照合)
- `templates/repo/changes/_template/tasks.md`(完了報告の照合)
- `.agents/skills/hearing/SKILL.md`(記録節の反映先。100行に収めた)

## 見る観点

1. joint.md の条件 1〜8 を満たしているか、取りこぼし・逸脱(特に条件1 転記可/創作禁止、2 件数の扱い、3 区分に使わない、4 原文と問い・出所の対応、5 承認は proposal 全体)
2. 指示どおりに書いた AI が迷う・誤る箇所、既存規範(templates/repo/AGENTS.md「変更の進め方」、hearing の他の節、lens-review、README)との矛盾・参照切れ
3. 過剰(proposal.md は 52→71 行。joint の見積り +8〜12 を超えている。削れる行)
4. hooks: `scripts/check-proposal-approved.sh` の判定に影響しないか(selftest は両層 pass=50 を template-cc が確認済み。再実行してよい)

## 進め方・守ること

- 結果を `_devlog/materials/2026-11-03-human-decisions/review-astra.md` に書く。各指摘は 重さ(P1/P2/P3)・ファイル:行・何が起きるか・直し方の案(文言)。
  最終行を飾りなしで `P1=n P2=n P3=n`
- 書き終えたら agmsg で template-cc に知らせ、`hc send t16 '報告した'` と一言知らせる
- 読むこと・上記ファイルを書くこと・hooks-selftest の実行だけ。ファイル変更・commit・push・削除・ネットワーク取得はしない。秘密を読まない
