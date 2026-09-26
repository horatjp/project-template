# STATUS — project-template 保守の現在地

<!--
テンプレート保守作業の「今」だけを書く。経緯は journal/、設計判断の原本はローカルの _archive/。
-->

## 進行中

- 2026-09-26 のテンプレート全体見直し(3系統レビューの統合メモ: ローカル `_archive/2026-09-26-review/synthesis.md`)
  - A 群(事実誤り・バグ・矛盾)と CLAUDE.md の `@AGENTS.md` 化: 完了・コミット済み(main)
  - B 群(運営記録を dev-log へ移す): 完了・Codex 承認・コミット済み(main 9284081・後続の fix、dev-log)
  - C 群(引き継ぎの頑健化): 完了・Codex 承認・コミット済み(main)
  - D 群(ナレッジループ): D1〜D5 完了・Codex 承認・コミット済み(main)。D6(鮮度チェックスクリプト)はユーザー判断で見送り
  - E・F 群: 未着手。論点ごとにユーザーと相談して決める(ユーザー方針)

## 宿題(open)

<!-- 形式: - [ ] 内容 / 担当 / 期限 / 出所: journal/YYYY-MM-DD.md -->

- [ ] main と dev-log の push / ユーザー / — / 出所: journal/2026-09-26.md
- [ ] 新 CLAUDE.md の読み込みをリポジトリ層(`repos/` 配下相当)で実起動確認 / AI / — / 出所: journal/2026-09-26.md

## 次の一手

- E 群(過剰指示・儀式の削減)の論点をユーザーに提示して方針を決める。完了条件: synthesis.md の E 各項目に採否が付き、
  採用分が実装・Codex 承認・コミットされていること

## 最終更新

- 日付: 2026-09-26
- 更新者: Claude Code(template-cc)
