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
| 手順(必要な時だけ読む) | `.agents/skills/`(オンデマンドでロード。Claude Code は `.claude/skills/` の symlink 経由) |
| 例外なく強制するルール | hooks(決定的に実行される唯一の手段) |

両層の `docs/learnings.md`(失敗と学び。リポジトリ層はコードと技術、ワークスペース層は運営)が
育ったら、hooks / `docs/rules/`(パス限定の規約)/ skills / AGENTS.md へ昇格させる。「学び → 恒常化」の一方通行で、恒常層の肥大化を防ぐ。

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
承認前に design・tasks を書かせないゲートは、指示ではなく hooks で機械的に強制する
(実装そのものは止めない。後述)。

### 3. ナレッジに信頼度を持たせる — AIは古い・未検証の文書にも自信満々に従う

`docs/decisions/`・`docs/knowledge/` の frontmatter は OKF(Open Knowledge Format、
Google Cloud 発のオープン仕様)を部分採用した方言で、信頼シグナルを機械可読にする:

- `generated`(誰がいつ書いたか)と `verified`(誰が検証したか)を分離する
- 決定記録(decisions)は `status: stable`(=ユーザー承認済み)を信頼の根拠にし、`draft` は参考扱い
- 事実・調査の記録(knowledge)は `verified` で信頼度を示す — 未検証 → 書いた文脈以外(別セッション・
  別の AI。別ベンダー推奨)が検証 → 人間が検証。**自己検証は禁止**
- 本文を変更したら既存の `verified` は削除する(検証は失効する)
- `stale_after`(鮮度期限)を超えた記録と `deprecated` は判断根拠にしない

actor 表記(`agent:<tool>@<role>` / `human:<id>`)と日付(YYYY-MM-DD)は OKF を簡略化した
方言で、厳密準拠が必要になれば機械変換できる粒度を保っている。

仕様: https://github.com/GoogleCloudPlatform/knowledge-catalog

## 構成

```
project-workspace/
├── AGENTS.md              # ワークスペース層の運用ルール(まず読む)
├── CLAUDE.md              # `@AGENTS.md` の1行だけ(Claude Code 用の入口。下記)
├── STATUS.md              # 現在地(進行中・open な宿題・次の一手)
├── journal/               # 時系列ログ: 日誌・議事録(YYYY-MM-DD.md、追記専用。ため方は同README)
├── docs/                  # 主題別の生きた文書(要件・関係者情報など)
│   ├── learnings.md       #   運営側の失敗と学び(リポジトリ層と同じゲート・昇格方式)
│   └── decisions/         #   事業・運営判断の決定記録(リポジトリ層と同じOKF互換書式)
├── materials/             # ファイル原本+AI可読の変換版(方法は同README)
├── .agents/skills/        # ワークスペース共有スキル(正典。README 参照)
├── .claude/skills/        # → .agents/skills/ への symlink(Claude Code 用の入口)
├── scripts/               # hooks 用スクリプト(承認ゲート・認証情報検出・自己テスト。設定は .claude/settings.json と .codex/hooks.json)
├── .devcontainer/         # 汎用開発コンテナ(コンテナ運用しない場合は無視してよい。同README参照)
├── repos/                 # コードリポジトリ置き場(git 管理外。各リポジトリが独立した git)
└── templates/
    ├── modules/
    │   └── multi-agent/   # 追加モジュール: Issue駆動の並列実行(必要になったら導入。同README参照)
    └── repo/              # リポジトリ層テンプレート(repos/ に新規リポジトリを作るときコピー)
        ├── AGENTS.md      # 正典。100行以下を維持(+ `@AGENTS.md` だけの CLAUDE.md)
        ├── changes/       # 変更スペック(大きい変更のみ proposal → design → tasks)
        ├── scripts/       # hooks 用スクリプト(承認ゲート・認証情報検出・自己テスト)
        ├── .codex/hooks.json  # Codex CLI 用の hooks 設定(同じスクリプトを登録)
        ├── docs/
        │   ├── STATUS.md      # 現在地(毎セッション必読)
        │   ├── learnings.md   # 失敗と学び(毎セッション必読・100行上限)
        │   ├── PROJECT.md     # 安定した背景情報(オンデマンド)
        │   ├── decisions/     # 決定記録=「なぜ」の記録
        │   ├── knowledge/     # 再利用する技術調査・バグ解決・一次資料
        │   └── rules/         # パス限定の規約(該当パスを触る前に読む。どの CLI でも効く)
        ├── .agents/skills/    # リポジトリ固有の手順スキル(正典。Codex も自動発見)
        └── .claude/
            ├── settings.json  # hooks 設定(既定で有効)
            ├── rules/     # Claude Code 専用の補助(守らせたい規約は docs/rules/ へ)
            └── skills/    # → ../.agents/skills/ への symlink(Claude Code 用の入口)
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
git add -A && git commit -m "🎉 init: リポジトリ層テンプレートを展開"  # ロールバック地点を最初に作る
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
ln -s ../../../../.agents/skills/<skill-name> repos/<repo>/.agents/skills/<skill-name>   # 正典(Codex も読む)
ln -s ../../.agents/skills/<skill-name>       repos/<repo>/.claude/skills/<skill-name>   # Claude Code 用の入口
```

この symlink はワークスペース内でのみ解決される。リポジトリを単体で clone・配布すると
dangling になるため、リポジトリ側 `.gitignore` で除外するか(setup-repo スキルは除外する)、
単体配布時はコピーに置き換える。除外した symlink は `git worktree` で作った作業先にも
引き継がれないので、必要ならワークスペース側の `SKILL.md` を直接読ませる。

## hooks — 承認ゲートと認証情報検出(同梱済み・既定で有効)

機械的に強制したいルールは AGENTS.md に書かず hooks にする(AGENTS.md の指示は
アドバイザリだが、hooks は登録した経路では決定的に実行される)。ひとつめが**承認ゲート** —
proposal の承認チェックが未記入のまま design.md / tasks.md を書こうとしたらブロックする
PreToolUse フック(ドライランで、指示だけではこのゲートが素通りできることを確認済み)。

`templates/repo/.claude/settings.json`(Claude Code)と `templates/repo/.codex/hooks.json`(Codex CLI)に
設定済みで、`scripts/check-proposal-approved.sh` とあわせてリポジトリ作成時からそのまま動く
(追加の設定は不要。初回セッションで hooks の実行許可・信頼確認を求められたら内容を確認して許可する)。スクリプトは `changes/*/design.md`・
`tasks.md` への書き込みだけを検査し、対象外のパスは exit 0 で通す
(ブロックは exit 2 — stderr がそのままAIへのフィードバックになる)。
hooks は起動ディレクトリの settings しか読まれないため、ワークスペース直下で開いた
セッションが `repos/` 配下を編集するケースに備え、ワークスペース層
(`.claude/settings.json` + `scripts/`)にも同じゲートを同梱している。

ふたつめが**認証情報検出** — 認証情報らしき文字列(AWSキー・GitHub / Slack /
Google / Stripe トークン・`sk-` 系APIキー・秘密鍵ブロック)を、これから書き込む内容から
検出してブロックする PreToolUse フック(`scripts/check-credentials.sh`)。AGENTS.md 安全節
「認証情報をどこにも書かない」の編集ツール経路を防御する(Bash リダイレクト等の
経路は対象外 — リポジトリ全体の検査が必要になったら gitleaks 等のコミット時スキャンを
別途足す)。誤検知を抑えるため、形式が一意に決まる高確度パターンのみを見る
(汎用の `password=...` 等は AGENTS.md のルールで守る)。こちらも両層に同梱している。

どちらのスクリプトも Claude Code(Write / Edit)と Codex CLI(`apply_patch`)の両方の入力形式を
扱う。Codex では `apply_patch` のパッチ本文からヘッダー行のパスを抽出して承認ゲートを判定し、
認証情報は追加行だけを検査する(漏えい済みの値を削除する編集は止めない)。JSON の解析に jq か
python3 が必要で、どちらも無ければ検査不能として理由を表示しブロックする。
`scripts/hooks-selftest.sh` が両形式の合成入力で挙動を検証する(実 CLI は不要)。

スタックが決まったら、フォーマット・lint・テストゲートも同様に
`.claude/settings.json` と `.codex/hooks.json` の両方へ追記して hooks 化する。

**Claude Code で使う場合**: 両層の `CLAUDE.md` は `@AGENTS.md` の1行だけで、AGENTS.md を取り込む。
Claude Code は v2.1.277 以降 AGENTS.md を直接読めるが、作業ディレクトリか祖先に CLAUDE.md があると
既定では AGENTS.md を読まない。symlink ではなく import 1行の実ファイルにすることで、バージョンや
symlink 非対応の環境(Windows 等)に関係なく同じ規則が読まれる。Claude 固有の注記が要ればこのファイルに足す。

**Codex CLI で使う場合**: `AGENTS.md` は Codex CLI がネイティブに読む。ただし探索範囲はプロジェクトルート
(通常は git root)からカレントディレクトリまでなので、`repos/` 配下(独立した git)で起動すると
ワークスペースの `AGENTS.md` は自動では読まれない — リポジトリ層 `AGENTS.md` が明示的に読むよう
指示している。スキルは `.agents/skills/` に置いてあるため Codex も自動発見する(`.claude/skills/` はその symlink)。承認ゲート・認証情報検出の hooks も
`.codex/hooks.json` で同じスクリプトが登録されており、初回の信頼確認後に `apply_patch`
経路を検査する(シェル等の別経路は対象外で、完全な防壁ではない)。`.claude/rules/` は
Claude Code の機構で Codex は読まないため、守らせたい規約は `docs/rules/` に置く:

- 自動発見されない CLI では「`.agents/skills/<name>/SKILL.md` を読んでその方法論で
  進めて」と指示すれば同等に使える
- hooks を持たない CLI に任せる場合は、承認欄の確認とコミット前の認証情報混入の確認を人間が行う
- すべてのCLIに守らせたい規範は AGENTS.md 本文に書く(hooks や rules に置かない)

## 運用の要点

- 要件が曖昧なまま proposal を書かせない。まず hearing スキル(ワークスペース同梱。
  `repos/` 配下では symlink で取り込む — 導入手順参照)で聞き切ってから
- スペック必須の変更は「changes/ に proposal を作って」から。承認まで design・実装に進ませない
  (承認する前に「この計画を叩いて」と一声かけると `grill-me` スキルが質問攻めで穴を潰す)
- 決定・学びは会話中に都度書き込ませる(「後で書く」はさせない)
- レビューは多視点で: 実装した本人以外のAIにレンズ(UX・セキュリティ・法務など)を指定して
  レビューさせる(リポジトリ層同梱の `lens-review` スキル)。別ベンダーのAIとの併用で
  検出率がさらに上がる(Codex CLI を呼ぶ手順は同梱の `codex` スキルが持つ)
- 失敗したら「やり直せ」ではなく「原因を分析して learnings.md に残してから直して」と指示する
- セッションの終わりに「終了処理して」と一声かける(`session-end` スキルが未コミット確認・
  書き漏れチェック・journal 反映・STATUS 更新をワンセットで行う)
- 月1回程度「棚卸しして」と一声かける(`tanaoroshi` スキルが deprecated の整理・
  stale_after の見直し・learnings の昇格候補・100行上限の点検を提案としてまとめる)
- 複数エージェントを並列で走らせるときは git worktree でタスクごとに隔離する
  (同一ワーキングディレクトリの同時編集は破綻する)

## テンプレートの保守

このテンプレート自身の運営記録(STATUS・journal・レビュー往復の原文)は、main ではなく
orphan ブランチ [`dev-log`](https://github.com/horatjp/project-template/tree/dev-log) に置いている
(テンプレートから作ったプロジェクトに保守の経緯を持ち込まないため)。このテンプレートで運営している実例としても読める。

テンプレート本体を保守するとき(AI 向けの手順を含む):

- AI セッションは main のワークスペース直下で起動する。`_devlog/` は記録の置き場で、そこでは起動しない
  (独立した worktree なので、そこで起動すると AGENTS.md・スキルが読まれない)
- `_devlog/` が無ければ展開する。ローカルに dev-log ブランチがあれば `git worktree add _devlog dev-log`、
  無ければ `git fetch origin refs/heads/dev-log:refs/remotes/origin/dev-log && git worktree add -b dev-log _devlog origin/dev-log`
  (single-branch clone でも動く形)。取得できなければ初期化を始めず、ユーザーに状況を報告する
- STATUS・journal・materials は `_devlog/` 側を読み書きし、`_devlog/` の中で dev-log ブランチにコミットする
  (push は `git push origin dev-log` と明示する)。
  main の STATUS・journal・materials は配布用の雛形のまま触らない(session-end も同じ)
- 設計判断の原本などは、main 側のローカル資料 `_archive/`(git 管理外)にある

## ライセンス

MIT License([LICENSE](LICENSE))
