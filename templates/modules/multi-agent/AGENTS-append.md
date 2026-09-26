# AGENTS.md 追記モジュール — マルチエージェント並列運用

<!--
導入方法: 下の「## 並列運用(マルチエージェント)」以下を丸ごと、リポジトリの
AGENTS.md 末尾に追記する(このコメントと最上部の見出しは写さない)。
全CLIに確実に読ませるため、別ファイル参照ではなく AGENTS.md への追記を推奨。
追記後の AGENTS.md は150行以下に収める(現行テンプレートで約150行 — 上限に近いので、追記するなら同量を削る)。「100行以下」の原則に
対し、モジュール導入時のみ上限を150行とする(AGENTS.md 保守節に同じ例外を明記済み)。
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

- **change は承認の単位、Issue は実行の単位。** スペック必須の変更は `changes/<name>/` で
  承認を得てから、tasks の項目ごとに Issue を切る(Issue 本文の「対応スペック」欄で
  `changes/<name>/tasks.md` の項番を参照。スペック不要な変更はその理由を書く)。
  実行状態の正典は Issue。tasks のチェックは scribe が Issue の完了を見て反映する。
  親 change の完了・archive は、全 Issue のマージ後に統合検証と共有文書の更新が済んでから
- 1 実装タスク = 1 GitHub Issue = 1 git worktree = 1 ブランチ = 1 PR
- 担当範囲は Issue 本文にパスの glob で明記し、範囲外のファイルは変更しない
- 依存は Issue 本文に `Depends on: #12, #13` の形式で明記する
  (`scripts/check-blocked.sh` が自動パースする。フォーマット厳守)
- ラベル: `blocked`(依存待ち)→ `todo`(着手可)→ `in-progress`(claim 済み)。進捗ラベルは常に1つ(spawn が付け替え。着手済みの依存が再オープンされたら blocked + needs-human で人間が継続/破棄を判断)。
  `needs-human` は進捗ラベルと直交する**停止フラグ**: 付いている間は spawn を拒否し、
  依存の同期(check-blocked)も cleanup も触らない(CLOSED でも消さない)。
  解除は人間が判断を Issue コメントに記録してラベルを外し、`scripts/check-blocked.sh` を
  1回実行して停止中の依存変化を同期する
- **close の意味は「対応PRが main にマージされた」に固定する。** 手動 close はしない。
  PR 本文に `Closes #N` を書き、マージによる自動 close に任せる
  (統合タスクが依存コード未収載の main から分岐する事故を防ぐため)

### 並列実行

- 着手は `scripts/spawn-worktree.sh <issue番号>` で worktree を分離してから。
  スクリプトが `in-progress` ラベル+assign で Issue を claim する。claim 済みの Issue には着手しない
- 統合(fan-in)タスクは、依存 Issue が全て close されるまで着手しない
  (`scripts/check-blocked.sh` が自動でラベルを解除する)
- 中断・再開は同じ Issue で `spawn-worktree.sh` を再実行(再 claim して既存 worktree を案内)。claim 後の
  失敗で `in-progress` だけ残ったら、表示される回収コマンドで担当を解放する(自動では戻さない)
- worktree にはワークスペース共有スキルの symlink(`.gitignore` 済み)が引き継がれない。
  必要なら `<workspace>/.agents/skills/<name>/SKILL.md` を直接読ませる
- **記録の分担(本節の適用中は「記録」節の共有文書更新を次のとおり委譲する)**:
  builder が書くのは担当 glob 内のコード、Issue コメント・PR 本文(現在地・次の一手・検証結果・
  ブロッカー・記録すべき判断。実行状態の正典として「ファイルのみ」原則の例外)、
  `docs/learnings/YYYY-MM-DD-<slug>.md`(1エントリ1ファイル。ゲートは learnings.md 冒頭。
  `docs/learnings.md` への直接追記は conflict するので不可)。`docs/STATUS.md`・生きた文書・
  decisions・knowledge・tasks の完了報告は scribe/統合担当が Issue と PR を読んで更新し、
  その完了を change 完了の条件にする。スコープ変更の停止と再承認は委譲しない

### エスカレーション(`needs-human` を付けて人間の判断を待つ)

- 同じ原因の失敗への修正を繰り返しても進まない(目安3回。別々の原因を順に解消している間は該当しない)
- Issue・change で承認された範囲を超えて、公開API・DBスキーマ・依存パッケージ・セキュリティ/認証/支払いの
  コード・`.env`・Secrets に触れる必要が出た(承認範囲内の実装なら該当しない)
- force-push・ブランチ/タグの削除・履歴の書き換え、データ削除を伴うマイグレーション
- 継続的な課金・コストが発生する操作
- 依存 Issue が再オープンされたが、自分のタスクは着手済み(継続/破棄は人間が決める)
