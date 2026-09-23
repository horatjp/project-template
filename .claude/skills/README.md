# .claude/skills/ — Claude Code 用の入口(symlink)

共有スキルの正典は `.agents/skills/`(Codex CLI も自動発見するベンダー中立の置き場)。
ここには各スキルへの symlink だけを置く。スキルの追加・編集は `.agents/skills/` で行い、
`ln -s ../../.agents/skills/<name> .claude/skills/<name>` で入口を足す。
(symlink 経由の発見は Claude Code の公式ドキュメントに明記が無いが、本ワークスペースで動作確認済み。
2026-09-23 時点。動かなくなったら実体を `.claude/skills/` に戻し `.agents/skills/` を symlink にする)
