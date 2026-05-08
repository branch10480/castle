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
│   ├── .zshrc      # zsh 起動スクリプト本体
│   └── .zshrc.d/   # 機能別 zsh snippet（op.zsh など）— ~/.zshrc から自動 source
├── config/         # ~/.config にリンクされる設定
│   ├── nvim/       # Neovim設定（lazy.nvim使用）
│   ├── wezterm/    # WezTermターミナル設定
│   ├── karabiner/  # Karabiner-Elements設定
│   ├── git/        # Git 関連設定（global ignore, allowed_signers (machine-local) ）
│   ├── nix-darwin/ # nix-darwin + Home Manager 構成（flake.nix / darwin.nix / home.nix）
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
- `oprun [--env-file=<path>] -- <command...>` — `op run --env-file=<path> --no-masking -- <command>` のショートカット。env-file は省略時 `./.env.op`（Phase 3 の `.env` テンプレ運用で使う規約）

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
- **`OP_ACCOUNT` の machine-local 切り替え**: 個人 / 仕事 Mac でアカウントを変えたい場合は `~/.zshrc.local` に `export OP_ACCOUNT=<short_name>` を書く（castle 共通設定からは分離）
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

## SSH 設定（1Password agent 連携）

`config/ssh/config` に SSH client 設定本体を集約。`home/.config -> ../config` 経由で `~/.config/ssh/config` に自動 symlink される。

`~/.ssh/` には秘密鍵があり homeshick で扱わないため、`~/.ssh/config` は **machine-local** の最小ファイル（`Include ~/.config/ssh/config` の 1 行）として運用する。

### 初回セットアップ手順（新規 Mac で 1 度だけ）

1. `homeshick link castle` を実行（`config/ssh/config` が `~/.config/ssh/config` に symlink される）
2. **permissions を当てる**（git は read/write bit を追跡しないため、新規 clone 後は 644 で展開される）:
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
