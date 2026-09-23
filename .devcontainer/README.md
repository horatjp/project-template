# 汎用開発コンテナ

ワークスペース直下で使う devcontainer。ワークスペース層はスタック非依存なので、
Claude Code + Codex CLI が使える最小構成を恒久の既定とする。ここでコンテナを開けば
`repos/` 配下のリポジトリも同じコンテナ内で作業できる。

VS Code で「Reopen in Container」(または `devcontainer up`)で起動する。
コンテナを使わない運用なら、このディレクトリは無視してよい(害はない)。

## 初回セットアップ

- コンテナ内で `claude` / `codex` を起動してログインする。コンテナ内の `~/.claude`・
  `~/.codex` はホストとは別物なので、ホスト側のローカル環境には影響しない
- 既定では **rebuild するとログイン・設定は消える**(再ログインすればよい)。
  残したい場合は `devcontainer.json` に named volume を追記する:

  ```jsonc
  "mounts": [
    "source=claude-config-${devcontainerId},target=/home/vscode/.claude,type=volume",
    "source=codex-config-${devcontainerId},target=/home/vscode/.codex,type=volume"
  ],
  // volume は初回 root 所有で作られるため postCreateCommand の先頭に chown を足す:
  // sudo chown -R vscode:vscode /home/vscode/.claude /home/vscode/.codex && ...
  ```

- **ユーザースキルの復元**: コンテナ内の `~/.claude/skills` はまっさらになる。
  dotfiles でスキルを管理している場合、VS Code の設定
  `"dotfiles.repository": "<user>/dotfiles"` を入れておくと全コンテナに自動適用される
- **Codex のサンドボックス**: コンテナ内では bubblewrap が user namespace を作れず
  起動しないことがある(ドライランで確認)。コンテナ自体が隔離境界なので、その場合は
  サンドボックス無しで実行する(`codex --sandbox danger-full-access`、または
  `~/.codex/config.toml` で設定)

## スタックが決まったら

`devcontainer.json` の features に追記する(1行ずつ):

- Python: `"ghcr.io/devcontainers/features/python:1": {}`
- Docker(テスト用DB等をコンテナ内から起動): `"ghcr.io/devcontainers/features/docker-in-docker:2": {}`
- DB 常駐が必要になったら `docker-compose.yml` 方式に移行する(devcontainer の
  `dockerComposeFile` 指定。Compose の構成はスタック決定後にリポジトリ側で決める)

特定リポジトリだけ重い環境が必要になったら、そのリポジトリ側に個別の
`.devcontainer/` を作って分離する(このファイルをコピーして育てればよい)。

## オプション: ファイアウォール(自律実行用)

権限確認をスキップした自律実行を安全にやりたい場合は、Anthropic 公式リファレンス実装の
アウトバウンド許可リスト式ファイアウォールを導入する:
https://code.claude.com/docs/ja/devcontainer
(許可リスト外への通信を遮断するので、使うAPIやレジストリをリストに足してから有効化する)
