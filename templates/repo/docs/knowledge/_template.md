---
type: research          # research(技術調査・バグ解決) | reference(一次資料・URL・外部仕様)
title: <一言>
description: <一行要約。ファイルを開かずに関連判断できる粒度で>
status: stable          # draft | stable | deprecated
superseded_by:          # deprecated のとき必須。置き換えたファイル名
stale_after:            # reference は特に推奨(外部情報は腐る)。YYYY-MM-DD
tags: []
generated:
  by: agent:<tool-name>@<role>  # 例: agent:claude-code@coder
  at: YYYY-MM-DD
verified: []            # 空=未検証。書式: [{by: agent:<tool>@reviewer | human:<id>, at: YYYY-MM-DD}]
                        # 実際にレビューを実施した主体のみ記入。同じ tool-name は role・
                        # セッションが違っても本人(自己検証=不可)。本文変更時は既存要素を削除
---

# <タイトル>

<!--
ファイル名: topic-subtopic.md(例: yfinance-rate-limit.md、auth-token-expiry-bug.md)
1件1ファイル。既存ファイルと主題が同じなら新規作成せず既存を更新する(編集前に本文を読む)。
本文の形は内容に合わせる(目安):
- 技術調査: 調査背景 / 比較・評価 / 結論(採用の決定はここではなく docs/decisions/ へ書き、
  両者を相互にリンクする)
- バグ解決: 症状 / 原因 / 修正 / 再発防止のシグナル
  (AIの振る舞いの教訓になったものは learnings.md にも。ゲートは learnings 冒頭)
- 実行可能な検証コード(SDK実挙動の確認・経路検証など)を残す場合は `spikes/<topic>/` に
  置き(目的・実行方法を添える。使い捨て前提・本番利用不可)、この knowledge からリンクする
- 参照資料: URL / なぜ保存したか / 要点の抜き書き
-->
