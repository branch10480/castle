-- LSP設定 (Neovim 0.11+ ネイティブAPI使用)

return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				-- 自動インストールする言語サーバー
				ensure_installed = {
					"lua_ls", -- Lua
				},
				automatic_installation = true,
				-- Neovim 0.11の新しいAPIを自動的に有効化
				automatic_enable = true,
			})
		end,
	},

	{
		"hrsh7th/cmp-nvim-lsp",
		lazy = true,
		config = function()
			-- 1. グローバル診断設定
			vim.diagnostic.config({
				virtual_text = {
					prefix = "●",
				},
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
			})

			-- 2. 診断記号の設定
			local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
			end

			-- 3. LSPハンドラの設定
			vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
				border = "rounded",
			})

			vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
				border = "rounded",
			})

			-- 4. LspAttachオートコマンド（on_attachの代替）
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local bufnr = args.buf
					local opts = { buffer = bufnr, silent = true }

					-- キーマップの設定
					vim.keymap.set(
						"n",
						"gd",
						vim.lsp.buf.definition,
						vim.tbl_extend("force", opts, { desc = "定義へジャンプ" })
					)
					vim.keymap.set(
						"n",
						"gD",
						vim.lsp.buf.declaration,
						vim.tbl_extend("force", opts, { desc = "宣言へジャンプ" })
					)
					vim.keymap.set(
						"n",
						"gi",
						vim.lsp.buf.implementation,
						vim.tbl_extend("force", opts, { desc = "実装へジャンプ" })
					)
					vim.keymap.set(
						"n",
						"gr",
						vim.lsp.buf.references,
						vim.tbl_extend("force", opts, { desc = "参照を表示" })
					)
					vim.keymap.set(
						"n",
						"K",
						vim.lsp.buf.hover,
						vim.tbl_extend("force", opts, { desc = "ホバードキュメント" })
					)
					vim.keymap.set(
						"n",
						"<leader>rn",
						vim.lsp.buf.rename,
						vim.tbl_extend("force", opts, { desc = "シンボルをリネーム" })
					)
					vim.keymap.set(
						"n",
						"<leader>ca",
						vim.lsp.buf.code_action,
						vim.tbl_extend("force", opts, { desc = "コードアクション" })
					)
					vim.keymap.set(
						"n",
						"[d",
						vim.diagnostic.goto_prev,
						vim.tbl_extend("force", opts, { desc = "前の診断" })
					)
					vim.keymap.set(
						"n",
						"]d",
						vim.diagnostic.goto_next,
						vim.tbl_extend("force", opts, { desc = "次の診断" })
					)
					vim.keymap.set(
						"n",
						"<leader>e",
						vim.diagnostic.open_float,
						vim.tbl_extend("force", opts, { desc = "診断を表示" })
					)
				end,
			})

			-- 5. グローバルcapabilities設定
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			vim.lsp.config("*", { capabilities = capabilities })

			-- 6. サーバー固有設定
			-- Lua Language Server
			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							library = {
								[vim.fn.expand("$VIMRUNTIME/lua")] = true,
								[vim.fn.stdpath("config") .. "/lua"] = true,
							},
						},
						telemetry = {
							enable = false,
						},
					},
				},
			})
		end,
	},
}
