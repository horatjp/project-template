---
name: codex
description: |
  Codex CLI(OpenAI)にセカンドオピニオンを求める時に使用。
  トリガー: 「codex」「codexと相談」「codexに聞いて」「codexにレビューしてもらって」など、codex を名指しした依頼。
  「別のAIの意見が欲しい」「セカンドオピニオンが欲しい」という依頼、
  lens-review で別ベンダーのAIにも同じレンズで見せる時にも使用。
  codex の指定がない通常のレビュー・調査依頼には使用しない。
---

# Codex CLI ヘルパー

Codex CLI(OpenAI)を使用して、コードや設計についてセカンドオピニオンを得たり、
レビューを依頼したりする。レビュー指摘の大半は単一のレビュアーしか検出しないため、
別ベンダーのAIを挟むと検出率が直接上がる。

先に `command -v codex` で CLI の存在を確認する。無ければ導入案内
(https://github.com/openai/codex)だけ report して止まる(勝手にインストールしない)。

## 使用場面

1. **コードレビュー** - 実装のレビューや改善提案(lens-review のレンズを
   プロンプトに含めると観点が揃う)
2. **設計の相談** - アーキテクチャやAPI設計のアドバイス
3. **バグ調査** - 問題の原因特定や解決策の提案
4. **文言・メッセージの検討** - エラーメッセージやUIテキストの改善
5. **解消困難な問題の調査** - 複雑な問題への別視点からのアプローチ

## 実行方法

読み取りのみ(レビュー・調査):

```bash
codex exec --sandbox read-only --skip-git-repo-check --cd "$PWD" "<リクエスト内容>"
```

ファイル書き込みあり(実装・修正):

```bash
codex exec --sandbox workspace-write --skip-git-repo-check --cd "$PWD" "<リクエスト内容>"
```

## 使用例

### コードレビューを依頼

```bash
codex exec --sandbox read-only --skip-git-repo-check --cd "$PWD" "src/auth.tsのコードをレビューして、改善点があれば教えてください"
```

### 設計相談

```bash
codex exec --sandbox read-only --skip-git-repo-check --cd "$PWD" "認証システムをJWTからセッションベースに変更する場合の影響範囲を分析してください"
```

## オプション

- `--sandbox read-only`: 読み取り専用(レビュー・調査向け)
- `--sandbox workspace-write`: ファイル書き込みあり(実装・修正向け)
- `--skip-git-repo-check`: trusted directory 外でも実行を許可
- `--cd <dir>`: 作業ディレクトリを指定

## 注意事項

- 結果はセカンドオピニオンとして参考にする。受け取った指摘は lens-review と同じ3値
  (対応する / 意図した設計として記録 / 見送り+理由)で仕分け、最終判断はユーザーに委ねる
- Codex の hooks(`.codex/hooks.json`)が検査するのは、プロジェクトを信頼済みのときの `apply_patch` による
  編集だけ(シェル経由の書き込みは対象外)。`workspace-write` で書かせた変更は diff を確認してから取り込む
- `read-only` モードではファイルの変更は行われない
