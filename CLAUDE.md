# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

homeshickで管理されているdotfilesリポジトリ。macOS環境向けの設定ファイルを集約。

## リポジトリ構造

```
dotfiles/
├── home/           # ~ にシンボリックリンクされるファイル
│   ├── .config -> ../config
│   ├── .hammerspoon -> ../hammerspoon
│   ├── .zshrc
│   └── claude_agents -> ../claude_agents
├── config/         # ~/.config にリンクされる設定
│   ├── nvim/       # Neovim設定（lazy.nvim使用）
│   ├── wezterm/    # WezTermターミナル設定
│   ├── karabiner/  # Karabiner-Elements設定
│   └── git/        # Gitグローバル設定
├── claude/         # Claude Code用スキル・コマンド
│   ├── commands/   # ユーザー呼び出し可能なコマンド
│   └── skills/     # 自動呼び出しスキル
├── claude_agents/  # Claude Code用カスタムエージェント定義
└── hammerspoon/    # Hammerspoonマクロ
```

## 主要コマンド・スキル

- `/dotfiles [メッセージ]` - 変更をcommit & push
- `/push` - 汎用的なgit add, commit, push
- `/zama-parking` - イオンモール座間 駐車場空き状況確認

## Neovim設定

- パッケージマネージャ: lazy.nvim
- 設定エントリ: `config/nvim/init.lua`
- プラグイン: `config/nvim/lua/plugins/`
- 基本設定: `config/nvim/lua/config/` (options, keymaps, autocmds)

## シェル設定

zsh使用。主要ツール:
- anyenv（各種言語バージョン管理）
- powerline-shell（プロンプト）
- zoxide（ディレクトリジャンプ、`j`コマンド）
- fzf + ghq（リポジトリ選択、`Ctrl+]`）

## homeshick操作

```bash
# dotfilesディレクトリに移動
cd ~/.homesick/repos/dotfiles

# シンボリックリンク作成
homeshick link dotfiles

# 変更をプッシュ（Claude Codeから）
/dotfiles "コミットメッセージ"
```
