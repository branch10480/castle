-- Which-key: キーマップ候補をポップアップ表示

return {
	"folke/which-key.nvim",
	lazy = false,
	priority = 900,
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = true })
			end,
			desc = "キーマップ一覧 (which-key)",
		},
	},
	opts = {
		delay = 100,
		win = {
			border = "rounded",
		},
		plugins = {
			spelling = {
				enabled = true,
				suggestions = 20,
			},
		},
		spec = {
			{ "<leader>f", group = "find" },
			{ "<leader>c", group = "code" },
		},
	},
}
