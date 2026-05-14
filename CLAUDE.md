# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
│   └── .tmux.conf  # tmux 設定（Ghostty 互換キーバインド・session group・プラグインは Nix 配布 → home.nix の home.file.".tmux/plugins.conf"）
├── config/         # ~/.config にリンクされる設定
│   ├── nvim/       # Neovim設定（lazy.nvim使用）
│   ├── ghostty/    # Ghostty ターミナル設定（Claude Day light/dark テーマ含む）
│   ├── karabiner/  # Karabiner-Elements設定
│   ├── git/        # Git 関連設定（global ignore, allowed_signers (machine-local) ）
│   ├── nix-darwin/ # nix-darwin + Home Manager 構成（flake.nix / darwin.nix / home.nix と、files/markdownobserver・files/xcode 配下の CSS / Xcode テーマも配布）
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
├── docs/           # 技術ドキュメント（ワークアラウンド解説等）
├── scripts/        # 運用スクリプト（Codexスキル同期、ステータスラインセットアップなど）
└── hammerspoon/    # Hammerspoonマクロ
```

## 主要コマンド・スキル

- `/castle` - castleリポジトリの変更をcommit & push（メッセージは差分から英語で自動生成）
- `/push` - 汎用的なgit add, commit, push
- `/zama-parking` - イオンモール座間 駐車場空き状況確認
- `/htmla` - HTML 形式で成果物（spec / report / mockup / プロトタイプ / リサーチ / 解説 / カスタムエディタ等）を生成。デザイントークンは `claude/skills/htmla/design-system.html`、使い方ガイドは `docs/htmla-usage.html`
- `scripts/scan-secrets.sh` - 既知パターンの API キー / 秘密鍵を grep する軽量スキャナ。`--staged` で git index のみスキャンも可
- `scripts/setup-claude-mcp-perplexity.sh` - `~/.claude.json` の `mcpServers.perplexity.--env-file` を `/tmp/op-mcp-perplexity.env` に向け直す jq 書換え（tmux ペイン単位の Touch ID 回避用、Phase 4 + `op-warm-mcp` と組）
- `tmuxreset` (zsh 関数) - Claude Code `teammateMode=tmux` が残す pane-border override（タイトル・片側オレンジ境界）を消すエスケープハッチ。本体は `scripts/tmux-clear-pane-border-overrides.sh` で、通常は `~/.claude/settings.json` の Stop / SubagentStop hook 経由で自動発火する（同期は nix-darwin `home.activation.patchClaudeHooks`）
- `clog` (zsh 関数) - Claude Code セッション横断検索。`~/.claude/projects/**/*.jsonl` を全 working directory 横断で grep し、「あの話をしたのはどの worktree だったっけ」を解決する。本体は `scripts/claude-session-search.py` で、詳細は下記「[Claude Code セッション横断検索 (`clog`)](#claude-code-セッション横断検索-clog)」を参照

## Claude Code セッション横断検索 (`clog`)

Claude Code は `~/.claude/projects/<encoded-cwd>/<session>.jsonl` にセッション記録を持つ（cwd を `/` → `-` に encode したディレクトリ + session UUID）。各行が JSON で `cwd / gitBranch / timestamp / sessionId / message` を含むため、全ファイル横断で grep すれば**どのディレクトリ / どの worktree で何を話したか**を再現できる。

`clog` は `~/.claude/projects/` 配下を全件 scan して `user` / `assistant` の発話本文だけを検索対象にする CLI。`scripts/claude-session-search.py` を `home/.zshrc.d/clog.zsh` の zsh 関数でラップしている。

### 典型的な使い方

```bash
clog Privacy Manifest                # AND 検索 (Privacy AND Manifest, ignore-case)
clog -g 'Phase 9'                    # cwd ごとのマッチ件数だけ集計 (どこで話したかを一覧)
clog --since 7d 'ranking'            # 直近 7 日のみ (7d / 12h / 30m / 2w / 2026-05-01)
clog --cwd ebookjapan-ios 'crash'    # cwd 部分一致で絞り込み
clog --regex 'op://[^ ]+/credential' # 正規表現
clog --role user 'やめてほしい'      # 自分の発話だけ (feedback の発掘に便利)
clog --full -n 0 'OAuth refresh'     # preview を切り詰めず全件
```

各ヒットには cwd / gitBranch / timestamp / preview に加え、`<jsonl path>:<line>  session=<id>` まで出るので、`less +<line> <path>` で前後文脈を直接読める / `claude --resume <session>` で worktree がまだ残っていればセッション再開できる。

### `clog-resume` — session id 1 つで cd + resume

`clog` の出力からコピペした session id を渡すと、jsonl から元の cwd を自動解決して `cd <cwd> && claude --resume <id>` を 1 ステップで実行する zsh 関数（`home/.zshrc.d/clog.zsh` に同梱）。

```bash
clog-resume eb697d30-9327-438d-825a-3a6b50b3d3d2                 # cd + resume
clog-resume eb697d30-9327-438d-825a-3a6b50b3d3d2 --fork-session  # 元 session を温存してフォーク再開
CLOG_RESUME_CMD=echo clog-resume <session-id>                    # ドライラン (claude を起動せず cwd 解決だけ確認)
```

`claude --resume` は **session の cwd と一致するディレクトリから呼ぶ必要がある**（Claude Code は cwd を encode した `~/.claude/projects/<encoded-cwd>/` から候補 session を探す）。`clog-resume` はその cwd 解決を `python3` で jsonl 先頭から `"cwd"` キーを持つ最初の行を拾うことで自動化している。

cwd の worktree が消えていた場合は明示的にエラーを出し、`git worktree add <path> <branch>` で復元するか jsonl を別 cwd の encoded ディレクトリに移植するヒントを表示する（公式サポートではないが構造上動く救済パス）。

### ヘルプ

`clog -h` / `clog --help` で 自前 usage（worktree 探しの観点でのユースケース）+ argparse 詳細フラグの両方を表示する。`clog-resume -h` / `clog-resume --help` で resume 関数の usage・ドライラン方法・うろ覚え session id 時の `clog` 連携を表示する。

### ノイズ抑制ルール

何も考えずに jsonl を grep するとコマンドエコー (`/push` 等が user メッセージとして注入される)・`<system-reminder>` 自動付与・`toolUseResult` の生 JSON で結果が埋まり、自分の発話と assistant の地の文が埋もれる。`scripts/claude-session-search.py` は以下を **既定で除外**:

- `type` が `user` / `assistant` 以外（`attachment` / `file-history-snapshot` / `permission-mode` 等）
- `toolUseResult` キーを持つ行（ツール出力の引き戻し）
- `isMeta=true` の行（command 説明文の auto-attach）
- 本文が `<command-…>` / `<local-command…>` / `<system-reminder…>` / `<bash-stdout…>` / `Caveat: The messages below were generated by the user while running local commands` で始まる行

この除外を**実発話だけに絞る前提のドメイン知識**として `SKIP_PREFIXES` に列挙してある。新しい自動注入 prefix を見つけたら同配列に追加すること。

### 設計上のポイント

- **ripgrep ではなく Python 単体**: jsonl の各行を `json.loads` で parse して `message.content` の text part だけを抽出する都合上、ripgrep の前段 filter は機械的に効きづらい。302MB 全 scan でも数秒で終わるので Python だけで完結
- **`CLAUDE_PROJECTS_DIR`** 環境変数で参照先ディレクトリを上書き可能（別 Mac の Claude transcripts を持ち込んだ時用、通常は不要）
- **`<system-reminder>` を取り逃す可能性**: 本文の途中で `<system-reminder>` が始まるケース（assistant のコードブロック中の例示等）はマッチ対象に残る。先頭一致でしか除外していないため意図せず混じることがあるが、preview を見れば人間には判別できる
- **`-g` (group) は cwd の `Counter` を sort して出すだけ**: 「自分が CRA を触ったのは fileToImaeda 系の worktree だった」のような探し物にはこのモードがいちばん速い

### 新規 snippet 追加時の `homeshick link` 競合への対応

`~/.zshrc.d/` は実ディレクトリで個別 symlink 運用。`homeshick link castle` は `.gitconfig` 等の競合で途中停止すると新規追加 snippet にたどり着かない（このリポジトリで実観測）。停止した場合は手動で個別 symlink を貼る:

```bash
ln -s ../.homesick/repos/castle/home/.zshrc.d/clog.zsh ~/.zshrc.d/clog.zsh
```

(snippet 追加直後の既存 zsh セッションへの反映は「[`~/.zshrc.d/` の auto-source と新規 snippet 追加時の落とし穴](#zshrcd-の-auto-source-と新規-snippet-追加時の落とし穴)」を参照)

## スキル管理

- Claude用スキルは `claude/skills/<skill-name>/SKILL.md` で管理する

## Neovim設定

- パッケージマネージャ: lazy.nvim
- 設定エントリ: `config/nvim/init.lua`
- プラグイン: `config/nvim/lua/plugins/`
- 基本設定: `config/nvim/lua/config/` (options, keymaps, autocmds)

## シェル設定

zsh使用。主要ツール:
- anyenv（各種言語バージョン管理）
- starship（プロンプト）
- zoxide（ディレクトリジャンプ、`j`コマンド）
- fzf + ghq（リポジトリ選択、`Ctrl+]`）

### `~/.zshrc.d/` の auto-source と新規 snippet 追加時の落とし穴

`home/.zshrc` の末尾近くに以下のループがあり、起動時に `~/.zshrc.d/*.zsh` を全て source する（glob qualifier `(N)` = NULL_GLOB なので、マッチしなければ silent skip）:

```zsh
if [[ -d ~/.zshrc.d ]]; then
  for _f in ~/.zshrc.d/*.zsh(N); do
    source $_f
  done
fi
```

**落とし穴**: zsh は起動時に rc を **1 度だけ** source する。castle 側に新しい snippet (`home/.zshrc.d/<x>.zsh`) を追加して `homeshick link castle` で symlink を貼っても、**既に起動している zsh プロセスには反映されない**。Ghostty + tmux の session group 方式（[ターミナル / マルチプレクサ](#ターミナル--マルチプレクサ) 参照）下では tmux session が生きている限り中の zsh プロセスも生き続けるため、長期セッションだとこのドリフトが蓄積する。

典型的な症状:

```bash
$ which apauto
apauto not found     # ← snippet 追加前に起動した古い zsh では関数が読まれていない
```

**新規 snippet を追加 / 更新した直後の反映**:

```bash
# 関数定義の追加なら、既存セッションでも source だけで十分
source ~/.zshrc.d/<新スニペット>.zsh

# alias の再定義や PATH の差し戻しなど rc 全体を読み直したい場合
exec zsh

# tmux 内で複数 pane に居る場合は各 pane で個別に上記を実行
# (もしくは新規 Ghostty タブを開いて新規 ghostty-<pid> セッションを作る)
```

`(N)` qualifier の挙動上、symlink が無いときはエラーにならず silent skip なので、症状が「コマンドが存在しない」だけになって原因に気付きにくい。新規 snippet を足したら `exec zsh` を癖にすると安全。

## ターミナル / マルチプレクサ

- **Ghostty**（ターミナル）と **tmux**（マルチプレクサ）を組み合わせ。Ghostty はキー入力・表示・タブ管理に専念し、ペイン分割/移動/リサイズ/コピーモードは tmux 側に集約
- `home/.tmux.conf` で Ghostty 互換キー (`Ctrl+;` 分割 / `Ctrl+h/j/k/l` 移動 / `Ctrl+Shift+...` リサイズ / `Ctrl+Shift+x` copy mode) を `bind -n` で再現
- `home/.zshrc` の "Ghostty: auto-attach tmux" ブロックで **session group 方式**を採用: 1 タブ目は `main` セッション作成、2 タブ目以降は `ghostty-<pid>` として join — タブを増やしても session が雪だるま化しない
- 詳細・キーマッピング表・移行時の罠（`'C-\;'` シングルクォート / `=main` zsh EQUALS 展開）は [`docs/tmux-setup.md`](docs/tmux-setup.md)
- Claude Code の `teammateMode=tmux` が window-scope に書き残す pane-border override（タイトル・片側オレンジ境界）の自動クリーンアップは下記「[Claude Code TeamCreate の tmux 残骸クリーンアップ](#claude-code-teamcreate-の-tmux-残骸クリーンアップ)」を参照

## Claude Code TeamCreate の tmux 残骸クリーンアップ

Claude Code の `teammateMode = "tmux"`（`~/.claude/settings.json`）で TeamCreate を使うと、サブエージェント割り当て先 tmux ペインに **window-scope の override** が書き込まれる: `pane-border-status top` (タイトル表示) と `pane-active-border-style fg=colour208` (オレンジ)。TeamDelete でもメインエージェント終了でもこの override は巻き戻されず、castle グローバル設定 (`pane-border-status off` / グレー) を覆い隠したまま「分割線・タイトル・片側オレンジ境界」が居座る。

`pane-border-indicators = colour` モード（castle / tmux デフォルト）下では active-border-style 色が **境界線の半分のみ**描画されるため、「タイトル + 片側だけオレンジ」という独特の見た目になるのが特徴。

### 自動クリーンアップ

`scripts/tmux-clear-pane-border-overrides.sh` が全 window から `pane-border-status` / `pane-border-style` / `pane-active-border-style` / `pane-border-format` / `pane-border-indicators` の window-scope override を `set-option -uw` で unset し、上位（server-global = castle `home/.tmux.conf`）にフォールバックさせる。

`~/.claude/settings.json` の `hooks` で **`Stop` と `SubagentStop`** に配線され、エージェント停止イベント毎に上記スクリプトが発火する。

#### マシン間同期: nix-darwin home.activation で自動 jq merge

`settings.json` は `extraKnownMarketplaces` の絶対パスや `enabledPlugins` などマシン固有値を含む machine-local ファイル（castle `.gitignore` で除外）なので丸ごと symlink できない。代わりに **`config/nix-darwin/home.nix` の `home.activation.patchClaudeHooks`** が `.hooks` キーだけを jq で部分上書きする（[Phase 4](#phase-4-mcp-api-キーを-op-経由で隠匿する) の `patchClaudeMcpPerplexity` と同じ思想）。

```bash
darwin-rebuild switch --flake ~/.config/nix-darwin
# → ~/.claude/settings.json の .hooks が castle 起源の値に揃う
# → Claude Code 再起動で反映
```

真実の源は `home.nix` の `desired=$(jq -n ...)` ブロック（hooks を増減したければここを編集）。Claude Code CLI 起動中は `pgrep -x claude` で skip + 警告を出し、settings.json の競合を防ぐ。既に同値なら no-op で再実行コストはほぼゼロ。

新規 Mac でも `homeshick link castle && darwin-rebuild switch` だけで hooks が反映されるため、手動セットアップ手順は不要。nix-darwin 未適用環境で手動同期したい場合のみ `jq` で local 編集 ([Phase 4](#phase-4-mcp-api-キーを-op-経由で隠匿する) の jq パターン参照)。

### 手動エスケープハッチ: `tmuxreset`

`home/.zshrc.d/tmuxreset.zsh` が同名 zsh 関数を提供する。hook が発火する前に視覚的に消したい時、hook が何らかの理由で動いていない時、あるいは別ツールが同じ override を残した時に叩く:

```bash
tmuxreset   # 全 window から pane-border 系 override を削除
```

### ポイント

- **`set -uw` の `-u`** が "unset" で、`-w` が window-scope を指定する。tmux のオプションは server / session / window の 3 階層で**下位がより限定的**。window-level の override を unset すれば自動的に上位 (castle グローバル) にフォールバックする
- **`pane-active-border-style` を unset し忘れない**: `pane-border-style` (非アクティブ側) と `pane-active-border-style` (アクティブ側) は別系統。前者だけ unset すると「片側オレンジ」が残る (実装時に踏んだ罠)
- **tmux 未起動環境では silent exit**: Stop hook は CI / non-tmux session でも発火し得るので、`command -v tmux` と `tmux info` の双方でガード

## テーマ運用ルール（Light/Dark = 0.5pt 差 + Dark = warm-lifted layered gray）

castle が配布する Light/Dark ペアテーマには **「Dark のフォントサイズを Light よりちょうど 0.5pt 大きく取る」** という共通契約を置く。アプリ横断で揃えることで、OS の appearance 切替時に「色だけでなくフォントサイズも自動でついてくる」体験を作る。

### ルール

- **Light が基準（小さい側）/ Dark がそれより +0.5pt（大きい側）**
- 既存配布物の対応:
  | アプリ | Light | Dark | 実現方式 |
  |---|---|---|---|
  | Xcode | 13pt (`ClaudeDay.xccolortheme`) | 13.5pt (`ClaudeDayDark.xccolortheme`) | テーマファイル内に font-size を直接定義 (`config/nix-darwin/files/xcode/`) |
  | Ghostty | 13pt | 13.5pt | Hammerspoon hook 経由 (`hammerspoon/init.lua` が `~/.config/ghostty/config.local` を appearance に応じて書き換え) |
  | markdownobserver | アプリ本体決定 | アプリ本体決定 | 適用外 (`user.css` に絶対値 font-size を持たない設計、`@media (prefers-color-scheme: dark)` 内に font override 無し) |
- 例外を作る場合（特定アプリの仕様で 0.5pt 差が破綻する等）は、該当テーマファイルのヘッダコメントに **理由を明記** してから外す

### 根拠（Why）

- 暗背景は明背景に比べてコントラスト感が低く、**同じ pt でも筆画が細く感じる**。Dark を持ち上げることで Light と視覚的な「重み」を揃え、テーマ切替時に脳が疲れない
- 当初は +1pt 差を採用していた (Light 13pt / Dark 14pt) が、appearance 切替時の「ガクッと大きさが変わる」違和感が強かったため、**+0.5pt の中庸に倒した** (2026-05 方針転換)。Dark の "重みを持ち上げる" 効果は維持しつつ、切替時の不連続感は緩和する妥協点
- 0.5pt 差を成立させるため Ghostty 側 (`hammerspoon/init.lua`) の `string.format` を `%d` → `%g` に変更している (整数フォーマットだと浮動小数を渡したときに "bad argument" になるため)

### Dark = warm-lifted layered gray（背景階層）

Light/Dark の 0.5pt 差ルールと独立して、**Dark テーマ側は背景を単色の純黒に倒さず、warm-leaning な多階層 gray で構成する**という共通契約を置く。Light 側の ivory `#FAF9F5`（純白ではなく暖色寄り）と対称な「warm dark」を維持し、editor / terminal / Markdown reader の 3 サーフェイスで同じ vocabulary を共有する。

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

### Ghostty の制約と Hammerspoon hook 方式

Ghostty 公式 docs では「A theme can set any valid configuration option」と書かれているが、**実装上は theme file 内の `font-size` などフォント系オプションは silently ignored** される（`+show-config | grep font-size` を Light/Dark 両モードで実行すると、本体 config の値しか返らないことで検証可能）。これは glyph atlas の再構築コストを避けるための暗黙仕様と推定される。

そのため castle では **Hammerspoon を appearance watcher として用いる方式**を採用:

1. 本体 `config/ghostty/config` 末尾に `config-file = ?config.local` (optional include) を置く
2. `hammerspoon/init.lua` が `AppleInterfaceThemeChangedNotification` を `hs.distributednotifications` で購読
3. appearance 変更を検知したら `~/.config/ghostty/config.local` を `font-size = 13` (Light) / `font-size = 13.5` (Dark) だけ含む最小ファイルとして上書き
4. 続けて Ghostty の **メニューバー → Reload Configuration を `hs.application:selectMenuItem` で自動 click** （Ghostty 未起動なら best-effort で skip）。これにより config.local の値が即座に Ghostty 内部の "current config" に取り込まれる
5. Hammerspoon 起動時 (cold start / `hs.reload()`) にも 1 度同期して cold start でも正しい値に揃える

`config.local` は **gitignored** (`.gitignore` 末尾に登録) の machine-local 動的ファイル。Hammerspoon が起動していない別 Mac でも `?` (optional include) のおかげで Ghostty config は壊れない (font-size は本体 config の fallback = 13pt にフォールバックする)。

### Ghostty 側の反映の挙動

| 設定カテゴリ | 既存ウィンドウ | 新ウィンドウ |
|---|---|---|
| color / palette / keybinding | ✓ 即時反映 | ✓ 反映 |
| **font-size** | ✓ 即時反映 (Hammerspoon が Reload Configuration を自動発火するため) | ✓ 反映 |

実機確認 (2026-05) で、Hammerspoon が `selectMenuItem` で発火する Reload Configuration により **既存ウィンドウの色も font-size も即時反映** される。`auto-update-channel = tip` を採用している castle の Ghostty では、font 系設定も live reload に追従する挙動になっている。

ただし **reload 発火は必須**: `config.local` を書き換えただけでは Ghostty は再読込しない。Hammerspoon の `selectMenuItem` が menu click を自動化することでこのループを閉じている。Hammerspoon に **Accessibility 権限が必要** (System Settings → Privacy & Security → Accessibility) で、無いと selectMenuItem が silently fail する。

#### Accessibility 権限の自己チェック（新 Mac セットアップ時の safeguard）

`hammerspoon/init.lua` の冒頭で `hs.accessibilityState()` を呼び、権限が無ければ次の 2 経路で自己申告する:

1. **通知センター**: 「Hammerspoon: Accessibility 権限が必要」というタイトルの通知を `autoWithdraw = false` で滞留させる
2. **画面中央アラート**: `hs.alert.show` で 10 秒表示。通知センターを見ない癖の人にも届く

新 Mac で `homeshick link castle` 直後に Hammerspoon を起動すると、この通知が出る → ユーザーは System Settings → Privacy & Security → Accessibility で Hammerspoon を許可 → Hammerspoon メニュー → Reload Config で反映、というフローになる。

> ドキュメントに「権限が必要」と書くだけだと「ドキュメントを読まずに動かない → 原因不明」になりがち。実装が自己診断するほうが届く範囲が広い。

### Hammerspoon による時刻ベース appearance 自動切替

macOS 純正の「自動」appearance は日の出 / 日の入り固定で時刻指定ができないため、Hammerspoon 側で時刻トリガーを持ち OS appearance を切り替えている。切替に伴って `AppleInterfaceThemeChangedNotification` が飛び、上記の Ghostty `config.local` 書換えが自動追従する（= 時刻層と font-size 層を疎結合にしている）。

- 既定スケジュール: **07:00 に Light / 14:00 に Dark**（境界は `hammerspoon/init.lua` の `APPEARANCE_LIGHT_HOUR` / `APPEARANCE_DARK_HOUR`）
- cold start（Hammerspoon 起動 / `hs.reload()` / 再ログイン）時にも、現在時刻に対する期待状態へ強制同期する（= 手動 override より時刻ルールを優先する設計判断）
- 必須権限: `hs.osascript.applescript` で System Events を呼ぶため **Automation 権限**（System Settings → Privacy & Security → Automation → Hammerspoon → System Events を ON）が必要。Accessibility 権限とは別枠で、初回実行時に macOS のダイアログが出る

#### 一時 OFF 運用（`apauto` コマンド / flag file）

「今日はずっと Dark で作業したい」「プレゼン中なので勝手に切り替わってほしくない」など、時刻ベースの自動切替を一時的に止めたい場合は `apauto` zsh 関数（`home/.zshrc.d/apauto.zsh`）を使う:

```bash
apauto off       # 時刻トリガー & cold-start 同期を停止 (Hammerspoon 自動 reload)
apauto on        # ON に戻す
apauto toggle    # ON/OFF を反転
apauto status    # 現在の状態を表示 (引数なしと同じ)
apauto help      # 使い方を表示
```

内部的には `~/.hammerspoon/appearance-auto.disabled` という flag file の作成/削除と `hs -c 'hs.reload()'` の自動発火をまとめている。`hs` CLI が無い環境では flag だけ書き換えて警告を出すので、Hammerspoon メニュー → Reload Configuration で手動反映すれば良い。

flag が存在する間は `hammerspoon/init.lua` の `isAppearanceAutoDisabled()` が true を返し、各 timer コールバックと `applyExpectedAppearance()`（cold-start 同期）が早期 return する。cold start 時には `hs.alert` で `⏸ appearance auto-switch is OFF` を 4 秒表示し、OFF 中であることを自己申告する（黙って効かなくなる事故を防ぐため）。

zsh が無い環境（CI / 一時 sh / 他シェル）から直接叩きたい場合は flag ファイルを直接操作することもできる:

```bash
touch ~/.hammerspoon/appearance-auto.disabled   # OFF
rm    ~/.hammerspoon/appearance-auto.disabled   # ON
hs -c 'hs.reload()'                             # 即時反映 (任意)
```

#### 設計上のポイント

- **Ghostty font-size 連動は止めない**: flag は時刻トリガーだけを無効化し、`AppleInterfaceThemeChangedNotification` の購読は生かす。OFF 中でも手動で OS appearance を切り替えれば font-size はそのまま追従する（= "手動操作の体験は壊さない"）
- **machine-local 扱い**: `~/.hammerspoon` は homeshick の symlink 越しに `castle/hammerspoon/` を指すため flag は castle 配下に着地するが、`.gitignore` で `hammerspoon/*.disabled` を無視して追跡しない（[`config/ghostty/config.local`](config/ghostty/config.local) と同じ machine-local override パターン）
- **永続 OFF にしたい場合は flag を残したまま運用**: reload や macOS 再ログインも貫通する。`rm` するまで OFF
- **常時 OFF にしたいわけではなく "境界時刻を変えたい" だけなら**, `hammerspoon/init.lua` の `APPEARANCE_LIGHT_HOUR` / `APPEARANCE_DARK_HOUR` を直接書き換えるほうが筋が良い（flag は "一時退避" 用、定数は "通常運用の境界" を担う）

### 新規テーマを追加するときの指針（How to apply）

- Xcode 系のように **theme file で font-size が effective なアプリ**は、Light/Dark 両方の theme file 内に直接 `font-size` を明示する (self-contained な定義)
- Ghostty のように **theme file で font-size が ignored なアプリ**は、Hammerspoon hook 側に分岐を追加するか、castle 側で `config-file` の optional include 機構を仕掛ける
- フォントサイズを 1pt 変えるときは **大きいサイズから降順で置換** すること。`13→14, 14→15` の順で実行すると元 13 のものが二重シフトされて 15 になる事故が起きる (Xcode テーマ作成時に踏んだ罠)
- 本体 config に `font-size` を残す場合は **Dark と同値 (13.5pt)** にして、override 未適用時に小さい側に倒れない設計にする (= 戸惑わせない方の挙動にフォールバック)

## homeshick操作

```bash
# castleディレクトリに移動
cd ~/.homesick/repos/castle

# シンボリックリンク作成
homeshick link castle

# ステータスライン設定を settings.json に適用（初回 or 設定変更時）
scripts/setup-claude-statusline.sh

# 変更をプッシュ（Claude Codeから）
/castle
```

## nix-darwin / Home Manager

`config/nix-darwin/` に nix-darwin + Home Manager + Homebrew(宣言) の構成を集約。
詳細は `config/nix-darwin/README.md`。

```bash
# 初回適用（Nix インストール後）
scripts/bootstrap-nix-darwin.sh

# 日常運用
darwin-rebuild switch --flake ~/.config/nix-darwin
```

方針:
- CLI = Nix (`home.nix` の `home.packages`) / GUI = Homebrew (`darwin.nix` の `homebrew.casks`)
- 既存 dotfiles は homeshick 管理を維持し、HM の `programs.<tool>` は有効化しない
- Homebrew は `cleanup = "none"` で安全側起動（取り込み完了後に `"zap"` 化を検討）

## 1Password CLI シェル統合（Phase 2: secrets management）

`home/.zshrc.d/op.zsh` に 1Password CLI (`op`) のシェル統合スクリプトを集約。`~/.zshrc.d/*.zsh(N)` ループで自動 source される（`home/.zshrc`）。

### 提供ヘルパ

- `op-status` — `op whoami` のラッパ。lock 状態なら non-zero を返してヒント文を出す
- `oprun [--env-file=<path>] -- <command...>` — `op run --env-file=<path> --no-masking -- <command>` のショートカット。env-file は省略時 `./.env.op`（Phase 3 の `.env` テンプレ運用で使う規約 → [`docs/op-env-pattern.md`](docs/op-env-pattern.md)）
- `op-warm-mcp` — `~/.config/op/*.env` を `op run -- bash -c '...'` で resolve し `/tmp/op-mcp-<basename>` に書き出す（mode 0600）。Ghostty 起動時に `home/.zshrc` から自動呼び出し。`~/.claude.json` の MCP `--env-file=` を `/tmp/op-mcp-...` に向け直しておけば、tmux ペイン分割時の per-pane Touch ID を回避できる（詳細: [`docs/op-touchid-investigation.md`](docs/op-touchid-investigation.md)、セットアップ: `scripts/setup-claude-mcp-perplexity.sh`）

### Shell Plugins（`gh`, `aws` 等）

`op plugin init <cli>` を 1 度実行すると `~/.config/op/plugins.sh` に alias が追記される。`op.zsh` はこのファイルが存在すれば source する。

```bash
# 例: gh を Personal Access Token を介さず 1Password 経由で動かす
op plugin init gh   # 対話で 1Password 内のアイテムを選ぶ
exec zsh            # plugins.sh が読まれる
which gh            # → op plugin run -- gh ... に置き換わる alias になっている
```

`op plugin init` は対話プロセスのため自動化できない。各 CLI を 1Password 化したくなったタイミングで個別に実行する。

### 設計上のポイント

- **シェル起動時に `op read` でシークレットをキャッシュしない**: 起動遅延・非対話 shell でのプロンプト・監査ログ希薄化を避けるため、必要時に `op run` / `op plugin run` で都度注入する
- **`OP_ACCOUNT` の machine-local 切り替え**: 個人 / 仕事 Mac でアカウントを変えたい場合は `~/.zshrc.local` に `export OP_ACCOUNT=<short_name>` を書く（castle 共通設定からは分離）。仕事 Mac での具体的な差分手順は [`docs/work-mac-setup.md`](docs/work-mac-setup.md) を参照
- **`op` 未インストール環境では早期 return**: 仕事 Mac の bootstrap 中など、op CLI が無くても zsh 起動が壊れない

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. 1Password 8 を起動 → Settings → Developer → **Integrate with 1Password CLI** を ON（Touch ID で `op` を unlock するために必須）
2. `homeshick link castle` を実行。`~/.zshrc.d` の symlink が自動で作られない場合は手動で:
   ```bash
   if [ ! -e ~/.zshrc.d ]; then
     ln -s ~/.homesick/repos/castle/home/.zshrc.d ~/.zshrc.d
   fi
   ```
3. 動作確認（新規 zsh セッション or `exec zsh` 後）:
   ```bash
   op-status                   # → my.1password.com / <email> / <user id>
   op item list --vault Private | head
   ```
4. 必要な CLI のみ Shell Plugin 化（任意）:
   ```bash
   op plugin init gh           # 対話で 1Password アイテムを選択
   exec zsh                    # plugins.sh が source される
   ```

## Phase 3: プロジェクトの `.env` を `op://` で運用する

任意のプロジェクト（Web app / CLI / インフラ管理リポジトリ等）で API キーを扱うときに、生値を `.env` に書かず Phase 2 の `oprun` ヘルパ経由で 1Password から実行時注入する運用パターン。詳細・実例は [`docs/op-env-pattern.md`](docs/op-env-pattern.md) を参照。

castle 自体は対象外（castle に置くのは secrets を含まない dotfiles のみ）。castle 外のプロジェクトに採用する際の規約。

要点:

- `.env.op`（commit OK、`op://` URI のみ）と `.env.op.local`（gitignore、machine-local override）の 2 ファイル運用
- 対話 shell からは `oprun -- <cmd>`（env-file の既定値は `./.env.op`）
- npm scripts / Makefile / Docker 等 sh 経由のコンテキストでは **`op run --env-file=.env.op -- <cmd>` を直接書く**（`oprun` は zsh 関数のため、sh では未定義）
- 仕事 Mac で vault 名が違う場合は `.env.op.local` を作って `oprun --env-file=.env.op.local -- <cmd>` のように **明示的に切り替える**（透過 fallback は事故の温床なので採用しない）
- CI では Service Account Token (`OP_SERVICE_ACCOUNT_TOKEN`) で `op run` を回す

## Phase 4: MCP API キーを op:// 経由で隠匿する

Claude Code の `~/.claude.json` の `mcpServers.<name>.env.<KEY>` に**生 API キーを書かない**。代わりに `op run --env-file=…` でラップして起動し、env-file は `op://` URI のみを含める。

### 構成

- `config/op/<server>.env` — op:// URI を書くテンプレ（このリポジトリで追跡）
  - 例: `config/op/perplexity.env` → `PERPLEXITY_API_KEY=op://Private/Perplexity API/credential`
  - `.gitignore` で `config/op/*` は無視され、`!config/op/*.env` のみ例外で追跡
- `~/.claude.json` の `mcpServers.<name>` を `command: "op", args: ["run", "--env-file=…", "--", <orig command>...]` に書き換える
- 1Password 側に同名のアイテムを保管（個人 Mac は Private vault、仕事 Mac は別アカウントの vault）

### 初回セットアップ手順（新キーを op 化するとき）

> ⚠️ **`~/.config/op` は `0700` 必須**。group/other に read bit があると `op` 起動時に
> `permissions are too broad. Change its permissions to 700` で拒否される。
> nix-darwin 適用済み Mac では `home.activation.fixSensitiveConfigPermissions`
> （`config/nix-darwin/home.nix`）が `darwin-rebuild switch` 毎に自動で
> 0700 に揃えるため通常は意識不要。nix-darwin 未適用 / `homeshick link` 直後に
> 手動で sign-in したい場合のみ `chmod 700 ~/.config/op` を当てること。

1. 1Password で API Credential テンプレのアイテムを作成（例: `Private/Perplexity API/credential` フィールドに値を保管）
2. `op-status` で signin 状態を確認、`op item get "Perplexity API" --vault Private --fields credential --reveal` で値が引けることを確認
3. `~/.config/op/<server>.env`（castle 経由なら `config/op/<server>.env`）の `op://` URI が 1Password 側のアイテム名・フィールド名と一致しているか確認
4. **Claude Code（および Claude Desktop）を一旦終了**してから `~/.claude.json` を **jq で部分書き換え**（既存の他キーを潰さない）。Claude Code 稼働中だと last-writer-wins の競合で編集が消える可能性があるため:
   ```bash
   jq '.mcpServers.perplexity = {
     type: "stdio",
     command: "op",
     args: [
       "run",
       "--env-file=" + (env.HOME + "/.config/op/perplexity.env"),
       "--",
       "npx", "-y", "@perplexity-ai/mcp-server"
     ]
   }' ~/.claude.json > ~/.claude.json.tmp && mv ~/.claude.json.tmp ~/.claude.json
   ```
5. **Claude Code を再起動**（既存セッションは古い設定を保持しているため）
6. 動作確認: `claude mcp list` で `perplexity ✓ Connected` が出る + Perplexity ツールが応答する

### tmux で複数ペインを使う場合の追加セットアップ (per-pane Touch ID 回避)

1Password 8 は呼び出し元の **pty (= tmux ペイン) ごとに 10 分間の transient grant** を発行するため、上記そのままだと「ペインを分割して各ペインで `claude` を起動 → ペインの数だけ Touch ID」が発生する。castle の Nix tmux は adhoc 署名で「永続認可済みアプリ」リストにも乗らない（詳細: [`docs/op-touchid-investigation.md`](docs/op-touchid-investigation.md)）。

**対策 (A.2 ハイブリッド)**: ghostty 起動時に `op-warm-mcp` (Phase 2 ヘルパ) で `op://` を一度 resolve → `/tmp/op-mcp-perplexity.env` に literal 保存。`~/.claude.json` の `--env-file` をそこへ向け直すと、tmux 内のすべての `op run` が 1Password 呼び出しを skip する。

`~/.claude.json` の書換えは `darwin-rebuild switch` 時に **nix-darwin の `home.activation.patchClaudeMcpPerplexity` で自動適用**される（`config/nix-darwin/home.nix`）。Claude Code CLI 起動中は `pgrep -x claude` で検出して skip + 警告するので state file の競合は回避。例外時 (`~/.claude.json` 未存在 / perplexity 未設定 / 既に正しい) は静かに skip。

手動で実行したい場合（CI / 別 OS / 確認用）は同等の jq 操作を行うスクリプトが残っている:

```bash
# Claude Code を一旦終了してから:
bash ~/.homesick/repos/castle/scripts/setup-claude-mcp-perplexity.sh
# .mcpServers.perplexity.args の --env-file を /tmp/op-mcp-perplexity.env に書き換える
# Claude Code を起動し直す
```

**Trade-off**: secret が `/tmp/op-mcp-*.env` に 0600 で session 中存在する（OS 再起動でクリア）。鍵 rotate 時は `rm /tmp/op-mcp-*.env` してから ghostty 再起動で再 warm。

### ポイント

- **Claude Code 自体は op:// を解釈しない**: `command` 階層で `op run` を噛ませることで、Claude Code には透過に見せる
- **env-file は 1 行 = 1 環境変数**: `KEY=op://...` のみ。複数 MCP サーバを共用にしたい場合でも、サーバごとにファイルを分けると依存関係を局所化できる
- **`--no-masking` は付けない**: Phase 2 の `oprun` ヘルパとは違い、MCP サーバの stdio に対して masking を切る必要は無い（むしろ stderr の意図しない出力が機密扱いになるリスクを減らす）
- **Resolved file (`/tmp/op-mcp-*.env`) も "1 行 = `KEY=literal-value`" の env-file 形式**: `op run` は op:// が無い行を素通しするので、warm 済みファイルへの再アクセスは 1Password を呼ばない（実測 0.05s, silent）

## Phase 5: ASC API キー (`.p8`) を 1Password 経由で配信時のみ展開する

iOS / macOS アプリを TestFlight / App Store に配信する `xcrun altool --upload-app` 用の API キー（`AuthKey_<KEY_ID>.p8` ＋ Key ID ＋ Issuer ID ＋ Team ID）を 1Password に集約し、配信時だけディスクに展開する運用。詳細・フィールド規約・トラブルシュートは [`docs/asc-api-key-op.md`](docs/asc-api-key-op.md) を参照。

### 構成

- `scripts/asc-upload.sh` — `op read` で `.p8` を `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` に一時展開し、`xcrun altool --upload-app` を呼び、EXIT トラップで削除（`umask 077` のサブシェル内で 0600 生成、`trap EXIT INT TERM` で正常終了 / 中断 / 失敗のいずれでもクリーンアップ）
- `home/.zshrc.d/asc.zsh` — 対話 zsh から `asc-upload <ipa>` で呼ぶラッパ関数（中身はスクリプトを叩くだけ）
- 1Password 側: API Credential テンプレで `username = <KEY_ID>` / `credential = .p8` 全文 / `key id`・`issuer id`・`team id` をテキストフィールドに保管

### Phase 3 (`oprun`) との違い

`xcrun altool` は API キーの値を **環境変数からも `--apiKeyPath` のようなオプションからも受け取らず**、`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` という固定パスを scan する仕様。さらに `.p8` は PKCS#8 PEM（複数行・改行・引用符を含む）で dotenv パーサに乗らないため、[`docs/op-env-pattern.md`](docs/op-env-pattern.md) の `oprun --env-file=` 経路では扱えない。Phase 5 はこの 2 つの制約を受けて、**「短時間だけ実体ファイルを置いて、終わったら必ず消す」** という別経路を用意している。

### 環境変数による切替

| 変数 | 既定値 | 用途 |
|---|---|---|
| `ASC_OP_ITEM` | `App Store Connect API Key` | 複数アプリ / 複数 Apple ID で鍵を分ける場合に item 名を切替 |
| `ASC_OP_VAULT` | `Private` | 仕事 Mac で別 vault を使う場合（[`docs/op-env-pattern.md` の machine-local override](docs/op-env-pattern.md) と同じ思想） |

### ポイント

- **`.p8` を永続化しない**: ローカル `~/.appstoreconnect/private_keys/AuthKey_*.p8` は配信実行中の数十秒〜数分のみ存在。永続バックアップは 1Password 側のみ
- **`scan-secrets.sh` の検出パターン**: ファイル名 `AuthKey_[A-Z0-9]{8,}\.p8` を追加して、`.p8` のパスをスクリプトに hardcode してしまった場合に commit 前に拾う。中身の PKCS#8 PEM は既存の `Private key block` パターン（`(RSA |OPENSSH |EC |PGP )?` の `?` で prefix 無しもマッチ）が拾う
- **CI での扱い**: 対話 Touch ID は使えないので、Phase 3 と同じく `OP_SERVICE_ACCOUNT_TOKEN` を環境変数に置く運用に切替（[`docs/op-env-pattern.md` の "CI で使う場合"](docs/op-env-pattern.md)）

## 機密情報の取り扱い（castle / Claude Code 共通ルール）

Phase 4 の副産物として、castle 配下と Claude Code 越しの作業全般に適用する運用ルール。

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

## SSH 設定（1Password agent 連携）

`config/ssh/config` に SSH client 設定本体を集約。`home/.config -> ../config` 経由で `~/.config/ssh/config` に自動 symlink される。

`~/.ssh/` には秘密鍵があり homeshick で扱わないため、`~/.ssh/config` は **machine-local** の最小ファイル（`Include ~/.config/ssh/config` の 1 行）として運用する。

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. `homeshick link castle` を実行（`config/ssh/config` が `~/.config/ssh/config` に symlink される）
2. **permissions を当てる**（git はディレクトリ mode を追跡せず、ファイルも新規 clone 後は 644 で展開されるため。nix-darwin 適用済み Mac では `home.activation.fixSensitiveConfigPermissions` が自動で当て直すので step 2 自体を skip して良い）:
   ```bash
   chmod 700 ~/.config/ssh
   chmod 600 ~/.config/ssh/config
   ```
3. `~/.ssh/config` を machine-local の Include stub として作成:
   ```bash
   printf 'Include ~/.config/ssh/config\n' > ~/.ssh/config
   chmod 600 ~/.ssh/config
   ```
4. 1Password 8 を起動 → Settings → Developer → **Use the SSH agent** を ON
5. 動作確認: `ssh -T git@github.com` で `Hi <username>! You've successfully authenticated...` が返ることを確認

### ポイント

- 1Password の SSH agent socket パス (`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`) は AgileBits Team ID に依存し、**個人/ビジネスを問わずアカウント横断で同一**。複数 Mac（個人 / 仕事）で同じ config が機能する
- `Host github.com` ブロックには `IdentityFile` を置かず、認証は 1Password agent 経由のみ（秘密鍵をディスクに置かない設計）
- **秘密鍵はディスクに置かない**。auth / signing 双方が `op-ssh-sign` + 1Password agent 経由で完結し、Touch ID で都度承認される。新規 Mac では「1Password 内で SSH 鍵を新規生成」もしくは「既存鍵を import 後にローカルファイルを退避（`mkdir -p -m 700 ~/.ssh-keys-backup && mv ~/.ssh/id_* ~/.ssh-keys-backup/`）→ `ssh -T git@github.com` と test commit で動作確認 → バックアップは緊急復旧用に保持」の流れで運用する

## Git 設定（commit signing 含む）

`home/.gitconfig` に共通の Git 設定（commit signing、diff/merge tool、`user.name`）を集約し、`~/.gitconfig` は `castle/home/.gitconfig` への symlink で運用する。

identity（`user.email` / `user.signingkey`）は **machine-local** の `~/.gitconfig.local` に分離し、`[include] path = ~/.gitconfig.local` 経由で読み込む。これにより個人 Mac と仕事 Mac で異なる identity を保持できる。

commit signing は **1Password SSH agent + `op-ssh-sign`** で行い、SSH 鍵そのもので commit を署名する（GPG 不要）。Touch ID で都度承認される。

> ⚠️ **新規 Mac で `homeshick link castle` 直後は `~/.gitconfig.local` が未作成**のため、`commit.gpgsign = true` が castle 側で有効でも署名ができず commit が失敗する（`error: gpg failed to sign the data`）。**castle 配下で commit する前に必ず以下の手順 1〜4 を完了**させてから commit すること（5・6 は GitHub 側 Verified バッジ用なので後回し可）。

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. `homeshick link castle` を実行。`~/.gitconfig` の symlink が自動で作られない場合は手動で:
   ```bash
   if [ ! -L ~/.gitconfig ]; then
     ln -s ~/.homesick/repos/castle/home/.gitconfig ~/.gitconfig
   fi
   ```
2. 1Password に SSH 鍵を import（既存鍵を import するか、1Password 内で新規生成）
3. machine-local identity ファイルを作成（`<...>` を実際の値に置換）:
   ```bash
   cat > ~/.gitconfig.local <<EOF
   [user]
   	email = <your email>
   	signingkey = key::<ssh public key, e.g. ssh-ed25519 AAAA...>
   EOF
   chmod 600 ~/.gitconfig.local
   ```
4. 自分の commit を verify するための allowed_signers を作成（`~/.config/git/` は homeshick 経由で生まれるが、castle 未使用の Mac でも動くよう `mkdir -p` で防御）:
   ```bash
   mkdir -p ~/.config/git && chmod 700 ~/.config/git
   echo "<your email> <ssh public key>" > ~/.config/git/allowed_signers
   chmod 600 ~/.config/git/allowed_signers
   ```
5. GitHub に同じ公開鍵を **signing key** として登録（authentication key とは別管理）。1Password のアイテム詳細から「公開鍵をコピー」してから次を実行:
   ```bash
   gh auth refresh -h github.com -s admin:ssh_signing_key   # 初回のみスコープ追加
   pbpaste > /tmp/op-pubkey.pub                             # クリップボードからファイル化
   gh ssh-key add /tmp/op-pubkey.pub --title "<machine name> (1Password signing)" --type signing
   rm /tmp/op-pubkey.pub
   ```
6. 動作確認: 任意の git リポジトリで `git commit --allow-empty -m "test signing"` を実行。1Password の Touch ID プロンプトが出て、`git log --show-signature -1` に `Good "git" signature` が表示されれば成功

## Phase 8: 仕事 Mac での差分セットアップ

仕事 Mac は **別の 1Password アカウント / 別の GitHub identity / 別の SSH 鍵**を持つ前提。castle の追跡ファイルは編集せず、すべて machine-local（`~/.zshrc.local` / `~/.gitconfig.local` / `.env.op.local`）に差分を逃がす。`~/.config/op/<server>.env` は homeshick の dir symlink (`~/.config -> castle/home/.config`) 越しに **castle 配下の実ファイル** を指すので直接編集しない。

具体的なチェックリスト・差分マトリクス・トラブルシュートは [`docs/work-mac-setup.md`](docs/work-mac-setup.md) に集約。

要点:

- `op account add` で Employer アカウント追加 → `~/.zshrc.local` の `OP_ACCOUNT` を仕事用に固定（値は shorthand / sign-in address / UUID のいずれでも可。GUI integration 経由 sign-in は sign-in address が堅い）
- 仕事用 SSH 鍵は **1Password Employer vault 内で新規生成**（個人鍵は使い回さない）。authentication / signing 両方を仕事 GitHub アカウント側に登録
- `~/.gitconfig.local` を仕事 email + 仕事 signing key で作る。個人 / 仕事の repo を同一 Mac で扱うなら **`~/.gitconfig.local` 内** に `[includeIf "gitdir:..."]` を書いて directory ベース自動切替（git の include は include 先のファイル内でも再帰的に有効。`~/.gitconfig` は castle 共通設定への symlink なので絶対に書き込まない）
- MCP API キーは 1Password 側で **vault / item 名を仕事 / 個人で共通化**するのが推奨（castle 追跡ファイルを変えずに済む）。共通化できない場合のみ最終手段として `--assume-unchanged` で castle 配下を上書き（詳細は `docs/work-mac-setup.md`）
- castle 外プロジェクトでは Phase 3 の `.env.op.local`（[`docs/op-env-pattern.md`](docs/op-env-pattern.md)）で `op://Employer/...` を上書き

## Phase 9: `nru` で flake update を認証付き fetch にする

`nix flake update`（castle では `nru` エイリアス）の実行時、Nix は `api.github.com` を `NixOS/nixpkgs` / `LnL7/nix-darwin` / `nix-community/home-manager` の 3 input 分連続で叩く。匿名アクセスは IP 単位で 60 req/hr のレートリミットがあり、共有 IP では `HTTP error 403: API rate limit exceeded` で `using cached version` フォールバックに落ちる挙動になる。

これを回避するため、`op run` で 1Password から GitHub Public PAT を `op://` 解決して `GITHUB_TOKEN` に展開 → `NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"` 経由で Nix に注入する。認証ユーザーあたり 5000 req/hr へ引き上がる。

### 構成

- `home/.zshrc` の `nru` zsh 関数（旧 alias を関数に置換）— `~/.config/op/github.env.local`（machine-local override、gitignored）があればそれを優先、無ければ castle 追跡側の `~/.config/op/github.env` を使う。両方無い / `op` 未起動なら匿名 fetch にフォールバック
- `config/op/github.env` — castle 追跡テンプレ。`GITHUB_TOKEN=op://Private/GitHub Public PAT/credential`（個人 Mac default）
- `~/.config/op/github.env.local` — 仕事 Mac 等で `op://Employee/GitHub Public PAT/credential` のように上書き
- 1Password 側: API Credential テンプレで `<vault>/GitHub Public PAT/credential` フィールドに PAT を保管

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. **public github.com** で Fine-grained PAT を発行（個人 Mac なら個人アカウント、仕事 Mac なら仕事用個人アカウント。GHE 用 token は使えない）
   - Resource owner: 自分 / Expiration: 90 days / Repository access: "Public Repositories (read-only)" / Permissions: デフォルト
2. 1Password に保管:
   - Item template: **API Credential**
   - Item name: **`GitHub Public PAT`**（vault 横断で同じ名前に揃える）
   - `credential` フィールドに PAT
3. 個人 Mac の Private vault に保管した場合は追加設定不要（`config/op/github.env` がそのまま参照される）
4. 仕事 Mac で Employer 1Password の `Employee` vault などに置く場合は machine-local override を作成:
   ```bash
   cat > ~/.config/op/github.env.local <<'EOF'
   GITHUB_TOKEN=op://Employee/GitHub Public PAT/credential
   EOF
   chmod 600 ~/.config/op/github.env.local
   ```
5. 動作確認:
   ```bash
   op read 'op://Employee/GitHub Public PAT/credential' >/dev/null && echo OK
   nru   # 403 が出ずに lock 更新が走ること
   ```

### ポイント

- **Nix は `GITHUB_TOKEN` を直接読まない**: `NIX_CONFIG="access-tokens = github.com=..."` 経由で渡す必要がある。`nru` 関数の中で組み立てている
- **Fine-grained PAT を選ぶ**: Classic PAT より blast radius が小さい。Public read-only スコープなら漏洩時被害は最小限。Phase 5 の ASC API キー rotation と同じ思想で 90 日 expiration が無難
- **GHE 用 token は使えない**: `ghe.corp.yahoo.co.jp` 等の GHE で発行した PAT は `api.github.com` には通用しない（host が独立）。public github.com で個別に発行する必要がある
- **Touch ID は `nru` 実行毎に 1 回**: Phase 4 の MCP per-pane と違い対話 1 回限りなので許容範囲。常駐プロセスではないので warm-cache 戦略は採らない
- **匿名フォールバック**: `op` 未起動 / env-file 未設置の Mac でも `nru` は anonymous な `nix flake update` を実行する。fresh Mac で Phase 9 を未設定でもエラーにならない設計
