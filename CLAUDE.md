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

## ターミナル / マルチプレクサ

- **Ghostty**（ターミナル）と **tmux**（マルチプレクサ）を組み合わせ。Ghostty はキー入力・表示・タブ管理に専念し、ペイン分割/移動/リサイズ/コピーモードは tmux 側に集約
- `home/.tmux.conf` で Ghostty 互換キー (`Ctrl+;` 分割 / `Ctrl+h/j/k/l` 移動 / `Ctrl+Shift+...` リサイズ / `Ctrl+Shift+x` copy mode) を `bind -n` で再現
- `home/.zshrc` の "Ghostty: auto-attach tmux" ブロックで **session group 方式**を採用: 1 タブ目は `main` セッション作成、2 タブ目以降は `ghostty-<pid>` として join — タブを増やしても session が雪だるま化しない
- 詳細・キーマッピング表・移行時の罠（`'C-\;'` シングルクォート / `=main` zsh EQUALS 展開）は [`docs/tmux-setup.md`](docs/tmux-setup.md)

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
| GitHub PAT（gh の Shell Plugin 経由） | API Credential | `op://Private/GitHub PAT/token` |
| OpenAI / Anthropic 等の生 API キー | API Credential | `op://Private/<service>/credential` |
| SSH 秘密鍵 | SSH Key | （op-ssh-sign 経由で参照、URI 不要） |
| OAuth refresh token（Codex 等） | Login | `op://Private/<service>/refresh_token` |

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
