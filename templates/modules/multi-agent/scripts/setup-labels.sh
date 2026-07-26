#!/bin/bash
# setup-labels.sh
#
# 目的: このテンプレートの運用に必要なラベルを一括作成する。
#       リポジトリ作成直後に1回実行する。既存ラベルはスキップされる(冪等)。
#
# 使い方:
#   ./scripts/setup-labels.sh

set -euo pipefail

create_label() {
  local name="$1" color="$2" desc="$3" out
  if out=$(gh label create "$name" --color "$color" --description "$desc" 2>&1); then
    echo "作成: $name"
  elif printf '%s' "$out" | grep -qi "already exists"; then
    echo "スキップ(既存): $name"
  else
    # 既存以外の失敗(未認証・権限不足・ネットワーク等)は黙殺せずエラーで止める
    echo "エラー: ラベル $name を作成できませんでした: $out" >&2
    exit 1
  fi
}

create_label "todo"        "0E8A16" "着手可能なタスク"
create_label "blocked"     "D93F0B" "依存Issueの完了待ち(check-blocked.shが自動でtodoに付け替える)"
create_label "in-progress" "FBCA04" "エージェントが着手中(spawn-worktree.shが自動で付与)"
create_label "needs-human" "B60205" "エスカレーション: 人間の判断が必要"

echo "done."
