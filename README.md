# My Castle

macOS 用 dotfiles リポジトリ。[homeshick](https://github.com/andsens/homeshick) で symlink を貼り、[nix-darwin](https://github.com/LnL7/nix-darwin) + [Home Manager](https://github.com/nix-community/home-manager) で CLI / フォント / GUI アプリも宣言的に管理する。

詳細な技術解説・トラブルシュートは [`CLAUDE.md`](CLAUDE.md) と [`docs/`](docs/) 配下に集約してある。本 README は **何が入っているかの案内図** に徹する。

## クイックスタート

```bash
# 1. homeshick で symlink を貼る
brew install homeshick
homeshick clone git@github.com:branch10480/castle.git
homeshick link castle

# 2. nix-darwin で CLI / フォント / Homebrew cask を一括宣言適用
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
~/.homesick/repos/castle/scripts/bootstrap-nix-darwin.sh
```

> 仕事 Mac（別の 1Password アカウント / 別の GitHub identity / 別の SSH 鍵を使う環境）でセットアップする場合は、個人 Mac との差分手順を [`docs/work-mac-setup.md`](docs/work-mac-setup.md) に集約してあるので併せて参照すること。

## 含まれる設定

### シェル (zsh)

- **starship** — カスタムプロンプト
- **anyenv** — 言語バージョン管理（pyenv / nodenv 等）
- **zoxide** — スマートディレクトリジャンプ (`j` コマンド)
- **fzf + ghq** — リポジトリ選択 (`Ctrl+]`)
- **wtp + fzf** — ワークツリー選択 (`Ctrl+w`)
- **`~/.zshrc.d/*.zsh`** — 機能別 snippet（`op.zsh` など）を自動 source（[CLAUDE.md の Phase 2 節](CLAUDE.md)）

### ターミナル (Ghostty)

- カラースキーム: **Claude Day** (light) / **Claude Day Dark** (dark) — macOS Appearance に追従して自動切替
- フォント: JetBrainsMono Nerd Font Mono + ヒラギノ角ゴ ProN W3（[`docs/font-strategy.md`](docs/font-strategy.md)）
- マルチプレクサ操作（ペイン分割・移動・リサイズ・コピーモード）は **tmux に移譲**。Ghostty 単体のキーバインドはコメントアウト残置 → [`docs/tmux-setup.md`](docs/tmux-setup.md)
- split 時の CWD 復元: [`docs/ghostty-cwd-workaround.md`](docs/ghostty-cwd-workaround.md)

### マルチプレクサ (tmux)

- Ghostty 互換キーで運用: ペイン分割 `Ctrl+;` / `Ctrl+'`、移動 `Ctrl+h/j/k/l`（vim-tmux-navigator 経由で nvim と seamless）、リサイズ `Ctrl+Shift+h/j/k/l`、均等化 `Ctrl+Shift+=`、copy mode `Ctrl+Shift+x`
- Ghostty 起動時に **session group 方式**で auto-attach: 1 タブ目は `main` セッション作成、2 タブ目以降は `ghostty-<pid>` として group join → タブ増加で session 雪だるま化しない
- 設定本体: [`home/.tmux.conf`](home/.tmux.conf) / 起動ロジック: [`home/.zshrc`](home/.zshrc) の "Ghostty: auto-attach tmux" ブロック
- 詳細・キーマッピング表・移行時の罠（`'C-\;'` シングルクォート / `=main` zsh EQUALS 展開）: [`docs/tmux-setup.md`](docs/tmux-setup.md)

### エディタ (Neovim)

- パッケージマネージャ: **lazy.nvim**
- ファイラー: oil.nvim / ファジーファインダー: telescope.nvim / インデント自動検出: guess-indent.nvim
- UI 改善: noice.nvim（コマンドライン・メッセージ・通知）/ 自動ペア補完: nvim-autopairs
- 構文解析: nvim-treesitter（ハイライト・インデント・折りたたみ）
- スタートダッシュボード: dashboard-nvim / LSP 対応

### Markdown ビューア (MarkdownObserver fork)

- カスタム CSS テーマ **Claude Day** (light/dark 対応、`prefers-color-scheme` 連動)
- nix-darwin の `home.file` 経由で `~/Library/Application Support/MarkdownObserver/themes/user.css` に symlink 配布
- 実体: `config/nix-darwin/files/markdownobserver/user.css`

### Xcode

- カスタムテーマ **Claude Day**（chrome = Claude Day トーン、syntax = Sunset ベース + グレースケール comment）
- nix-darwin の `home.activation` 経由で `~/Library/Developer/Xcode/UserData/FontAndColorThemes/` に**実ファイル**配置（Xcode は symlink を辿らないため。詳細は [`docs/nix-darwin-manual.md`](docs/nix-darwin-manual.md) §5.10）

### Git

- commit signing は **1Password SSH agent + `op-ssh-sign`** 経由（GPG 不要、Touch ID で都度承認）
- `tig` — `K` で未ステージ差分を Kaleidoscope で表示
- identity（`user.email` / `user.signingkey`）は **machine-local** な `~/.gitconfig.local` に分離（個人 Mac / 仕事 Mac で同一 castle のまま identity を切替可能）

### SSH

- 認証 (`auth`) も commit signing も **1Password agent** 経由で完結（秘密鍵をディスクに置かない）
- `config/ssh/config` に共通設定を集約。`~/.ssh/config` は `Include ~/.config/ssh/config` の 1 行 stub
- 1Password agent socket パスは AgileBits Team ID 由来でアカウント横断共通 → 個人 / 仕事 Mac で同じ設定が動く

### 1Password CLI 統合（zsh + MCP + プロジェクト `.env`）

| 用途 | 仕組み | 詳細 |
|---|---|---|
| 対話 zsh から API キーを注入 | `oprun -- <cmd>` | [CLAUDE.md Phase 2](CLAUDE.md) |
| MCP サーバの API キー隠匿 | `~/.claude.json` の `mcpServers.<name>` を `op run` でラップ | [CLAUDE.md Phase 4](CLAUDE.md) |
| プロジェクトの `.env` を `op://` 化 | `.env.op` (commit OK) + `.env.op.local` (ignore) | [`docs/op-env-pattern.md`](docs/op-env-pattern.md) |
| ASC API キー (`.p8`) を配信時のみ展開 | `asc-upload <ipa>` で 1P から取得 → altool → trap で削除 | [`docs/asc-api-key-op.md`](docs/asc-api-key-op.md) |

### nix-darwin + Home Manager

- **CLI = Nix** (`home.nix` の `home.packages`)
- **GUI アプリ = Homebrew Cask** (`darwin.nix` の `homebrew.casks`)
- フォント (JetBrainsMono Nerd Font 等) = Nix
- 詳細: [`docs/nix-darwin-manual.md`](docs/nix-darwin-manual.md) / [`config/nix-darwin/README.md`](config/nix-darwin/README.md)
- 日常運用: `darwin-rebuild switch --flake ~/.config/nix-darwin`（`nrs` エイリアス）

### キーボード / macOS GUI

- **Karabiner-Elements** — CapsLock→Control、日本語キーボードカスタマイズ
- **Hammerspoon** — `Ctrl+Space` でターミナル (Ghostty) にフォーカス
- **BetterTouchTool** — カスタムジェスチャー
- **Raycast** — ランチャー設定 (`config/raycast/`)

### Claude Code 設定

- カスタムエージェント (`claude/agents/`) / コマンド (`claude/commands/`) / スキル (`claude/skills/`)
- 主要スキル:
  - **`/castle`** — このリポジトリの変更を commit & push（メッセージは差分から英語で自動生成）
  - **`/html-artifact`** — Claude Day デザイン言語の HTML 成果物（spec / report / mockup / プロトタイプ等）を生成。使い方: [`docs/html-artifact-usage.html`](docs/html-artifact-usage.html)
  - **`/zama-parking`** — イオンモール座間 駐車場空き状況確認
- ステータスライン: `scripts/setup-claude-statusline.sh` で `~/.claude/settings.json` に適用

### Codex 設定

- Codex 用スキル本体は `codex/skills/` で管理
- `~/.codex/skills/` は `home/.codex/skills/` 経由で homeshick 管理
- 同期: `scripts/sync-codex-skills.sh`（詳細手順は [CLAUDE.md の Codex セクション](CLAUDE.md)）

## Claude Day デザイン言語

castle 全体で **同じカラーパレット + 同じフォント語彙** を貫くポリシー。Anthropic ブランドカラー（clay `#D97757` / ivory `#FAF9F5` / slate `#141413`）を anchor に、light / dark 両モードで一貫した見た目を提供する。

| サーフェス | 担当ファイル |
|---|---|
| HTML 成果物（`/html-artifact` 出力） | `claude/skills/html-artifact/design-system.html` |
| MarkdownObserver | `config/nix-darwin/files/markdownobserver/user.css` |
| Xcode | `config/nix-darwin/files/xcode/ClaudeDay.xccolortheme` |
| Ghostty | `config/ghostty/themes/Claude Day` / `Claude Day Dark` |

## 関連ドキュメント

| ドキュメント | 内容 |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | 人間 + Claude Code 向けの全体ガイド（Phase 2〜8 のセットアップ手順含む） |
| [`docs/nix-darwin-manual.md`](docs/nix-darwin-manual.md) | nix-darwin / Home Manager / 宣言 Homebrew の運用マニュアル |
| [`docs/font-strategy.md`](docs/font-strategy.md) | アプリ横断のフォント戦略（JBM + ヒラギノ角ゴ） |
| [`docs/op-env-pattern.md`](docs/op-env-pattern.md) | プロジェクト `.env` を `op://` で運用するパターン |
| [`docs/work-mac-setup.md`](docs/work-mac-setup.md) | 仕事 Mac での差分セットアップ手順 |
| [`docs/ghostty-cwd-workaround.md`](docs/ghostty-cwd-workaround.md) | Ghostty split CWD 問題のワークアラウンド解説 |
| [`docs/html-artifact-usage.html`](docs/html-artifact-usage.html) | `/html-artifact` スキルの使い方ガイド |
| [`config/nix-darwin/README.md`](config/nix-darwin/README.md) | nix-darwin 構成ファイルの短縮版概要 |
| [`stylus/README.md`](stylus/README.md) | Slack 用 Stylus CSS の設定手順 |

## 安全装置

- `scripts/scan-secrets.sh` — 既知パターンの API キー / 秘密鍵を grep する軽量スキャナ。`--staged` で git index のみスキャンも可。commit 直前に走らせる運用を推奨
- `homebrew.onActivation.cleanup = "none"` — 宣言外の brew/cask を消さない安全側起動。完全宣言管理 (`"zap"`) への切替は別途検討
