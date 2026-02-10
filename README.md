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
- 自動ペア補完: nvim-autopairs
- 構文解析: nvim-treesitter（ハイライト・インデント・折りたたみ）
- スタートダッシュボード: dashboard-nvim
- LSP対応

### キーボード

- **Karabiner-Elements** - CapsLock→Control、日本語キーボードカスタマイズ
- **Hammerspoon** - `Ctrl+Space` でWezTermにフォーカス
- **BetterTouchTool** - カスタムジェスチャー

### Git

- **tig** - `K` で未ステージ差分をKaleidoscopeで表示

### Codex

- Codex用スキル本体は `codex/skills/` で管理
- リンク先は `~/.codex/skills/`（`home/.codex/skills/` をhomeshickで反映）

#### 同期コマンド

```bash
# homeshick用リンクを同期
scripts/sync-codex-skills.sh

# 現在の端末(~/.codex/skills)にも即時反映
scripts/sync-codex-skills.sh --local-codex

# homeshick配下へ初回適用（既存はスキップ）
homeshick -s -b link castle

# 既存リンクも含めて更新適用
homeshick -f -b link castle
```

#### Codexスキル作成（新規）

1. ディレクトリを作成する（例: `mkdir -p codex/skills/<skill-name>`）
2. `SKILL.md` を作成する（最低限 `name` と `description` をfrontmatterに含める）
3. `scripts/sync-codex-skills.sh` を実行する
4. 必要なら `scripts/sync-codex-skills.sh --local-codex` を実行する
5. 必要なら `homeshick -f -b link castle` を実行する

#### Codexスキル更新（既存）

1. `codex/skills/<skill-name>/SKILL.md` を編集する
2. `scripts/sync-codex-skills.sh` を実行する
3. 必要なら `scripts/sync-codex-skills.sh --local-codex` を実行する
4. 必要なら `homeshick -f -b link castle` を実行する
