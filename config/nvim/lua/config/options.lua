-- 基本設定

-- True colorサポート
vim.opt.termguicolors = true

-- 行番号
vim.opt.number = true
vim.opt.relativenumber = true

-- インデント設定（既存の設定を保持）
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- 検索設定
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- UI設定
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- パフォーマンス
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500

-- エディタ動作
vim.opt.clipboard = "unnamed,unnamedplus"
vim.opt.mouse = "a"
vim.opt.undofile = true
vim.opt.backup = false
vim.opt.swapfile = false

-- 分割ウィンドウ
vim.opt.splitbelow = true
vim.opt.splitright = true

-- 補完メニュー
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.pumheight = 10
