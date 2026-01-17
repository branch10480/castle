-- UI改善プラグイン

return {
	-- ファイルアイコン
	{
		"nvim-tree/nvim-web-devicons",
		config = function()
			require("nvim-web-devicons").setup({
				override = {},
				default = true,
			})
		end,
	},

	-- カラースキーム: Tokyonight
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("tokyonight").setup({
				style = "night", -- night, storm, day, moon
				transparent = true, -- 透明背景を有効化
				terminal_colors = true,
				styles = {
					comments = { italic = true },
					keywords = { italic = true },
					sidebars = "transparent",
					floats = "transparent",
				},
			})

			-- カラースキームを適用
			vim.cmd([[colorscheme tokyonight]])
		end,
	},
}
