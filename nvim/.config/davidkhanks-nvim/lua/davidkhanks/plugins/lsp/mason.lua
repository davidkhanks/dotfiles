return {
	"williamboman/mason.nvim",
	commit = "e2f7f9044ec30067bc11800a9e266664b88cda22",
	dependencies = {
		{ "williamboman/mason-lspconfig.nvim", commit = "25c11854aa25558ee6c03432edfa0df0217324be" },
		{ "WhoIsSethDaniel/mason-tool-installer.nvim", commit = "c5e07b8ff54187716334d585db34282e46fa2932" },
	},
	config = function()
		-- import mason
		local mason = require("mason")

		-- import mason-lspconfig
		local mason_lspconfig = require("mason-lspconfig")

		local mason_tool_installer = require("mason-tool-installer")

		-- enable mason and configure icons
		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			-- list of servers for mason to install
			ensure_installed = {
				"cssls",
				"emmet_ls",
				"gopls",
				"graphql",
				"html",
				"lua_ls",
				"prismals",
				"pyright",
				"svelte",
				"tailwindcss",
				"terraformls",
				"ts_ls",
			},
		})

		mason_tool_installer.setup({
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
