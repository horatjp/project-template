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
  合意12件と追加指摘を修正(main 8a3cfa4・75b4960・7a4b877、Fable / Astra 再確認 P1=0 P2=0)。完了・push 済み
- 2026-11-03 ADR 執筆ガイドライン記事の取り込み: Fable・Astra 合意5件を両層 decisions/_template.md に反映(main 0aff97a)。
  完了・push 済み。出所: journal/2026-11-03.md
- 2026-11-03 henteko「コードレビューをなくして見えたもの」から、proposal に「ユーザーの判断」節(原文記録)と承認発言の原文化を検討。
  Fable・Astra は条件付き賛成(materials/2026-11-03-human-decisions/joint.md)。ユーザー承認で実装(main 0f42f7e)、
  Astra レビュー P2=2 P3=1 → 修正後 0。完了・push 済み
- 2026-11-03 architecture.md から PROJECT.md の構成欄にデータの流れ・境界を促す1文(main 52458ce)。完了・push 済み
- 2026-11-06 freee の Lean 記事から、AI の自主性に頼る規則を棚卸しし、決定論の hook(`ask`)で強制する提案を作成
  (materials/2026-11-06-deterministic-guardrails/proposal.md)。**ユーザー判断待ち**(昇格の時期・採る範囲・シェル経路・別AIレビューの有無)

## 宿題(open)

<!-- 形式: - [ ] 内容 / 担当 / 期限 / 出所: journal/YYYY-MM-DD.md -->

- [ ] ~/projects/okayu など他プロジェクトの templates/ 複製の multi-agent 整理 / ユーザー / 期限なし / 出所: journal/2026-10-09.md
- [ ] dotfiles 側 CLAUDE.md の multi-agent 言及の修正 / ユーザー / 期限なし / 出所: journal/2026-10-09.md


## 次の一手

- 次の実案件でテンプレートを展開し、見直し後のルールで回して詰まりを dev-log に記録する
  - その際、hooks の実 CLI での挙動(exit 2 以外の終了値の扱い・パーサ不在時のブロック)を確かめる
    (2026-10-30 の修正は合成入力の selftest でのみ検証。出所: materials/2026-10-30-full-review/joint.md §5)
  - 2026-11-03 の追加(decisions の書かないもの・決めないこと、proposal の「ユーザーの判断」節と承認原文)が実執筆で守られるか、
    既存回答の聞き直し・AI の勝手な補完が減るかを見る(いずれも予防的追加で未観測。出所: journal/2026-11-03.md)

## 最終更新

- 日付: 2026-11-06
- 更新者: Claude Code
