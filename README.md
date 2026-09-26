# dev-log — project-template 自身の運営記録

このブランチ(`dev-log`、main と履歴を共有しない orphan ブランチ)は、テンプレート
[project-template](https://github.com/horatjp/project-template) の保守作業そのものの記録を持つ。
main は配布用の雛形だけにし、テンプレートから作った新規プロジェクトに保守の経緯が混ざらないようにしている。

- `STATUS.md` — テンプレート保守の現在地
- `journal/` — 保守作業の時系列ログ
- `materials/` — レビュー往復の原文など

保守者は main のワークスペース直下に worktree として展開して使う(`_devlog/` は main 側で git 管理外)。
AI セッションは main のワークスペース直下で起動し、ここは記録の置き場として使う(ここで起動すると
main 側の AGENTS.md・スキルが読まれない)。手順は main の README「テンプレートの保守」:

```bash
# ローカルに dev-log ブランチがある場合
git worktree add _devlog dev-log
# 無い場合(single-branch clone でも動く形)
git fetch origin refs/heads/dev-log:refs/remotes/origin/dev-log
git worktree add -b dev-log _devlog origin/dev-log
# push は明示する
git push origin dev-log
```

書式・運用はワークスペース層の `AGENTS.md` と各 `_template.md`(main 側)に従う。
設計判断の原本は main 側のローカル資料 `_archive/`(git 管理外)にある。
