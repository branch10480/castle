-- Snacks.nvim Picker設定

return {
	"folke/snacks.nvim",
	opts = {
		picker = {
			enabled = true,
		},
	},
	keys = {
		{ "<leader>ff", function() Snacks.picker.files({ hidden = true }) end, desc = "ファイル検索" },
		{ "<leader>fg", function() Snacks.picker.grep() end, desc = "Grep検索" },
		{ "<leader>fb", function() Snacks.picker.buffers() end, desc = "バッファ一覧" },
		{ "<leader>fh", function() Snacks.picker.help() end, desc = "ヘルプタグ検索" },
		{ "<leader>fo", function() Snacks.picker.recent() end, desc = "最近開いたファイル" },
		{ "<leader>fc", function() Snacks.picker.lines() end, desc = "現在のバッファ内検索" },
		{ "<leader>fs", function() Snacks.picker.grep_word() end, desc = "カーソル下の単語を検索" },
	},
}
