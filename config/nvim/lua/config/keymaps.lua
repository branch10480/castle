-- キーマップ設定

-- リーダーキーをSpaceに設定
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap.set

-- ノーマルモード

-- ウィンドウ移動
keymap("n", "<C-h>", "<C-w>h", { desc = "左のウィンドウに移動" })
keymap("n", "<C-j>", "<C-w>j", { desc = "下のウィンドウに移動" })
keymap("n", "<C-k>", "<C-w>k", { desc = "上のウィンドウに移動" })
keymap("n", "<C-l>", "<C-w>l", { desc = "右のウィンドウに移動" })

-- ウィンドウリサイズ
keymap("n", "<C-Up>", ":resize +2<CR>", { desc = "ウィンドウ高さを増やす" })
keymap("n", "<C-Down>", ":resize -2<CR>", { desc = "ウィンドウ高さを減らす" })
keymap("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "ウィンドウ幅を減らす" })
keymap("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "ウィンドウ幅を増やす" })

-- バッファ移動
keymap("n", "<S-h>", ":bprevious<CR>", { desc = "前のバッファ" })
keymap("n", "<S-l>", ":bnext<CR>", { desc = "次のバッファ" })

-- 検索ハイライトのクリア
keymap("n", "<Esc>", ":noh<CR>", { desc = "検索ハイライトをクリア" })

-- 行の移動（ビジュアルモード）
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "選択行を下に移動" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "選択行を上に移動" })

-- インデント調整（ビジュアルモード、選択を維持）
keymap("v", "<", "<gv", { desc = "インデントを減らす" })
keymap("v", ">", ">gv", { desc = "インデントを増やす" })

-- カーソル位置を維持してページスクロール
keymap("n", "<C-d>", "<C-d>zz", { desc = "半画面下にスクロール" })
keymap("n", "<C-u>", "<C-u>zz", { desc = "半画面上にスクロール" })

-- 検索時にカーソルを中央に
keymap("n", "n", "nzzzv", { desc = "次の検索結果" })
keymap("n", "N", "Nzzzv", { desc = "前の検索結果" })

-- ペースト時にヤンクレジスタを維持
keymap("x", "<leader>p", [["_dP]], { desc = "削除せずにペースト" })

-- システムクリップボードへヤンク
keymap({ "n", "v" }, "<leader>y", [["+y]], { desc = "システムクリップボードへコピー" })
keymap("n", "<leader>Y", [["+Y]], { desc = "行をシステムクリップボードへコピー" })

-- 削除時にレジスタを汚さない
keymap({ "n", "v" }, "<leader>d", [["_d]], { desc = "レジスタを汚さずに削除" })

-- 保存とクローズ
keymap("n", "<leader>w", ":w<CR>", { desc = "ファイルを保存" })
keymap("n", "<leader>q", ":q<CR>", { desc = "ウィンドウを閉じる" })
keymap("n", "<leader>x", ":wq<CR>", { desc = "保存して閉じる" })

-- 外部アプリケーション連携
-- Marked 2で現在のファイルを開く
local function open_in_marked()
	local filepath = vim.fn.expand("%")
	if filepath == "" then
		vim.notify("Marked 2で開くファイルがありません", vim.log.levels.WARN)
		return
	end

	if vim.bo.modified then
		vim.notify("ファイルに未保存の変更があります", vim.log.levels.WARN)
	end

	local fullpath = vim.fn.expand("%:p")
	local cmd = string.format('open -a "Marked 2" "%s"', fullpath)
	local result = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Marked 2を開けませんでした: " .. result, vim.log.levels.ERROR)
	else
		vim.notify("Marked 2で開きました: " .. vim.fn.fnamemodify(fullpath, ":t"), vim.log.levels.INFO)
	end
end

keymap("n", "<leader>m", open_in_marked, { desc = "Marked 2で開く" })
