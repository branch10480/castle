-- LSP設定 (Neovim 0.11+ / nvim-lspconfig 新API)

return {
	-- Mason: LSPサーバーのインストール管理
	{
		"williamboman/mason.nvim",
		opts = {
			ui = {
				border = "rounded",
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		},
	},

	-- mason-lspconfig: MasonとLSPの連携
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"williamboman/mason.nvim",
			"neovim/nvim-lspconfig",
		},
		opts = {
			-- 自動インストールするサーバー
			ensure_installed = {
				"lua_ls",
			},
			-- mason経由でインストールしたサーバーを自動でvim.lsp.enable()
			automatic_enable = true,
		},
	},

	-- nvim-lspconfig: LSPサーバー設定の定義を提供
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			-- 1. グローバル診断設定
			vim.diagnostic.config({
				virtual_text = {
					prefix = "●",
				},
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ",
						[vim.diagnostic.severity.WARN] = " ",
						[vim.diagnostic.severity.HINT] = " ",
						[vim.diagnostic.severity.INFO] = " ",
					},
				},
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
					source = true,
				},
			})

			-- 2. cmp-nvim-lspのcapabilities（全サーバー共通）
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- 3. 全サーバー共通設定（vim.lsp.config('*', ...)）
			vim.lsp.config("*", {
				capabilities = capabilities,
			})

			-- 4. サーバー固有設定（vim.lsp.config()を使用）
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							checkThirdParty = false,
						},
						telemetry = {
							enable = false,
						},
					},
				},
			})

			-- Swift (sourcekit-lsp) - Xcodeに付属
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
			vim.lsp.enable("sourcekit")

			-- 5. LspAttachオートコマンド（キーマップ設定）
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(args)
					local bufnr = args.buf
					local opts = { buffer = bufnr, silent = true }

					-- キーマップ設定
					vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "定義へジャンプ" }))
					vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "宣言へジャンプ" }))
					vim.keymap.set("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "実装へジャンプ" }))
					vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "参照を表示" }))
					vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "ホバードキュメント" }))
					vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "シンボルをリネーム" }))
					vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "コードアクション" }))
					vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, vim.tbl_extend("force", opts, { desc = "前の診断" }))
					vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, vim.tbl_extend("force", opts, { desc = "次の診断" }))
					vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "診断を表示" }))
				end,
			})
		end,
	},
}
