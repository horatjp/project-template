# dev-log — project-template 自身の運営記録

このブランチ(`dev-log`、main と履歴を共有しない orphan ブランチ)は、テンプレート
[project-template](https://github.com/horatjp/project-template) の保守作業そのものの記録を持つ。
main は配布用の雛形だけにし、テンプレートから作った新規プロジェクトに保守の経緯が混ざらないようにしている。

- `STATUS.md` — テンプレート保守の現在地
- `journal/` — 保守作業の時系列ログ
- `materials/` — レビュー往復の原文など

保守者は main のワークスペース直下に worktree として展開して使う(`_devlog/` は main 側で git 管理外):

```bash
git fetch origin dev-log
git worktree add _devlog dev-log
```

書式・運用はワークスペース層の `AGENTS.md` と各 `_template.md`(main 側)に従う。
設計判断の原本はローカルの `_archive/`(git 管理外)にある。
