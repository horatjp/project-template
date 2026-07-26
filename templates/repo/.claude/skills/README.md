# リポジトリ固有スキル

繰り返し使う多段階の手順(デプロイ手順・レビュー観点・リリースチェック等)をここに置く。
AGENTS.md を太らせないための逃がし先のひとつ(learnings からの昇格先でもある)。

- 形式: `<skill-name>/SKILL.md`。frontmatter に name / description を書く
  (AIは description を見て自動ロードするため、「いつ使うスキルか」を具体的に書く)
- Claude Code の機構。他のCLIで同じ手順を使わせたい場合は、AGENTS.md から
  該当 SKILL.md のパスを参照させる
