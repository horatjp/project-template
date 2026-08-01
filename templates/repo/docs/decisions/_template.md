---
type: decision
title: <決定の一言>
description: <一行要約。ファイルを開かずに関連判断できる粒度で>
status: stable          # draft(承認待ち) | stable(現行) | deprecated(無効)
superseded_by:          # deprecated のとき必須。置き換えた決定記録のファイル名
stale_after:            # 任意(YYYY-MM-DD)。時限性のある決定のみ。過ぎたら要再検証
tags: []
generated:
  by: agent:<tool-name>@<role>  # 例: agent:claude-code@coder。人間が書いたら human:<id>
  at: YYYY-MM-DD
verified: []            # 空=未検証。書式: [{by: agent:<tool>@reviewer | human:<id>, at: YYYY-MM-DD}]
                        # 実際にレビューを実施した主体のみ記入。同じ tool-name は role・
                        # セッションが違っても本人(自己検証=不可)。本文変更時は既存要素を削除
---

# <決定の一言>

<!--
ファイル名: YYYY-MM-DD-topic.md
frontmatter は OKF(Open Knowledge Format)互換の方言(actor 表記と日付を簡略化)。運用ルール:
- 決定記録(技術決定の場合、いわゆるADR)は「なぜこう作られたか」の記録。
  AIはこれを知らないと理由ごと壊す。「何を決めたか」より「なぜそう決めたか」を丁寧に
- 重要な決定はまず `status: draft` で起こし、ユーザーの承認を得て `stable` にする
- 「採用しない」と決めたことも1件の決定記録として書く(例:「GraphQL は採用しない」。
  status は stable)。やらない理由も立派な「なぜ」
- 調査に基づく決定は、根拠になった docs/knowledge/ のファイルと相互にリンクする
- 既存の決定の編集は、開始前にユーザーへ「更新か上書きか」を確認する:
  - 誤字・てにをは・補足説明(決定は不変)→ **上書き**(そのまま編集)
  - 技術スタック・設計・インフラ・データモデルの変更、status の変更 → **更新**
    (新しい決定記録を起こし、旧を `status: deprecated` + `superseded_by` に)
-->

## 背景

(この決定が必要になった経緯・制約)

## 決定と理由

(何を選び、なぜか)

## 検討した代替案

(採用しなかった案と理由。自明なら省略可)

## 影響範囲

(この決定が影響するコンポーネント・ドキュメント。なければ「なし」)

## 再検討の条件

(どうなったらこの決定を見直すか。日付で切れるものは frontmatter の stale_after にも書く)
