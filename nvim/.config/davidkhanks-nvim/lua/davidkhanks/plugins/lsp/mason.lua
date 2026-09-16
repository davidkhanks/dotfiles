return {
	-- mason.nvim moved from williamboman/ to mason-org/ with v2.
	"mason-org/mason.nvim",
	commit = "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d",
	dependencies = {
		{
			"mason-org/mason-lspconfig.nvim",
			commit = "24d4ab0838b250753b307a8747ade06dc99aed9d",
		},
		{
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			commit = "443f1ef8b5e6bf47045cb2217b6f748a223cf7dc",
		},
	},
	config = function()
		require("mason").setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		-- mason-lspconfig v2 removed setup_handlers(). Its remaining jobs are
		-- installing servers and, optionally, calling vim.lsp.enable() for the
		-- ones it installed. We turn that off and enable explicitly in
		-- plugins/lsp/lspconfig.lua, so enabling is guaranteed to happen after
		-- the vim.lsp.config() definitions rather than racing them.
		require("mason-lspconfig").setup({
			ensure_installed = require("davidkhanks.lsp-servers"),
			automatic_enable = false,
		})

		require("mason-tool-installer").setup({
			ensure_installed = {
				"prettier", -- prettier formatter
				"stylua", -- lua formatter
				"isort", -- python formatter
				"black", -- python formatter
				"pylint",
				"eslint_d",
			},
		})
	end,
}
