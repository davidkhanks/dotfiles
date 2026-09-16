-- Single source of truth for which language servers we use.
--
-- Consumed by:
--   * plugins/lsp/mason.lua      -> Mason installs these
--   * plugins/lsp/lspconfig.lua  -> vim.lsp.enable() activates these
--
-- Names are nvim-lspconfig config names, which match the `lsp/<name>.lua`
-- files that nvim-lspconfig puts on the runtimepath.
return {
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
}
