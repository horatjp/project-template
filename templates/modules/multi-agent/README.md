# multi-agent モジュール — Issue 駆動の並列実行

リポジトリ層(`templates/repo` を展開したリポジトリ)に**追加で**導入するモジュール。
複数のAIエージェント(Claude Code / Codex CLI 等)を GitHub Issues + git worktree で
並列協調させる。

**導入の目安**: 並列実行が実際に必要になってから入れる。1エージェントで回っている
リポジトリには入れない(Issue・ラベル運用のオーバーヘッドだけが残る)。

## 構成

```
multi-agent/
├── AGENTS-append.md        # AGENTS.md 末尾へ追記する運用ルール(役割・ライフサイクル・エスカレーション)
├── scripts/
│   ├── setup-labels.sh     # 運用に必要なラベルを一括作成(最初に1回)
│   ├── check-blocked.sh    # 依存Issueの完了チェック(cron/Actions 両対応・冪等)
│   ├── spawn-worktree.sh   # Issueをclaimしてworktreeとブランチを自動作成
│   └── cleanup-worktree.sh # closeされたIssueのworktree・ブランチを掃除
└── .github/
    ├── ISSUE_TEMPLATE/     # task.md(実装)/ integration.md(統合・fan-in)
    └── workflows/
        └── check-dependencies.yml  # Issueのclose/reopen時に依存を同期(イベント駆動)
```

## 導入手順

```bash
# 1. モジュールを対象リポジトリへコピー
#    (cp -R <dir> <repo>/ はコピー先に同名ディレクトリがあると二重ネストするため、
#     必ず mkdir -p + 「<dir>/.」の形式で中身をコピーする)
mkdir -p <repo>/scripts <repo>/.github
cp -R templates/modules/multi-agent/scripts/. <repo>/scripts/
cp -R templates/modules/multi-agent/.github/. <repo>/.github/

# 2. AGENTS-append.md の「## 並列運用」以下を <repo>/AGENTS.md の末尾に追記する
#    (追記後は約120行になる。導入時の上限は150行 — AGENTS.md 保守節の例外)

# 3. ラベルを作成(gh CLI 認証済みであること)
cd <repo> && ./scripts/setup-labels.sh
```

4. **ブランチ保護(強く推奨)**: main への直接 push を禁止し、PR + approve 必須にする。
   verifier を別の GitHub アカウント/トークンで動かすと「PR作成者は自己承認できない」
   という GitHub の制約が builder / verifier 分離の機械的な強制装置になる
5. **依存の自動解消**: `.github/workflows/check-dependencies.yml` はそのままイベント駆動で
   動く。cron 併用も可(`*/5 * * * * cd <repo> && ./scripts/check-blocked.sh`。冪等なので安全)

## 運用の流れ

```bash
gh issue create --title "認証API実装" --label "todo"
gh issue create --title "結合テスト" --label "blocked" --body "Depends on: #1"
./scripts/spawn-worktree.sh 1        # claim + worktree 作成 → builder が実装
# PR 作成(本文に Closes #1)→ verifier が lens-review 観点でレビュー → 人間がマージ
./scripts/cleanup-worktree.sh --force  # close 済み Issue の worktree を掃除
```

## 補足

- **Claude Code のネイティブ worktree / agent team 機能との関係**: Claude Code 単体の
  並列ならネイティブ機能で足りる場面が増えている。本モジュールのスクリプトを使う価値は
  (1) ベンダー横断(Codex 等との混成チーム)の調整、(2) claim 状態が GitHub に永続化され
  セッションを跨いで残ること、の2点にある
- **エージェント間メッセージングツール(任意)との役割分担**: メッセージング機構を併用する
  場合も、状態の正は常に GitHub Issues(claim・依存・完了・needs-human)。メッセージングは
  「受信箱を確認して」「レビュー依頼」等の**即時の呼びかけ専用**の呼び鈴として使う —
  turn モードのエージェント(Codex 等)は新着に自動で気づかないため、leader が起こす。
  決定・報告など残す価値のある内容はメッセージングに書かず Issue コメント / docs へ
  (セッション間の伝達はファイルのみ、の原則)。Claude 同士だけのチームなら
  ネイティブ agent team のメッセージングで足りる
- learnings の月次棚卸しは本体 README「運用の要点」の月1棚卸しに含める(並列中の
  1エントリ1ファイル運用と scribe による統合は AGENTS-append.md 参照)
- スクリプトは macOS(BSD)/ Linux(GNU)両対応
