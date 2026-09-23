# .claude/skills/ — Claude Code 用の入口(symlink)

リポジトリ固有スキルの正典は `.agents/skills/`(Codex CLI も自動発見する)。
ここには各スキルへの symlink だけを置く(`ln -s ../../.agents/skills/<name> .claude/skills/<name>`)。
