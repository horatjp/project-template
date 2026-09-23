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
├── tests/
│   └── synthetic.sh        # スクリプト3本の合成テスト(gh スタブ + 一時 bare リポジトリ。実 GitHub に触れない)
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
mkdir -p <repo>/scripts <repo>/.github <repo>/tests
cp -R templates/modules/multi-agent/scripts/. <repo>/scripts/
cp -R templates/modules/multi-agent/.github/. <repo>/.github/
cp -R templates/modules/multi-agent/tests/. <repo>/tests/     # 任意。自環境でスクリプトを検証したいとき
#    展開後に <repo>/tests/synthetic.sh を1回実行し、全ケース pass を確認する(gh・実リポジトリ不要)

# 2. AGENTS-append.md の「## 並列運用」以下を <repo>/AGENTS.md の末尾に追記する
#    (追記後は150行以下に収める — 導入時の上限。現行で約150行なので wc -l で確認する)

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
./scripts/cleanup-worktree.sh          # 削除候補の一覧(作業ツリー・Git 参照・GitHub 状態を変えない)
./scripts/cleanup-worktree.sh --force  # close 済み Issue の worktree を掃除(prune・fetch はこのときだけ)
```

### 中断・再開・失敗からの回収

- **再開**: 同じ Issue 番号で `spawn-worktree.sh` を再実行すると、再 claim(todo→in-progress)して
  既存 worktree のパスを案内する(差し戻しで in-progress が外れていても claim が戻る)。`cd` して続ける
- **着手済みの依存が再オープンされた**: check-blocked が `blocked` + `needs-human` にする(担当と
  worktree は残る)。人間が継続/破棄を判断してコメントに記録し `needs-human` を外す。依存の完了後に
  `todo` へ戻るので、継続なら `spawn-worktree.sh` を再実行して再開する
- **claim だけ残った**(worktree 作成前に失敗した等): スクリプトが表示する回収コマンド
  `gh issue edit <番号> --remove-label in-progress --add-label todo --remove-assignee @me` で担当を解放して
  着手可に戻す(厳密な元状態への復元ではない。blocked / needs-human / 担当が変わっていたら当てずに再確認)。
  自動では戻さない — 同じ GitHub アカウントを複数AIが使うと、自分の claim か検証できないため
- **`needs-human` の解除**: 人間が判断を Issue コメントに記録 → ラベルを外す →
  `./scripts/check-blocked.sh` を1回実行(停止中に変化した依存を同期する)
- **worktree に共有スキルが無い**: ワークスペース共有スキルの symlink は `.gitignore` 済みなので
  `git worktree add` で作った作業先には無い。必要なら
  `<workspace>/.agents/skills/<name>/SKILL.md` を直接読ませる(単体 clone と同じ扱い)

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
