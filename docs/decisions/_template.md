---
type: decision
title: <決定の一言>
description: <一行要約。ファイルを開かずに関連判断できる粒度で>
status: draft           # draft(承認待ち) | stable(現行) | deprecated(無効)。承認で stable に(同一ファイル内で書き換える)
superseded_by:          # deprecated のとき必須。置き換えた決定記録のファイル名
stale_after:            # 任意(YYYY-MM-DD)。時限性のある決定のみ。過ぎたら要再検証
tags: []
generated:
  by: agent:<tool-name>@<role>  # 例: agent:claude-code@coder。人間が書いたら human:<id>
  at: YYYY-MM-DD
verified: []            # 空=未検証。書式: [{by: agent:<tool>@reviewer | human:<id>, at: YYYY-MM-DD}]
                        # 実際に中身を検証した主体のみ記入。書いた文脈そのものは不可(自己検証)。
                        # 別セッション・別の AI・人間なら可(別ベンダー推奨)。本文変更時は既存要素を削除
                        # 決定の信頼の根拠は status(stable=ユーザー承認済み)。verified は任意の追加検証
---

# <決定の一言>

<!--
ファイル名: YYYY-MM-DD-topic.md
ワークスペース層の決定記録 = 事業・運営上の決定(料金・スコープ・体制・取引条件など)。
技術的な決定は各リポジトリの docs/decisions/ へ。書式は両層で共通(OKF互換の方言)。
- 決定はまず `status: draft` で起こし、ユーザーの承認が確認できたら `stable` にする(重要度によらない。
  会話や承認済み proposal で承認済みなら、その出所を本文に1行書けばよい。AI の判断だけでは stable にしない)
- 「やらない」と決めたことも1件の決定記録として書く(例:「○○プランは提供しない」)
- 既存の決定の編集は、開始前にユーザーへ「更新か上書きか」を確認する:
  誤字・補足(決定は不変)→ 上書き / 決定内容そのものの変更 → 更新
  (新しい決定記録を起こし、それが承認され適用が始まった時点で旧を `status: deprecated` +
  `superseded_by` に。それまでは旧記録が現行。将来から適用するなら適用条件・日付を後継の本文に書く)。
  draft → stable の承認と、旧記録への deprecated / superseded_by の記入は同一ファイル内で上書き
- 出所の打ち合わせがあれば journal へリンクする
-->

## 背景

(この決定が必要になった経緯・制約。出所: [journal/YYYY-MM-DD.md](../../journal/YYYY-MM-DD.md))

## 決定と理由

(何を選び、なぜか)

## 検討した代替案

(採用しなかった案と理由。自明なら省略可)

## 影響範囲

(この決定が影響する案件・リポジトリ・関係者。なければ「なし」)

## 再検討の条件

(どうなったらこの決定を見直すか)
