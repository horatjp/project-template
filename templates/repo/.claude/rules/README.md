# .claude/rules/ — Claude Code 専用の補助

Claude Code は、frontmatter の `paths` にマッチするファイルを扱うときだけ、ここの規約を自動で読み込む。
Codex など他の CLI は読まないため、**守らせたい規約の置き場は `docs/rules/`**(どの CLI でも読める)。
ここは Claude Code だけに効けば十分な補助(Claude 固有の癖への対処など)に限って使う。

書き方は Claude Code のドキュメント(memory の path-specific rules)に従う。
