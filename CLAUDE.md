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
│   └── git/        # Gitグローバル設定
├── claude/         # Claude Code用設定（~/.claude/にリンク）
│   ├── agents/     # カスタムエージェント定義
│   ├── commands/   # ユーザー呼び出し可能なコマンド
│   └── skills/     # Claude用スキル本体
├── codex/          # Codex用設定
│   └── skills/     # Codex用スキル本体
├── scripts/        # 運用スクリプト（Codexスキル同期など）
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

# 変更をプッシュ（Claude Codeから）
/castle
```
