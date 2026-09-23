# STATUS — プロジェクトの現在地

<!--
作業の区切り・打ち合わせ後にAIが更新する。常に「今」だけを書き、経緯は journal/ と
docs/decisions/ に任せる。宿題は完了したら消す(履歴は journal に残っている)。
-->

## 進行中

(なし — 2026-09-23 のテンプレート改善は第1ラウンド・第2ラウンド群1〜3とも Codex の verifier 承認を得て
コミット済み。経緯は journal/2026-09-23.md)

## 宿題(open)

<!-- 形式: - [ ] 内容 / 担当 / 期限 / 出所: journal/YYYY-MM-DD.md -->

## 次の一手

- multi-agent スクリプトの実 GitHub ドライラン。対象リポジトリは**未確定**(使い捨ての private
  リポジトリをユーザーが指定する)。手順: 指定リポジトリで `scripts/setup-labels.sh` → task.md 形式で
  Issue を2件(片方に `Depends on:`)→ `spawn-worktree.sh` → PR 作成・マージ → `check-blocked.sh` で
  blocked→todo を確認 → `cleanup-worktree.sh --force`。合格条件: 各段階の出力が
  `templates/modules/multi-agent/README.md` の説明どおり、かつ削除されたのは対象 worktree/ブランチのみ。
  後片付け: テスト用リポジトリの削除(ユーザー実施)。合成テストはこのワークスペースでは
  `templates/modules/multi-agent/tests/synthetic.sh`(展開先では `<repo>/tests/synthetic.sh`)で再実行できる
- Codex 側の hooks 実発火の確認: 新規 Codex セッションで `.codex/hooks.json` の信頼確認画面まで確認済み。
  人間が信頼した後に「proposal 無しで changes/<x>/design.md を apply_patch」してブロックされることを確認する
  (合成テスト `scripts/hooks-selftest.sh` は 28 ケース pass。Claude Code 側は実発火確認済み)
- 見送り2件の再検討: ワークスペース層 learnings.md の新設 / requirements の置き場の一本化

## 最終更新

- 日付: 2026-09-23
- 更新者: Claude Code(template-cc)
