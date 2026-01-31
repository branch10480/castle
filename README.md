# My Castle

macOS用dotfiles。[homeshick](https://github.com/andsens/homeshick)で管理。

## セットアップ

```bash
# homeshickのインストール
brew install homeshick

# リポジトリのクローン
homeshick clone git@github.com:branch10480/castle.git

# シンボリックリンクの作成
homeshick link dotfiles
```

## 含まれる設定

### シェル (zsh)

- **powerline-shell** - カスタムプロンプト
- **anyenv** - 言語バージョン管理（pyenv, nodenv等）
- **zoxide** - スマートディレクトリジャンプ (`j` コマンド)
- **fzf + ghq** - リポジトリ選択 (`Ctrl+]`)
- **wtp + fzf** - ワークツリー選択 (`Ctrl+w`)

### ターミナル (WezTerm)

- カラースキーム: Kanagawa
- リーダーキー: `Ctrl+t`（tmux風操作）
- ペイン分割: `Leader + %` / `Leader + "`
- ペイン移動: `Leader + h/j/k/l`

### エディタ (Neovim)

- パッケージマネージャ: lazy.nvim
- ファイラー: oil.nvim
- ファジーファインダー: telescope.nvim
- LSP対応

### キーボード

- **Karabiner-Elements** - CapsLock→Control、日本語キーボードカスタマイズ
- **Hammerspoon** - `Ctrl+Space` でWezTermにフォーカス
- **BetterTouchTool** - カスタムジェスチャー

### Git

- **tig** - `K` で未ステージ差分をKaleidoscopeで表示

### Claude Code

- カスタムスキル・コマンド (`claude/`)
- カスタムエージェント定義 (`claude_agents/`)
