-- Trouble: 診断・参照・quickfix を一覧表示

return {
	"folke/trouble.nvim",
	cmd = "Trouble",
	keys = {
		{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "診断一覧 (Trouble)" },
		{ "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "現在バッファの診断一覧" },
		{ "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "シンボル一覧 (Trouble)" },
		{ "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP一覧 (Trouble)" },
		{ "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "loclist一覧 (Trouble)" },
		{ "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "quickfix一覧 (Trouble)" },
	},
	opts = {
		use_diagnostic_signs = true,
	},
}
