# project-template

プロジェクト運営(議事録・資料)とコード開発(AI協働)を1つのワークスペースで扱うテンプレート。
2026年時点のAIエージェント開発のベストプラクティス調査に基づいて設計し、
模擬プロジェクトのドライランで検証している。

Claude Code / Codex CLI など、AGENTS.md 系の指示ファイルを読む
CLIコーディングAI全般に対応する。

## 設計思想

### 1. AGENTS.md は100行以下 — 書いた量とAIが守る量は比例しない

指示ファイルは長くなるほど各セクションが無視される。恒常層は薄く保ち、
「この行を消したらAIがミスするか?」で全行を検証する。知識は性質ごとに3つの置き場に振り分ける:

| 知識の性質 | 置き場 |
|---|---|
| 常時必要な事実・規範 | `AGENTS.md`(100行以下を維持) |
| 手順(必要な時だけ読む) | `.claude/skills/`(オンデマンドでロード) |
| 例外なく強制するルール | hooks(決定的に実行される唯一の手段) |

リポジトリ層の `docs/learnings.md`(失敗と学び)が育ったら、hooks / `.claude/rules/` /
skills / AGENTS.md へ昇格させる。「学び → 恒常化」の一方通行で、恒常層の肥大化を防ぐ。

### 2. 運営とコードを同じメンタルモデルで扱う

ワークスペースは2層構成。どちらの層も
「**STATUS.md を読めば現在地、docs/decisions/ を読めば経緯、時系列は journal / git log**」
という同じモデルで動く。

- **ワークスペース層**(直下): 現在地(`STATUS.md`)、時系列ログ(`journal/`)、
  事業判断・生きた文書(`docs/`)、ファイル原本(`materials/`)
- **リポジトリ層**(`templates/repo/` → `repos/` 配下へ展開): 薄い `AGENTS.md` +
  変更スペック(`changes/`)+ 決定・学びの記録(`docs/`)

変更管理は「変更を一級市民にする」方針で、スペック必須の変更(新機能 / 公開インターフェース
の変更 / 既存の決定を覆す変更)だけ `changes/` でスペック駆動にする
(proposal → 承認 → design → tasks → 実装)。バグ修正・微修正には強制しない。
承認ゲートは指示ではなく hooks で機械的に強制する(後述)。

### 3. ナレッジに信頼度を持たせる — AIは古い・未検証の文書にも自信満々に従う

`docs/decisions/`・`docs/knowledge/` の frontmatter は OKF(Open Knowledge Format、
Google Cloud 発のオープン仕様)を部分採用した方言で、信頼シグナルを機械可読にする:

- `generated`(誰がいつ書いたか)と `verified`(誰が検証したか)を分離する
- **自己検証は禁止**。信頼度は3段階 — 未検証 → machine-confirmed(書いた本人以外のAIが
  レビュー)→ human-reviewed(人間がレビュー)
- 本文を変更したら既存の `verified` は削除する(検証は失効する)
- `stale_after`(鮮度期限)を超えた記録と `deprecated` は判断根拠にしない

actor 表記(`agent:<tool>@<role>` / `human:<id>`)と日付(YYYY-MM-DD)は OKF を簡略化した
方言で、厳密準拠が必要になれば機械変換できる粒度を保っている。

仕様: https://github.com/GoogleCloudPlatform/knowledge-catalog

## 構成

```
project-workspace/
├── AGENTS.md              # ワークスペース層の運用ルール(まず読む)
├── CLAUDE.md              # → AGENTS.md への symlink(Claude Code 用)
├── STATUS.md              # 現在地(進行中・open な宿題・次の一手)
├── journal/               # 時系列ログ: 日誌・議事録(YYYY-MM-DD.md、追記専用。ため方は同README)
├── docs/                  # 主題別の生きた文書(要件・関係者情報など)
│   └── decisions/         #   事業・運営判断の決定記録(リポジトリ層と同じOKF互換書式)
├── materials/             # ファイル原本+AI可読の変換版(方法は同README)
├── .claude/skills/        # ワークスペース共有スキル(README 参照)
├── .devcontainer/         # 汎用開発コンテナ(コンテナ運用しない場合は無視してよい。同README参照)
├── repos/                 # コードリポジトリ置き場(git 管理外。各リポジトリが独立した git)
└── templates/
    ├── modules/
    │   └── multi-agent/   # 追加モジュール: Issue駆動の並列実行(必要になったら導入。同README参照)
    └── repo/              # リポジトリ層テンプレート(repos/ に新規リポジトリを作るときコピー)
        ├── AGENTS.md      # 正典。100行以下を維持(+ CLAUDE.md symlink)
        ├── changes/       # 変更スペック(大きい変更のみ proposal → design → tasks)
        ├── scripts/       # hooks 用スクリプト(承認ゲートの参照実装)
        ├── docs/
        │   ├── STATUS.md      # 現在地(毎セッション必読)
        │   ├── learnings.md   # 失敗と学び(毎セッション必読・100行上限)
        │   ├── PROJECT.md     # 安定した背景情報(オンデマンド)
        │   ├── decisions/     # 決定記録=「なぜ」の記録
        │   └── knowledge/     # 技術調査・バグ解決・一次資料
        └── .claude/
            ├── rules/     # パス限定の規約(該当ファイルを触る時のみロード)
            └── skills/    # リポジトリ固有の手順スキル
```

## 導入手順

```bash
# 1. テンプレートから新規ワークスペースを作成
gh repo create my-project --template horatjp/project-template --private --clone
cd my-project

# 2. AIセッションを開き、初期化を指示する
#    > AGENTS.md を読んで、このプロジェクトの概要を私に質問しながら
#    > journal の初回エントリと STATUS.md を初期化して。
#    > この README はテンプレートの説明書なので、プロジェクト用の内容に書き換えて
```

### repos/ にコードリポジトリを追加する

AIセッションで「repos/ に my-app を作って」と指示する — `setup-repo` スキル
(ワークスペース同梱)が、テンプレート展開 → git init → 初期コミット →
共有スキルの取り込みまでを決定的に実行する。手動で行う場合:

```bash
# cp -R <dir> <target> はコピー先が既に存在すると二重ネストするため「<dir>/.」形式でコピーする
mkdir -p repos/my-app && cp -R templates/repo/. repos/my-app/
cd repos/my-app
git init
git add -A && git commit -m "init: リポジトリ層テンプレートを展開"  # ロールバック地点を最初に作る
# スタックが決まったら .gitignore に依存・生成物・キャッシュ等を追記する
```

作成後、AIセッションで「hearing スキルの方法論で docs/requirements.md を記入し、
そこから docs/PROJECT.md と docs/STATUS.md を初期化して」と指示する。
`docs/`・`changes/` 配下は原則AIが書き、人間はレビューと承認を行う。

既存の `AGENTS.md` / `CLAUDE.md` があるリポジトリへ導入する場合は上書きせず、
AIに両方を読ませて統合案を出させ、承認してから統合する。

ワークスペース共有スキル(hearing 等)を `repos/` 配下で開くセッションでも使う場合は、
リポジトリ側へ symlink して取り込む:

```bash
ln -s ../../../../.claude/skills/<skill-name> repos/<repo>/.claude/skills/<skill-name>
```

この symlink はワークスペース内でのみ解決される。リポジトリを単体で clone・配布すると
dangling になるため、リポジトリ側 `.gitignore` で除外するか、単体配布時はコピーに置き換える。

## hooks — 承認ゲート(同梱済み・既定で有効)

機械的に強制したいルールは AGENTS.md に書かず hooks にする(AGENTS.md の指示は
アドバイザリだが、hooks は確実に実行される)。最初の例が**承認ゲート** —
proposal の承認チェックが未記入のまま design.md / tasks.md を書こうとしたらブロックする
PreToolUse フック(ドライランで、指示だけではこのゲートが素通りできることを確認済み)。

`templates/repo/.claude/settings.json` に設定済みで、`scripts/check-proposal-approved.sh` と
あわせてリポジトリ作成時からそのまま動く(追加の設定は不要。初回セッションで hooks の
実行許可を求められたら内容を確認して許可する)。スクリプトは `changes/*/design.md`・
`tasks.md` への書き込みだけを検査し、対象外のパスは exit 0 で通す
(ブロックは exit 2 — stderr がそのままAIへのフィードバックになる)。
hooks は起動ディレクトリの settings しか読まれないため、ワークスペース直下で開いた
セッションが `repos/` 配下を編集するケースに備え、ワークスペース層
(`.claude/settings.json` + `scripts/`)にも同じゲートを同梱している。

スタックが決まったら、フォーマット・lint・テストゲートも同様に
`.claude/settings.json` へ追記して hooks 化する。

**Codex CLI で使う場合**: `AGENTS.md` は Codex CLI がネイティブに読むため、追加設定なしで
両層の運用ルールが適用される。ただし hooks・`.claude/rules/`・`.claude/skills/` は
Claude Code の機構で、Codex は読まない:

- スキル(hearing / lens-review / setup-repo / tanaoroshi / session-end)は
  「`.claude/skills/<name>/SKILL.md` を読んでその方法論で進めて」と指示すれば
  同等に使える(自動起動しないだけ)
- 承認ゲート hook は効かないため、スペック必須の変更を Codex に任せる場合は
  承認欄の確認を人間が行う
- すべてのCLIに守らせたい規範は AGENTS.md 本文に書く(hooks や rules に置かない)

## 運用の要点

- 要件が曖昧なまま proposal を書かせない。まず hearing スキル(ワークスペース同梱。
  `repos/` 配下では symlink で取り込む — 導入手順参照)で聞き切ってから
- スペック必須の変更は「changes/ に proposal を作って」から。承認まで design・実装に進ませない
- 決定・学びは会話中に都度書き込ませる(「後で書く」はさせない)
- レビューは多視点で: 実装した本人以外のAIにレンズ(UX・セキュリティ・法務など)を指定して
  レビューさせる(リポジトリ層同梱の `lens-review` スキル)。別ベンダーのAIとの併用で
  検出率がさらに上がる
- 失敗したら「やり直せ」ではなく「原因を分析して learnings.md に残してから直して」と指示する
- セッションの終わりに「終了処理して」と一声かける(`session-end` スキルが未コミット確認・
  書き漏れチェック・journal 反映・STATUS 更新をワンセットで行う)
- 月1回程度「棚卸しして」と一声かける(`tanaoroshi` スキルが deprecated の整理・
  stale_after の見直し・learnings の昇格候補・100行上限の点検を提案としてまとめる)
- 複数エージェントを並列で走らせるときは git worktree でタスクごとに隔離する
  (同一ワーキングディレクトリの同時編集は破綻する)

## ライセンス

MIT License([LICENSE](LICENSE))
