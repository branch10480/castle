# Neovim LSP 追加手順ガイド

Neovim 0.11+ / nvim-lspconfig 新API 対応

## 概要

LSPサーバーの追加方法は2パターンあります：

| パターン | 例 | インストール | 有効化 |
|---------|-----|-------------|-------|
| Mason経由 | lua_ls, pyright, ts_ls | `ensure_installed` | 自動 |
| システム付属 | sourcekit (Xcode) | 不要 | `vim.lsp.enable()` |

---

## プラグインの役割と非推奨API

### 各プラグインの役割

```
mason.nvim              ← LSPサーバーのインストール管理
    ↓
mason-lspconfig.nvim    ← MasonとLSPの連携、自動有効化
    ↓
nvim-lspconfig          ← サーバー定義（cmd, filetypes等）を提供
    ↓
vim.lsp.config()        ← Neovim組み込みAPI（設定のカスタマイズ）
vim.lsp.enable()        ← Neovim組み込みAPI（サーバーの有効化）
```

### nvim-lspconfig は非推奨？

**nvim-lspconfig プラグイン自体は非推奨ではない。引き続き必要。**

| | ステータス |
|---|----------|
| nvim-lspconfig プラグイン自体 | ✅ 非推奨ではない |
| `require('lspconfig').xxx.setup()` | ❌ 非推奨（古いAPI） |

### nvim-lspconfig が提供するもの

nvim-lspconfig は**サーバー定義ファイル**を提供：

```
nvim-lspconfig/lsp/
├── lua_ls.lua      ← lua_lsの基本設定（cmd, filetypes等）
├── pyright.lua     ← pyrightの基本設定
├── sourcekit.lua   ← sourcekitの基本設定
└── ...
```

`vim.lsp.config()` はこれらを**自動的に見つけて使用**する。

### nvim-lspconfig あり vs なし

| | nvim-lspconfig あり | nvim-lspconfig なし |
|---|-------------------|-------------------|
| 基本設定 | 自動で適用される | 全部自分で書く |
| カスタム設定 | 上書き部分だけ書く | 全部自分で書く |

**nvim-lspconfig あり（推奨）:**
```lua
-- 基本設定は自動適用、カスタムだけ書けばOK
vim.lsp.config("pyright", {
    settings = { python = { analysis = { typeCheckingMode = "basic" } } },
})
vim.lsp.enable("pyright")
```

**nvim-lspconfig なし:**
```lua
-- 全部自分で書く必要がある
vim.lsp.config("pyright", {
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "setup.py", ".git" },
    settings = { python = { analysis = { typeCheckingMode = "basic" } } },
})
vim.lsp.enable("pyright")
```

---

## パターン1: Mason経由でインストールするサーバー

ほとんどのLSPサーバーはこちら。

### 手順

**1. `ensure_installed` にサーバー名を追加**

```lua
-- ~/.config/nvim/lua/plugins/lsp.lua

opts = {
    ensure_installed = {
        "lua_ls",
        "pyright",     -- 追加
        "ts_ls",       -- 追加
        "rust_analyzer", -- 追加
    },
    automatic_enable = true,
},
```

**2. （オプション）カスタム設定が必要な場合**

```lua
vim.lsp.config("pyright", {
    settings = {
        python = {
            analysis = {
                typeCheckingMode = "basic",
            },
        },
    },
})
```

**3. Neovimを再起動**

サーバーが自動インストール＆有効化されます。

### サーバー名の調べ方

```vim
:Mason
```

またはGitHubで確認:
- https://github.com/williamboman/mason-lspconfig.nvim#available-lsp-servers

---

## パターン2: システム付属のサーバー

Xcodeに付属の `sourcekit-lsp` など、OSやツールに同梱されているサーバー。

### 手順

**1. `vim.lsp.config()` で設定を定義**

```lua
-- ~/.config/nvim/lua/plugins/lsp.lua の config = function() 内

vim.lsp.config("sourcekit", {
    cmd = { "sourcekit-lsp" },
    filetypes = { "swift", "objective-c", "objective-cpp" },
    root_markers = {
        "Package.swift",
        "*.xcodeproj",
        "*.xcworkspace",
        ".git",
    },
})
```

**2. `vim.lsp.enable()` で有効化**

```lua
vim.lsp.enable("sourcekit")
```

**3. Neovimを再起動**

---

## 設定オプション一覧

### vim.lsp.config() で使える主なオプション

```lua
vim.lsp.config("server_name", {
    -- コマンド（実行ファイルパス）
    cmd = { "language-server", "--stdio" },

    -- 対応するファイルタイプ
    filetypes = { "python", "pyrex" },

    -- プロジェクトルートを検出するマーカー
    root_markers = { "pyproject.toml", ".git" },

    -- サーバー固有の設定
    settings = {
        -- サーバーごとに異なる
    },

    -- 初期化オプション
    init_options = {
        -- サーバーごとに異なる
    },
})
```

---

## よく使うLSPサーバー例

### Mason経由

| 言語 | サーバー名 | 備考 |
|-----|-----------|------|
| Lua | `lua_ls` | Neovim設定用 |
| Python | `pyright` | 型チェック強力 |
| TypeScript/JS | `ts_ls` | 旧称 tsserver |
| Rust | `rust_analyzer` | |
| Go | `gopls` | |
| JSON | `jsonls` | |
| YAML | `yamlls` | |
| HTML | `html` | |
| CSS | `cssls` | |
| Tailwind | `tailwindcss` | |

### システム付属

| 言語 | サーバー名 | 付属元 |
|-----|-----------|-------|
| Swift/ObjC | `sourcekit` | Xcode |
| C/C++ | `clangd` | LLVM (Xcodeにも付属) |

---

## トラブルシューティング

### LSPが動かない場合

```vim
" LSPの状態確認
:LspInfo

" ログを確認
:LspLog

" サーバーが見つかるか確認
:!which sourcekit-lsp
```

### Mason関連

```vim
" Masonのインストール状況確認
:Mason

" サーバーの手動インストール
:MasonInstall pyright
```

---

## 設定ファイルの場所

```
~/.config/nvim/lua/plugins/lsp.lua
```

## 参考リンク

- nvim-lspconfig: https://github.com/neovim/nvim-lspconfig
- mason.nvim: https://github.com/williamboman/mason.nvim
- mason-lspconfig: https://github.com/williamboman/mason-lspconfig.nvim
- Neovim LSP ヘルプ: `:help lsp`
