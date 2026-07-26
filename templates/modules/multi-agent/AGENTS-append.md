# AGENTS.md 追記モジュール — マルチエージェント並列運用

<!--
導入方法: 下の「## 並列運用(マルチエージェント)」以下を丸ごと、リポジトリの
AGENTS.md 末尾に追記する(このコメントと最上部の見出しは写さない)。
全CLIに確実に読ませるため、別ファイル参照ではなく AGENTS.md への追記を推奨。
追記後の AGENTS.md は約120行になる。「100行以下」の原則に対し、モジュール導入時のみ
上限を150行とする(AGENTS.md 保守節に同じ例外を明記済み)。
-->

## 並列運用(マルチエージェント)

### 役割

- **planner**: Issue を分解し、依存関係を設計する。実装はしない
- **builder**: 割り当てられた Issue(worktree)の実装のみを行う
- **verifier**: builder の実装をレビューする(観点は lens-review スキル)。実装はせず指摘と承認/却下のみ
- **scribe**: 決定・学びを `docs/` に記録し、learnings 統合PRのレビュアーを務める

兼任してよいが、**verifier は必ず別コンテキスト(別セッション・可能なら別ベンダーのAI)で行う**。
自分が書いたコードを自分でレビューしない。main のブランチ保護(PR必須+approve必須)で
機械的にも強制する(verifier を別 GitHub アカウントにすると自己承認不可の制約がそのまま効く)。

### タスクの単位と Issue ライフサイクル

- 1 実装タスク = 1 GitHub Issue = 1 git worktree = 1 ブランチ = 1 PR
- 担当範囲は Issue 本文にパスの glob で明記し、範囲外のファイルは変更しない
- 依存は Issue 本文に `Depends on: #12, #13` の形式で明記する
  (`scripts/check-blocked.sh` が自動パースする。フォーマット厳守)
- ラベル: `blocked`(依存待ち)→ `todo`(着手可)→ `in-progress`(claim 済み)。
  `needs-human` はエスカレーション中(人間の判断が出るまで自動処理を止める)
- **close の意味は「対応PRが main にマージされた」に固定する。** 手動 close はしない。
  PR 本文に `Closes #N` を書き、マージによる自動 close に任せる
  (統合タスクが依存コード未収載の main から分岐する事故を防ぐため)

### 並列実行

- 着手は `scripts/spawn-worktree.sh <issue番号>` で worktree を分離してから。
  スクリプトが `in-progress` ラベル+assign で Issue を claim する。claim 済みの Issue には着手しない
- 統合(fan-in)タスクは、依存 Issue が全て close されるまで着手しない
  (`scripts/check-blocked.sh` が自動でラベルを解除する)
- 並列運用中は `docs/learnings.md` に直接追記しない(worktree 間で conflict するため)。
  `docs/learnings/YYYY-MM-DD-<slug>.md` に1エントリ1ファイルで書き(ゲートは learnings.md 冒頭)、
  scribe が PR 経由で learnings.md へ統合する。統合時は重複をまとめ、迷ったら削除せず残す

### エスカレーション(`needs-human` を付けて人間の判断を待つ)

- 同一 Issue への自動修正の試行(テスト・ビルド・lint の失敗対応を合算)が5回を超えた
- 公開API・DBスキーマの変更、依存パッケージの追加・更新が必要になった
- セキュリティ・認証・支払いに関わるコード、`.env`・Secrets に触れる必要が出た
- force-push・ブランチ/タグの削除・履歴の書き換え、データ削除を伴うマイグレーション
- 継続的な課金・コストが発生する操作
- 依存 Issue が再オープンされたが、自分のタスクは着手済み(継続/破棄は人間が決める)
