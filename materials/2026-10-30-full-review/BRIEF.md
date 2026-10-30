# テンプレート全体レビューの依頼(2026-10-30)

依頼者: ユーザー(template-cc が取りまとめ)
参加者: review-fable(Claude Code・Claude Fable 5.1)、review-astra(Codex CLI・Astra)。agmsg のチームは project-template。

## 目的

project-template(ワークスペース層+リポジトリ層テンプレート)全体を、実プロジェクトで AI が
このルールに従って作業したときに「迷う・誤る・矛盾する・過剰で守られない」箇所を見つける。
特に 2026-10-30 の main `0f515ef`(契約による設計・副作用の分離)が全体と噛み合っているかを重点的に見る。

## 見る範囲

リポジトリ: /Users/horatjp/projects/project-template(main。`git ls-files` の約65ファイル)

1. **重点: `0f515ef`** — `git show 0f515ef`。templates/repo/AGENTS.md「コードの設計」節・
   changes/_template/design.md「契約」節・lens-review の correctness 観点
2. **リポジトリ層** — templates/repo/ 一式(AGENTS.md・changes/_template/・docs/ の _template・スキル・hooks・scripts)
3. **ワークスペース層** — AGENTS.md・README.md・.agents/skills/・.claude/・.codex/・scripts/・各 README と _template
4. 層をまたぐ整合(同じ規範の書き方の食い違い、片方だけ直された箇所、参照切れ、行数上限)

対象外: _devlog/・_archive/(保守者のローカル資料)。ただし経緯の確認に _devlog/journal/ を読むのはよい。

## 見る観点(この順で重視)

1. 指示どおりに動いた AI が誤る・事故を起こす箇所(安全・不可逆操作・秘密・承認の抜け)
2. 規範どうしの矛盾、定義のない用語・参照切れ、壊れた書式
3. 守られない・判断がつかない指示(どこに書くか、いつ適用するかが決まっていない)
4. 過剰・冗長(消しても AI がミスしない行。各 AGENTS.md は100行以下)
5. hooks・scripts の不具合(`scripts/hooks-selftest.sh` は両層にある。読むだけでなく実行してよい)

## 進め方

1. 最初は相手のファイルを読まず、独立に `_devlog/materials/2026-10-30-full-review/<fable|astra>.md` に書く。
   各指摘は 重さ(P1/P2/P3)・ファイル:行・何が起きるか・直し方の案。推測は「要確認」と明記
2. 書き終えたら最後の行を飾りなしで `P1=n P2=n P3=n` にし、agmsg で template-cc と相手に知らせる
3. 両方そろったら、相手と賛否を最大3往復までやり取りする
4. review-fable が `joint.md` に合意した指摘・意見が割れた指摘・やめてよいものをまとめ、
   最後の行を `合意 P1=n P2=n P3=n` にして template-cc に知らせる

## 守ること

- やってよいのは読むことと、上記の報告ファイルを書くことと、hooks-selftest の実行だけ。
  ファイルの変更・commit・push・削除・ネットワーク取得・有料の実行はしない
- 秘密を読まない(`.env`・`~/.codex/auth.json` 等)
- 受信箱は知らせを受けたときに確認する
