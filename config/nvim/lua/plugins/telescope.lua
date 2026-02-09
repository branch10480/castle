-- Telescope ファジーファインダー設定

return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
		},
	},
	cmd = "Telescope",
	keys = {
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "ファイル検索" },
		{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep検索" },
		{ "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "バッファ一覧" },
		{ "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "ヘルプタグ検索" },
		{ "<leader>fo", "<cmd>Telescope oldfiles<cr>", desc = "最近開いたファイル" },
		{ "<leader>fc", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "現在のバッファ内検索" },
		{ "<leader>fs", "<cmd>Telescope grep_string<cr>", desc = "カーソル下の単語を検索" },
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				-- レイアウト設定
				layout_strategy = "horizontal",
				layout_config = {
					horizontal = {
						preview_width = 0.55,
						results_width = 0.8,
					},
					width = 0.87,
					height = 0.80,
					preview_cutoff = 120,
				},

				-- プロンプト設定
				prompt_prefix = "🔍 ",
				selection_caret = "➤ ",
				path_display = { "truncate" },

				-- ソート設定
				sorting_strategy = "ascending",
				file_ignore_patterns = {
					"node_modules",
					".git/",
					"dist/",
					"build/",
					"target/",
					"%.lock",
				},

				-- キーマッピング
				mappings = {
					i = {
						["<C-j>"] = actions.move_selection_next,
						["<C-k>"] = actions.move_selection_previous,
						["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
						["<Esc>"] = actions.close,
					},
					n = {
						["q"] = actions.close,
						["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
					},
				},
			},
			pickers = {
				find_files = {
					hidden = true,
					find_command = { "rg", "--files", "--hidden", "--glob", "!.git/*" },
				},
			},
		})

		-- FZF拡張を読み込み（高速化）
		telescope.load_extension("fzf")
	end,
}
