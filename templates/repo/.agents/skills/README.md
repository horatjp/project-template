# リポジトリ固有スキル(正典)

繰り返し使う多段階の手順(デプロイ手順・レビュー観点・リリースチェック等)をここに置く。
AGENTS.md を太らせないための逃がし先のひとつ(learnings からの昇格先でもある)。

- 形式: `<skill-name>/SKILL.md`。frontmatter に name / description を書く
  (AIは description を見て自動ロードするため、「いつ使うスキルか」を具体的に書く)
- `.agents/skills/` は Codex CLI も自動発見する(Claude Code は `.claude/skills/<name>` の
  symlink 経由)。自動発見しない CLI には AGENTS.md から該当 SKILL.md のパスを参照させる
