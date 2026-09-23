---
name: 統合タスク(fan-in)
about: 複数の実装タスク完了後に行う統合・結合テストタスク
title: ""
labels: blocked
---

## 統合内容
<!-- AとBの結果をどう組み合わせるか -->

## 対応スペック
<!-- 例: changes/<name>/tasks.md の 5.(統合検証)。スペック不要なら理由を書く -->

## 担当範囲(他のIssueと競合しないよう、パスのglobで明記)
<!-- 例: tests/e2e/** と docs/**(統合後の共有文書更新を含む場合はここに書く) -->

## 依存Issue(必須・このフォーマットを厳守してください)
<!-- "Depends on:" で始まる1行に、このリポジトリのIssue番号を #番号 で列挙します -->
Depends on: #, #

## 完了条件
<!-- 例: E2Eテストが通り、deploy-checklistの全項目をクリアしていること -->

---
このIssueは `blocked` ラベルで作成されます。
依存Issueが全てclose(=対応PRがmainにマージ)されると、自動的に `todo` に切り替わります。
依存Issueが再オープンされた場合は自動的に `blocked` に戻ります。
