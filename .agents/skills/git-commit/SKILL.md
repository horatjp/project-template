---
name: git-commit
description: Gitコミットの作成を依頼された時に使用。「コミットして」「commit」などの指示や、作業の区切りでコミットが必要になった時。
context: fork
---

# Gitコミットヘルパー

変更内容を分析して適切なコミットメッセージを生成し、コミットを実行する。

## 基本原則

1. **Conventional Commits準拠**
2. **ハンク単位・論理的な単位に分割し、独立してリバート可能なコミットを作成**
3. **Gitmojiで視覚的に分かりやすく**
4. **プロジェクトの言語に合わせたメッセージ（READMEから自動検出）**

## 実行手順

### 1. プロジェクトの言語を検出

```bash
cat README.md 2>/dev/null || cat README 2>/dev/null
```

- 日本語文字（ひらがな・カタカナ・漢字）が多い → 日本語
- それ以外 → 英語

### 2. 過去のコミットを参照

```bash
git log --oneline -10
```

- 使われているGitmojiのパターンを把握する
- コミットメッセージの粒度感・文体を合わせる
- プロジェクト固有の慣習（scope記法など）を確認する

直近10件に今回使う type の実例がない場合のみ、過去を検索する：

```bash
git log --oneline --grep='<type>' -20
```

### 3. 現在の状態を確認

```bash
git status
git diff --staged
# ステージされた変更がない場合
git diff
```

### 4. 変更を論理的な単位で分析・分割

論理的に独立した単位ごとにコミットを分割する。

**ファイル単位で分割できる場合（基本）:**

```bash
git add <file1> <file2>
```

**1ファイル内に複数の変更が混在する場合（ハンク単位の分割）:**

対話的な `git add -p` はこの環境では使用できない。パッチ編集で部分ステージする：

```bash
# 1. 文脈行を減らした差分を一時ファイルに保存（近接した変更がハンク分離しやすくなる）
git diff -U1 -- <file> > /tmp/split.patch

# 2. パッチを編集し、先にコミットしたい変更のハンクだけ残す
#    ハンクは @@ 行から次の @@ 行の手前まで。ハンク単位で丸ごと削除し、@@ 行の数値は書き換えない

# 3. 編集したパッチをインデックスに適用し、内容を確認
git apply --cached /tmp/split.patch
git diff --cached
```

**分割の判断基準：**
- 各コミットが単独で意味を持つ（単一責任）
- バグ修正とリファクタリングは別コミット
- 新機能とフォーマット修正は別コミット
- 各コミット後もビルド・テストが通る状態を維持

### 5. コミットメッセージを生成・実行

```bash
git commit -m "$(cat <<'EOF'
<gitmoji> <type>(<scope>): <subject>

<body（任意）>

<footer（任意）>
EOF
)"
```

## コミットメッセージの形式

```
<gitmoji> <type>: <subject>
```

**例:**
```
✨ feat: ユーザー認証機能を追加
🐛 fix: ログインフォームのバリデーションエラーを修正
♻️ refactor: データベース接続処理をモジュール化
```

## Gitmoji マッピング

### 最頻出

| Gitmoji | Code | Type | 説明 |
|---------|------|------|------|
| ✨ | :sparkles: | feat | 新機能の追加 |
| 🐛 | :bug: | fix | バグ修正 |
| 🚑 | :ambulance: | fix | 緊急の修正（ホットフィックス） |
| ♻️ | :recycle: | refactor | リファクタリング |
| ⚡️ | :zap: | perf | パフォーマンス改善 |
| 🎨 | :art: | style | コード構造/フォーマットの改善 |
| 📝 | :memo: | docs | ドキュメント追加・更新 |
| ✅ | :white_check_mark: | test | テスト追加・更新 |
| 🔒️ | :lock: | fix | セキュリティ/プライバシー問題の修正 |
| 🔥 | :fire: | - | コード/ファイルの削除 |

### 最頻出に該当がない場合

依存関係・UI/UX・CI/ビルド・コード品質などのGitmojiは、同ディレクトリの `gitmoji-reference.md` を参照する。

## 分割例

**悪い例（まとめすぎ）:**
```bash
git add .
git commit -m "✨ feat: ユーザー機能追加とバグ修正と依存関係更新"
```

**良い例（適切に分割）:**
```bash
# 1. 依存関係の更新
git add package.json package-lock.json
git commit -m "⬆️ build: React を 18.2 から 18.3 にアップグレード"

# 2. バグ修正
git add src/components/LoginForm.tsx
git commit -m "🐛 fix: メールアドレス検証の正規表現を修正"

# 3. 新機能
git add src/components/UserProfile.tsx
git commit -m "✨ feat: ユーザープロフィール編集機能を追加"

# 4. テスト
git add src/components/__tests__/UserProfile.test.tsx
git commit -m "✅ test: ユーザープロフィール編集のテストを追加"
```

## コミット前のチェックリスト

- [ ] 変更は論理的に独立しているか？
- [ ] リバートしても他のコミットに影響しないか？
- [ ] コミットメッセージは明確か？
- [ ] 適切なGitmojiが選択されているか？
- [ ] テストは通るか？

## トラブルシューティング

### コミットが大きすぎた・間違ったファイルをコミットした場合

`git reset` が権限設定で拒否される環境では、ユーザーに実行を依頼する：

```bash
# ユーザーに `! git reset --soft HEAD~1` の実行を依頼
# その後、ステージングを整理して新しいコミットを作成
git restore --staged <不要なファイル>
git commit -m "メッセージ"
```

## プロジェクトへの適応

このファイルは雛形。プロジェクトに既存のコミット規約(Gitmoji を使わない・
言語固定・scope 必須など)があれば、形式・マッピングの節を書き換えて合わせる。
