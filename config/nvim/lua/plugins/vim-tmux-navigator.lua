-- vim-tmux-navigator: nvim window と tmux pane を C-h/j/k/l でシームレスに行き来する。
-- tmux 側には home/.tmux.conf で同名の plugin が入っており、両端で is_vim 判定により
-- フォーカス先が nvim/tmux のどちらでも適切に C-h/j/k/l が伝播する。
-- 詳細: docs/tmux-setup.md

return {
	"christoomey/vim-tmux-navigator",
	cmd = {
		"TmuxNavigateLeft",
		"TmuxNavigateDown",
		"TmuxNavigateUp",
		"TmuxNavigateRight",
		"TmuxNavigatePrevious",
		"TmuxNavigatorProcessList",
	},
	keys = {
		{ "<C-h>", "<cmd><C-U>TmuxNavigateLeft<CR>", desc = "左の nvim window / tmux pane へ" },
		{ "<C-j>", "<cmd><C-U>TmuxNavigateDown<CR>", desc = "下の nvim window / tmux pane へ" },
		{ "<C-k>", "<cmd><C-U>TmuxNavigateUp<CR>", desc = "上の nvim window / tmux pane へ" },
		{ "<C-l>", "<cmd><C-U>TmuxNavigateRight<CR>", desc = "右の nvim window / tmux pane へ" },
		{ "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<CR>", desc = "直前の nvim window / tmux pane へ" },
	},
}
