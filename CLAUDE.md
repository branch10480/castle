# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> このファイルは Claude Code が毎ターン context に取り込む索引。**判断時に毎回参照する中核ルール**のみを置き、初回セットアップ手順や設計詳細は `docs/` 配下に切り出している。

## リポジトリ概要

homeshickで管理されているdotfilesリポジトリ。macOS環境向けの設定ファイルを集約。

## リポジトリ構造

```
castle/
├── home/           # ~ にシンボリックリンクされるファイル
│   ├── .config -> ../config
│   ├── .hammerspoon -> ../hammerspoon
│   ├── .codex/skills/<skill-name> -> ../../../codex/skills/<skill-name>
│   ├── .zshrc      # zsh 起動スクリプト本体（Ghostty 起動時 auto-attach tmux も含む）
│   ├── .zshrc.d/   # 機能別 zsh snippet（op.zsh など）— ~/.zshrc から自動 source
│   └── .tmux.conf  # tmux 設定（Ghostty 互換キーバインド・session group・プラグインは Nix 配布）
├── config/         # ~/.config にリンクされる設定
│   ├── nvim/       # Neovim設定（lazy.nvim使用）
│   ├── ghostty/    # Ghostty ターミナル設定（Claude Day light/dark テーマ含む）
│   ├── cmux/       # cmux アプリ動作設定（cmux.json）。ターミナル描画は libghostty 経由で ghostty/config を共有
│   ├── karabiner/  # Karabiner-Elements設定
│   ├── git/        # Git 関連設定（global ignore, allowed_signers (machine-local) ）
│   ├── nix-darwin/ # nix-darwin + Home Manager 構成
│   ├── op/         # 1Password CLI 関連（*.env テンプレ＝op:// URI のみ追跡、他は ignore）
│   └── ssh/        # SSH client config（~/.ssh/config から `Include` で参照）
├── claude/         # Claude Code用設定（~/.claude/にリンク）
│   ├── agents/     # カスタムエージェント定義
│   ├── commands/   # ユーザー呼び出し可能なコマンド
│   ├── skills/     # Claude用スキル本体
│   ├── statusline.py            # ステータスラインスクリプト
│   └── statusline-config.json   # ステータスライン設定テンプレート
├── codex/          # Codex用設定
│   └── skills/     # Codex用スキル本体
├── docs/           # 技術ドキュメント（運用詳細・ワークアラウンド解説等）
├── scripts/        # 運用スクリプト（Codexスキル同期、ステータスラインセットアップなど）
└── hammerspoon/    # Hammerspoonマクロ
```

## 主要コマンド・スキル

- `/castle` - castleリポジトリの変更をcommit & push（メッセージは差分から英語で自動生成）
- `/push` - 汎用的なgit add, commit, push
- `/zama-parking` - イオンモール座間 駐車場空き状況確認
- `/htmla` - HTML 形式で成果物を生成（design tokens は `claude/skills/htmla/design-system.html`、使い方は `docs/htmla-usage.html`）
- `clog` (zsh 関数) - Claude Code セッション横断検索（worktree を跨いで「どこで何を話したか」を再現）。詳細: [`docs/clog-usage.md`](docs/clog-usage.md)
- `tmuxreset` (zsh 関数) - Claude Code teammateMode=tmux が残す pane-border override を消すエスケープハッチ。詳細: [`docs/tmux-claude-pane-borders.md`](docs/tmux-claude-pane-borders.md)
- `apauto` (zsh 関数) - 時刻ベース appearance auto-switch の一時 OFF。詳細: [`docs/theme-appearance-switching.md`](docs/theme-appearance-switching.md)
- `nru` (zsh 関数) - `nix flake update` を 1Password 経由の GitHub PAT 付きで実行。詳細: [`docs/phase9-nix-github-pat.md`](docs/phase9-nix-github-pat.md)
- `scripts/scan-secrets.sh` - 既知パターンの API キー / 秘密鍵を grep する軽量スキャナ。`--staged` で git index のみスキャン可
- `scripts/setup-claude-mcp-perplexity.sh` - `~/.claude.json` の `mcpServers.perplexity.--env-file` を `/tmp/op-mcp-perplexity.env` に向け直す jq 書換え（Phase 4 + `op-warm-mcp` と組）

## スキル管理

- Claude用スキルは `claude/skills/<skill-name>/SKILL.md` で管理する
- Codex用スキルは `codex/skills/<skill-name>/SKILL.md` で管理する
- Codexスキルを追加・削除したら `scripts/sync-codex-skills.sh` を実行し、`home/.codex/skills/<skill-name>` の repo 相対 symlink を更新する
- Codexのユーザースコープ指示は `home/.codex/AGENTS.md` で管理し、homeshick 経由で `~/.codex/AGENTS.md` にリンクする
- `~/.codex/config.toml` / `~/.codex/auth.json` / `~/.codex/hooks.json` は machine-local な state を含むため、丸ごと symlink しない。共有したい設定が増えた場合は Claude hooks と同じく nix-darwin activation で局所 patch する

Codex スキル追加・削除時の反映順:

```bash
scripts/sync-codex-skills.sh
homeshick link castle
```

既存 Mac では `~/.codex/` が Codex の state directory として実体化している。`~/.codex` ディレクトリ全体を castle 側の symlink に置き換えると `auth.json` / logs / plugin cache などを巻き込むため、`AGENTS.md` と `skills/<skill-name>` だけを個別 symlink として扱う。

## Neovim設定

- パッケージマネージャ: lazy.nvim
- 設定エントリ: `config/nvim/init.lua`
- プラグイン: `config/nvim/lua/plugins/`
- 基本設定: `config/nvim/lua/config/` (options, keymaps, autocmds)

## シェル設定

zsh使用。主要ツール: anyenv（各種言語バージョン管理）/ starship（プロンプト）/ zoxide（ディレクトリジャンプ、`j`コマンド）/ fzf + ghq（リポジトリ選択、`Ctrl+]`）。

### `~/.zshrc.d/` の auto-source と新規 snippet 追加時の落とし穴

`home/.zshrc` の末尾で `~/.zshrc.d/*.zsh(N)` を全部 source する（`(N)` = NULL_GLOB、symlink 不在なら silent skip）。

**罠**: zsh は起動時に rc を **1 度だけ** source するため、新しい snippet を追加・symlink しても**既に起動している zsh プロセスには反映されない**。Ghostty + tmux session group 方式では tmux session が生きている限り中の zsh も生き続けるためドリフトしやすい。`which <新関数>` で "not found" が出たらこれを疑う。

反映の仕方:

```bash
source ~/.zshrc.d/<新スニペット>.zsh   # 関数定義の追加なら既存セッションでも source で十分
exec "$SHELL" -l                         # rc 全体を読み直したい場合
# tmux 内で複数 pane に居る場合は各 pane で個別に実行
```

新規 snippet を足したら `exec "$SHELL" -l` を癖にすると安全。

## ターミナル / マルチプレクサ

- **Ghostty**（ターミナル）と **tmux**（マルチプレクサ）の組み合わせ。Ghostty はキー入力・表示・タブ管理に専念し、ペイン分割/移動/リサイズ/コピーモードは tmux 側に集約
- `home/.tmux.conf` で Ghostty 互換キー (`Ctrl+;` 分割 / `Ctrl+h/j/k/l` 移動 / `Ctrl+Shift+...` リサイズ / `Ctrl+Shift+x` copy mode) を `bind -n` で再現
- `home/.zshrc` の "Ghostty: auto-attach tmux" ブロックで **session group 方式**を採用: 1 タブ目は `main` セッション作成、2 タブ目以降は `ghostty-<pid>` として join — タブを増やしても session が雪だるま化しない
- 詳細・キーマッピング表・移行時の罠（`'C-\;'` シングルクォート / `=main` zsh EQUALS 展開）は [`docs/tmux-setup.md`](docs/tmux-setup.md)
- Claude Code の `teammateMode=tmux` が残す pane-border override の自動クリーンアップは [`docs/tmux-claude-pane-borders.md`](docs/tmux-claude-pane-borders.md) を参照（hook で自動発火 + `tmuxreset` で手動エスケープ）

## テーマ運用ルール（Light/Dark = 1pt 差 + Dark = warm-lifted layered gray）

castle が配布する Light/Dark ペアテーマには **「Dark のフォントサイズを Light よりちょうど 1pt 大きく取る」** という共通契約を置く。アプリ横断で揃えることで、OS の appearance 切替時に「色だけでなくフォントサイズも自動でついてくる」体験を作る。

実装側の詳細（Ghostty の制約と Hammerspoon hook 方式、Accessibility 権限の自己チェック、時刻ベース auto-switch、`apauto`、新規テーマ追加指針）は [`docs/theme-appearance-switching.md`](docs/theme-appearance-switching.md) を参照。

### ルール

- **Light が基準（小さい側）/ Dark がそれより +1pt（大きい側）**
- 既存配布物の対応:
  | アプリ | Light | Dark | 実現方式 |
  |---|---|---|---|
  | Xcode | 11.5pt (`ClaudeDay.xccolortheme`) | 12.5pt (`ClaudeDayDark.xccolortheme`) | テーマファイル内に font-size を直接定義 (`config/nix-darwin/files/xcode/`) |
  | Ghostty | 12pt | 13pt | Hammerspoon hook 経由 (`hammerspoon/init.lua` が `~/.config/ghostty/config.local` を appearance に応じて書き換え) |
  | cmux | 12pt | 13pt | libghostty 内蔵により Ghostty config をそのまま共有。`config.local` include + 自動 watch を継承するため、Hammerspoon の reload 発火に頼らずファイル更新だけで追従する (実機検証 2026-05-17、詳細は [`docs/theme-appearance-switching.md`](docs/theme-appearance-switching.md)) |
  | markdownobserver | アプリ本体決定 | アプリ本体決定 | 適用外 (`user.css` に絶対値 font-size を持たない設計、`@media (prefers-color-scheme: dark)` 内に font override 無し) |
  | Kaleidoscope | plist で管理 | plist で管理 | 適用外 (`config/nix-darwin/files/kaleidoscope/` の highlight.js 互換 CSS ペア `Claude Day-light.css` / `Claude Day-dark.css` は **token color のみ責任**を持つ。chrome 背景・本文色は Kaleidoscope app appearance に追従、エディタ font-size は plist `KSTextScopeFontInfoUserDefaultsKey` が真実の源。OS appearance dispatch はファイル名 suffix `-light` / `-dark` で実現 — KSCore 同梱の Solarized-{light,dark}.css と同経路。CSS 構造も Solarized 完全互換で `EXC_BREAKPOINT` クラッシュ回避) |
- 例外を作る場合（特定アプリの仕様で 1pt 差が破綻する等）は、該当テーマファイルのヘッダコメントに **理由を明記** してから外す
- **Font weight も基本は Light/Dark で揃える** (どちらも Regular)。ただしアプリ側 rendering の都合で「同じ weight なのに片方だけ太く見える」場合は、該当アプリのテーマだけ weight を 1 段ずらして他アプリと視覚的な重みを揃える（後述の Xcode 例外）
- **アプリ別の weight 例外**:
  | アプリ | Light weight | Dark weight | 理由 |
  |---|---|---|---|
  | Xcode | `JetBrainsMonoNF-Regular` | `JetBrainsMonoNF-Light` | Xcode の text rendering は他アプリ (Ghostty / markdownobserver) より同 pt・同 PostScript 名でも筆画が太く出る。Dark で Regular のままだと castle 全体の重み感が揃わないため、Dark だけ 1 段細い weight を採用 (2026-05) |
  | Ghostty | `JetBrainsMono Nerd Font` Regular | 同左 | rendering は素直 (例外不要) |
  | cmux | `JetBrainsMono Nerd Font` Regular | 同左 | libghostty 経由で Ghostty 設定をそのまま使うため挙動同一 (例外不要) |
  | markdownobserver | system stack | 同左 | rendering は素直 (例外不要) |

### 根拠（Why）

- 暗背景は明背景に比べてコントラスト感が低く、**同じ pt でも筆画が細く感じる**。Dark を持ち上げることで Light と視覚的な「重み」を揃え、テーマ切替時に脳が疲れない
- 当初は +1pt 差を採用していた (Light 13pt / Dark 14pt) が、appearance 切替時の「ガクッと大きさが変わる」違和感が強かったため、**+0.5pt の中庸に倒した** (2026-05 方針転換)
- その後 +0.5pt 運用を試したところ、切替時の不連続感は確かに緩和されたものの、**Dark で前景文字が痩せて見える違和感のほうが恒常的に煩わしい**ことが分かったため、**再度 +1pt 差に戻した** (2026-05-15 再方針転換)。castle 全アプリ共通 (Xcode 11.5/12.5、Ghostty 12/13)
- Ghostty 側 (`hammerspoon/init.lua`) の `string.format` は `%g` のままにする (整数 12/13 ペアでは `%d` でも動くが、将来また 0.5pt 刻みの中間値に戻す可能性を残すため `%g` を維持する)

### Dark = warm-lifted layered gray（背景階層）

Light/Dark の 1pt 差ルールと独立して、**Dark テーマ側は背景を単色の純黒に倒さず、warm-leaning な多階層 gray で構成する**という共通契約を置く。Light 側の ivory `#FAF9F5`（純白ではなく暖色寄り）と対称な「warm dark」を維持し、editor / terminal / Markdown reader の 3 サーフェイスで同じ vocabulary を共有する。

#### Tier 構成

| Tier | 値 | 役割 |
|---|---|---|
| **tier 0** (page bg) | `#1a1916` | エディタ / ターミナル / reader 本文の地。Xcode `DVTSourceTextBackground` / `DVTConsoleTextBackgroundColor`、Ghostty `background`、markdownobserver `--reader-bg` で共有 |
| **tier 1** (elevated card) | `#26241f` | 一段浮かす要素: Xcode current-line highlight / markup bg、markdownobserver `--reader-code-bg` と `--reader-blockquote-bg` で共有 |
| **tier 2** (panel) | `#2e2c27` | 表 / dl のセル背景 (markdownobserver `.markdown-body thead th / tbody tr:nth-child(even) td / dl`)。Xcode 側には現状対応 surface なし |
| **tier 3** (inline chip) | `#36332d` | inline code chip 等のさらに浮かせる要素 (markdownobserver `--reader-code-inline-bg`) |
| **border** | `#3a3833` | hairline / invisibles。Xcode `g300-d` / markdownobserver `--reader-border` で統合 |

#### ルール

- **tier 0 を純黒 (`#000000`) に倒さない**：Light の ivory と対称な warm-dark を保つため。OLED 焼き付き対策よりも目の暗順応下での "浮き" の知覚を優先
- **tier 0 と tier 1 の差を +0.05 程度確保する**：上の elevated surface が地に対して肉眼で identify できる段差を取る
- **新規 Dark テーマを足すときも tier 0 = `#1a1916` を起点に揃える**：Light の `#FAF9F5` 起点ルールと対をなす
- 例外を作る場合（surface 制約で多階層を持てない等）は、該当ファイルのヘッダコメントに **理由を明記** してから外す（Ghostty は single-surface なので実質 tier 0 のみ採用）

#### 根拠（Why）

- 純黒は OLED の焼き付き対策には有利だが、**前景の暖色アクセント (`#d4cfc1` fg-d、`#D97757` clay) が浮きすぎる**。castle Light の暖色設計と対称性が取れない
- 旧 Dark (`#131312` 単色) は暗順応下で tier 0 / tier 1 の差 (+0.04) が潰れ、layer 構造が **存在するのに視認できない** 状態だった。tier 0 を +0.03 lift するだけで上層 token (`#1d1c1a` → `#26241f` 等)を比例 lift する必要があり、結果として全 tier を連動 lift した
- Anthropic 自身の最新 claude.ai は純黒方向に倒している (コミュニティから regression 扱い) が、castle は意図的に「以前の claude.ai の layered dark gray」方向を採用

## homeshick操作

```bash
cd ~/.homesick/repos/castle
homeshick link castle                       # シンボリックリンク作成
scripts/setup-claude-statusline.sh          # ステータスライン適用（初回 or 設定変更時）
/castle                                     # 変更を commit & push（Claude Code から）
```

## nix-darwin / Home Manager

`config/nix-darwin/` に nix-darwin + Home Manager + Homebrew(宣言) の構成を集約。詳細は `config/nix-darwin/README.md`。

```bash
scripts/bootstrap-nix-darwin.sh                          # 初回適用（Nix インストール後）
darwin-rebuild switch --flake ~/.config/nix-darwin       # 日常運用
```

方針:
- CLI = Nix (`home.nix` の `home.packages`) / GUI = Homebrew (`darwin.nix` の `homebrew.casks`)
- 既存 dotfiles は homeshick 管理を維持し、HM の `programs.<tool>` は有効化しない
- Homebrew は `cleanup = "none"` で安全側起動（取り込み完了後に `"zap"` 化を検討）

## Secrets management（Phase 一覧）

API キー・秘密鍵・SSH 鍵は 1Password を真実の源として、`op run` / `op-ssh-sign` 経由で**実行時注入**する。Phase ごとに対象が異なる:

| Phase | 対象 | 詳細 |
|---|---|---|
| **2** | 1Password CLI シェル統合（`op-status` / `oprun` / `op-warm-mcp` / shell plugins） | [`docs/op-cli-setup.md`](docs/op-cli-setup.md) |
| **3** | castle 外プロジェクトの `.env` を `op://` で運用 | [`docs/op-env-pattern.md`](docs/op-env-pattern.md) |
| **4** | Claude Code MCP API キーを op:// 経由で隠匿（per-pane Touch ID 回避含む） | [`docs/op-cli-setup.md`](docs/op-cli-setup.md), [`docs/op-touchid-investigation.md`](docs/op-touchid-investigation.md) |
| **5** | ASC API キー (`.p8`) を配信時のみ展開 | [`docs/asc-api-key-op.md`](docs/asc-api-key-op.md) |
| **8** | 仕事 Mac での差分セットアップ（別 1Password アカウント / 別 GitHub identity） | [`docs/work-mac-setup.md`](docs/work-mac-setup.md) |
| **9** | `nix flake update` を 1Password 経由 GitHub PAT で認証付き fetch | [`docs/phase9-nix-github-pat.md`](docs/phase9-nix-github-pat.md) |
| **10** | `sudo` を Touch ID で承認（`pam_reattach.so` + `pam_tid.so`） | [`docs/phase10-sudo-touchid.md`](docs/phase10-sudo-touchid.md) |

SSH / Git commit signing の初回セットアップ手順は [`docs/ssh-git-setup.md`](docs/ssh-git-setup.md)。

## 機密情報の取り扱い（castle / Claude Code 共通ルール）

Phase 4 の副産物として、castle 配下と Claude Code 越しの作業全般に適用する**毎ターン参照する**運用ルール。

### 生 API キーをコミットしない・transcript に残さない

- 生キーが付くファイル（`~/.claude.json` / `~/.codex/auth.json` / 各種 `.env` / `claude_desktop_config.json` など）は **値を直接 `cat` / `Read` / `jq -r` で読まない**。`jq -r 'paths(scalars) | join(".")' <file>` でキーパスのみ抽出する
- 万一 transcript に流出したら **即座にユーザーに通知し当該キーを rotate**。Claude Code の transcript はディスクに永続化される (`~/.claude/projects/.../*.jsonl`)
- castle で commit する直前に `scripts/scan-secrets.sh --staged` を走らせる（`pplx-` / `sk-…` / `AKIA…` / `eyJ…` JWT・OpenSSH/PGP private key block を検出）
- env-file テンプレ（`config/op/*.env`）は **`op://` URI のみ**。生キーが入った瞬間にこのファイルは secret 化するので、`scan-secrets.sh` で再確認してから push

### 1Password に保管する項目（推奨カテゴリ）

| 種別 | 1Password テンプレ | URI 例 |
|---|---|---|
| MCP サーバ用 API キー（Perplexity 等） | API Credential | `op://Private/Perplexity API/credential` |
| GitHub PAT（gh の Shell Plugin 経由） | API Credential | `op://Private/GitHub PAT/credential` |
| Nix flake fetch 用 GitHub PAT（Phase 9）| API Credential | `op://Private/GitHub Public PAT/credential` |
| OpenAI / Anthropic 等の生 API キー | API Credential | `op://Private/<service>/credential` |
| SSH 秘密鍵 | SSH Key | （op-ssh-sign 経由で参照、URI 不要） |
| OAuth refresh token（Codex 等） | Login | `op://Private/<service>/refresh_token` |

> ⚠️ `credential` は API Credential テンプレの **内部フィールド id**。UI 言語設定で label が「認証情報」や「token」と表示されても、`op://` URI で参照するのは固定の id `credential`。マシン間で UI 言語が違っても URI は壊れない設計なので、テンプレに統一しておけば共通化できる。

### `~/.claude.json` を編集するときの掟

- このファイルは Claude Code が動的に書き換える状態ファイル。**ファイル全体を書き換えない**（jq で `.mcpServers.<name>` のように局所更新する）
- 編集前にバックアップ: `cp ~/.claude.json{,.bak.$(date +%Y%m%d-%H%M%S)}`
- 編集後は **Claude Code を再起動**してから `claude mcp list` で反映を確認
