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
│   └── .zshrc
├── config/         # ~/.config にリンクされる設定
│   ├── nvim/       # Neovim設定（lazy.nvim使用）
│   ├── wezterm/    # WezTermターミナル設定
│   ├── karabiner/  # Karabiner-Elements設定
│   ├── git/        # Gitグローバル設定
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
- 既存鍵の `IdentityFile` 行は phase 5（次フェーズ）で 1Password に鍵 import 後に削除し、agent 専用に切り替える
