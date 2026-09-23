---
name: setup-repo
description: >
  repos/ 配下に新しいコードリポジトリを作るときに使用。「repos に <name> を追加して」
  「新しいリポジトリを作って」「リポジトリ層テンプレートを展開して」などの依頼で使う。
  テンプレート展開 → git init → 初期コミット → 共有スキルの取り込みまでを決定的に実行する。
  既存の AGENTS.md / CLAUDE.md を持つリポジトリへの導入には使わない(README の統合手順に従う)。
---

# setup-repo — リポジトリ層テンプレートの展開

README の手動手順を決定的に実行する。省略・順序変更をしない。

## 手順

1. **リポジトリ名を確定する。** 指示に無ければ聞く。`^[a-z0-9]+(-[a-z0-9]+)*$`
   (kebab-case)に一致しない名前、または `repos/<name>` が既に存在する場合は
   中断してユーザーに報告する(勝手に直したり上書きしたりしない)
2. **展開する。** `<dir>/.` 形式でコピーする(コピー先が既に存在すると
   `cp -R <dir>` は二重ネストするため):
   ```bash
   mkdir -p repos/<name> && cp -R templates/repo/. repos/<name>/ && find repos/<name> -name .DS_Store -delete
   ```
3. **git 初期化と初期コミット。** ロールバック地点を最初に作る(スキップしない)。
   `cd` は使わない — 作業ディレクトリが次のコマンドへ持ち越され、手順 4 の相対パスが壊れる:
   ```bash
   git -C repos/<name> init -b main && git -C repos/<name> add -A \
     && git -C repos/<name> commit -m "🎉 init: リポジトリ層テンプレートを展開"
   ```
   `user.name` / `user.email` 未設定で commit が失敗したら、勝手に設定せずユーザーに
   設定を依頼して再実行する
4. **共有スキルの取り込み。** ワークスペースの `.claude/skills/` を一覧し、どれを
   取り込むかユーザーに確認する(既定の提案: hearing・git-commit・codex・grill-me —
   README「運用の要点」が前提にする4つ)。取り込む場合(ワークスペース直下で実行):
   ```bash
   ln -s ../../../../.claude/skills/<skill> repos/<name>/.claude/skills/<skill>
   ```
   symlink はワークスペース内でのみ解決され、単体 clone や `git worktree` の作業先には無いため、
   リポジトリの `.gitignore` に `.claude/skills/<skill>` を追記してコミットする
   (単体配布するときはコピーに置き換える)
5. **検証と報告。** `repos/<name>/AGENTS.md` の存在と `git -C repos/<name> log --oneline`
   (初期コミットがあること。共有スキルを取り込んだ場合は `.gitignore` のコミットも)を
   確認して報告し、次の一手を案内する:
   - hearing の方法論で `docs/requirements.md` を記入し、`docs/PROJECT.md`・
     `docs/STATUS.md` を初期化する
   - スタックが決まったら `.gitignore` に依存・生成物・キャッシュ等を追記する
