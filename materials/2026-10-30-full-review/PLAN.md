# 修正の計画(2026-10-30。ユーザー承認: 12件すべて・J-03 は止める側に統一・Sol 実装 / Fable レビュー)

正: 同じフォルダの `joint.md`(J-01〜J-12 の場所・何が起きるか・直し方)。

## 担当

- 実装: impl-sol(Codex GPT-6.1 Sol medium)
- レビュー: review-fable(Claude Fable 5.1。作業した側と別系統)
- 監督・コミット: template-cc

## 順番(joint.md §6)

1. 文言: J-08 → J-09 → J-07 → J-01 → J-02 → J-05 → J-06 → J-12
2. 文書: J-10(materials/README.md)→ J-11(.devcontainer/README.md)
3. スクリプト: J-04 → J-03。selftest に回帰ケースを先に足して落ちることを確かめ、それから直す
   - J-03 はユーザー選択どおり「パーサ不在は両形式とも理由付き exit 2」。依存(jq または python3)を README と
     templates/repo/docs/PROJECT.md の開発環境節に明記
4. 仕上げ: 両層の `scripts/hooks-selftest.sh` が全 pass、両層 AGENTS.md が100行以下

## 守ること

- 両層で同一のファイル(scripts/・hooks 設定・共通文言)は両層を同じに直す(`cmp` で一致を確認)
- 範囲は joint.md の12件だけ。見送り6件(joint §4)と範囲外の改善はしない。気づいた点は impl.md に書いて止める
- commit・push・削除・ネットワーク取得・有料の実行はしない。_devlog/ は impl.md 以外触らない
- 終わったら `_devlog/materials/2026-10-30-full-review/impl.md` に各 J の変更箇所・selftest 結果を書き、最後の行を `実装完了` にする

## 完了条件(監督の門番)

- review-fable の集計が P1=0・P2=0
- 両層 selftest 全 pass(監督も自分で実行)
- 差分が12件の範囲内
- コミットは関心ごと(文書 / スクリプト+テスト)
