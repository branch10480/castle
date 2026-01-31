-- oil.nvim - ファイルをバッファのように編集できるファイルエクスプローラー

return {
	"stevearc/oil.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("oil").setup({
			-- カラムに表示する情報
			columns = {
				"icon",
				"permissions",
				"size",
				"mtime",
			},

			-- バッファローカルオプション
			buf_options = {
				buflisted = false,
				bufhidden = "hide",
			},

			-- ウィンドウローカルオプション
			win_options = {
				wrap = false,
				signcolumn = "no",
				cursorcolumn = false,
				foldcolumn = "0",
				spell = false,
				list = false,
				conceallevel = 3,
				concealcursor = "nvic",
			},

			-- 削除時にゴミ箱に送る（trash-cliが必要）
			delete_to_trash = true,

			-- 最後のoilバッファを閉じる時、編集中の変更をスキップ
			skip_confirm_for_simple_edits = false,

			-- oil内のファイル選択時のデフォルト動作
			default_file_explorer = true,

			-- `:Oil`実行時にフロートウィンドウで開く
			view_options = {
				-- 隠しファイルを表示
				show_hidden = true,
				-- 表示判定のカスタマイズ
				is_hidden_file = function(name, _)
					return vim.startswith(name, ".")
				end,
				-- 常に最初に表示するファイル/ディレクトリ
				is_always_hidden = function(name, _)
					return name == ".." or name == ".git"
				end,
				-- ソート順
				sort = {
					{ "type", "asc" },
					{ "name", "asc" },
				},
			},

			-- フロートウィンドウの設定
			float = {
				padding = 2,
				max_width = 100,
				max_height = 30,
				border = "rounded",
				win_options = {
					winblend = 0,
				},
			},

			-- プレビューウィンドウの設定
			preview = {
				max_width = 0.9,
				min_width = { 40, 0.4 },
				width = nil,
				max_height = 0.9,
				min_height = { 5, 0.1 },
				height = nil,
				border = "rounded",
				win_options = {
					winblend = 0,
				},
			},

			-- 確認ダイアログの設定
			progress = {
				max_width = 0.9,
				min_width = { 40, 0.4 },
				width = nil,
				max_height = { 10, 0.9 },
				min_height = { 5, 0.1 },
				height = nil,
				border = "rounded",
				minimized_border = "none",
				win_options = {
					winblend = 0,
				},
			},

			-- キーマップ
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = "actions.select",
				["<C-s>"] = "actions.select_vsplit",
				["<C-h>"] = "actions.select_split",
				["<C-t>"] = "actions.select_tab",
				["<C-p>"] = "actions.preview",
				["<C-c>"] = "actions.close",
				["<C-l>"] = "actions.refresh",
				["-"] = "actions.parent",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = "actions.tcd",
				["gs"] = "actions.change_sort",
				["gx"] = "actions.open_external",
				["g."] = "actions.toggle_hidden",
				["g\\"] = "actions.toggle_trash",
			},

			-- デフォルトのキーマップを使用
			use_default_keymaps = true,
		})

		-- グローバルキーマップ
		-- `-` で親ディレクトリを開く（vim-vinegar風）
		vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

		-- `<leader>o` でフロートウィンドウで開く
		vim.keymap.set("n", "<leader>o", function()
			require("oil").open_float()
		end, { desc = "Open Oil in float window" })

		-- `<leader>O` でカレントワーキングディレクトリを開く
		vim.keymap.set("n", "<leader>O", function()
			require("oil").open(vim.fn.getcwd())
		end, { desc = "Open Oil at cwd" })
	end,
}
