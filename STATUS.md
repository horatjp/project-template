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
  - E 群(過剰指示・儀式の削減): E1〜E5 完了・Codex 承認・コミット済み(main)
  - F 群(不足の追加): F1・F4・F6 完了・Codex 承認・コミット済み(main)。F3 は見送り、F2・F5 は実案件で必要になったら
- 2026-10-09 multi-agent モジュールを削除(main 34cd66d・b9e263e)。完了
- 2026-10-30 契約による設計・副作用の分離をリポジトリ層の規範に追加(main 0f515ef)。Fable・Astra の全体レビューで妥当と確認し、
  合意12件を修正(main 8a3cfa4・75b4960、Fable 再確認 P1=0 P2=0)。完了

## 宿題(open)

<!-- 形式: - [ ] 内容 / 担当 / 期限 / 出所: journal/YYYY-MM-DD.md -->

- [ ] ~/projects/okayu など他プロジェクトの templates/ 複製の multi-agent 整理 / ユーザー / 期限なし / 出所: journal/2026-10-09.md
- [ ] dotfiles 側 CLAUDE.md の multi-agent 言及の修正 / ユーザー / 期限なし / 出所: journal/2026-10-09.md
- [ ] R3-01: PATH 上の grep に実行権限が無いと check-credentials.sh が exit 0 で通る(P3。事前プローブ1行+selftest1件で直る)/ AI / 期限なし / 出所: journal/2026-10-30.md


## 次の一手

- 次の実案件でテンプレートを展開し、見直し後のルールで回して詰まりを dev-log に記録する

## 最終更新

- 日付: 2026-10-30
- 更新者: Claude Code
