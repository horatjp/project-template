# ワークスペース共有スキル

ここに置いたスキルは、ワークスペース直下でセッションを開いたとき有効になる。
プロジェクト固有の手順・規約をスキル化して、配下の全リポジトリで共有する。

- 形式: `<skill-name>/SKILL.md`(frontmatter に name / description)
- `repos/` 配下のリポジトリ直下でセッションを開く場合は symlink で取り込む:

```bash
ln -s ../../../../.claude/skills/<skill-name> repos/<repo>/.claude/skills/<skill-name>
```

- この symlink はワークスペース内でのみ解決される。リポジトリを単体で clone・配布すると
  dangling になるため、リポジトリ側 `.gitignore` で除外するか、単体配布時はコピーにする
- 汎用スキル(プロジェクトを問わず使うもの)はここに置かず、各自のユーザーグローバル領域
  (`~/.claude/skills/`)で管理する。例外として、テンプレートが推奨する運用の手順を
  実装する同梱スキル — git-commit(関心単位のコミット)・codex(別ベンダーレビュー)・
  grill-me(承認前の計画精査)— はここに置く
