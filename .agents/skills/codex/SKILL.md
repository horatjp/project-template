---
name: codex
description: |
  Codex CLI(OpenAI)にセカンドオピニオンを求める時に使用。codex を名指しした相談・レビュー依頼、
  別ベンダーのAIの意見を求める依頼、lens-review で別ベンダーのAIにも同じレンズで見せる時。
  codex の指定がない通常のレビュー・調査依頼には使用しない。
---

# Codex CLI ヘルパー

Codex CLI(OpenAI)を使用して、コードや設計についてセカンドオピニオンを得たり、
レビューを依頼したりする。レビュー指摘の大半は単一のレビュアーしか検出しないため、
別ベンダーのAIを挟むと検出率が直接上がる。

先に `command -v codex` で CLI の存在を確認する。無ければ導入案内
(https://github.com/openai/codex)だけ report して止まる(勝手にインストールしない)。

## 実行方法

読み取りのみ(レビュー・調査。lens-review のレンズをプロンプトに含めると観点が揃う):

```bash
codex exec --sandbox read-only --skip-git-repo-check --cd "$PWD" "<リクエスト内容>"
```

ファイル書き込みあり(実装・修正):

```bash
codex exec --sandbox workspace-write --skip-git-repo-check --cd "$PWD" "<リクエスト内容>"
```

## 注意事項

- 結果はセカンドオピニオンとして参考にする。受け取った指摘は lens-review と同じ3値
  (対応する / 意図した設計として記録 / 見送り+理由)で仕分け、最終判断はユーザーに委ねる
- Codex の hooks(`.codex/hooks.json`)が検査するのは、プロジェクトを信頼済みのときの `apply_patch` による
  編集だけ(シェル経由の書き込みは対象外)。`workspace-write` で書かせた変更は diff を確認してから取り込む
- `read-only` モードではファイルの変更は行われない
