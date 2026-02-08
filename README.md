# My Castle

macOS用dotfiles。[homeshick](https://github.com/andsens/homeshick)で管理。

## セットアップ

```bash
# homeshickのインストール
brew install homeshick

# リポジトリのクローン
homeshick clone git@github.com:branch10480/castle.git

# シンボリックリンクの作成
homeshick link castle
```

## 含まれる設定

### シェル (zsh)

- **starship** - カスタムプロンプト
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
- インデント自動検出: guess-indent.nvim
- UI改善: noice.nvim（コマンドライン・メッセージ・通知）
- LSP対応

### キーボード

- **Karabiner-Elements** - CapsLock→Control、日本語キーボードカスタマイズ
- **Hammerspoon** - `Ctrl+Space` でWezTermにフォーカス
- **BetterTouchTool** - カスタムジェスチャー

### Git

- **tig** - `K` で未ステージ差分をKaleidoscopeで表示

### Claude Code

- カスタムエージェント・スキル・コマンド (`claude/`)
