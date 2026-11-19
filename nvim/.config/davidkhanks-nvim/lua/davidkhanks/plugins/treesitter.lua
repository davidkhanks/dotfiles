-- Parsers to keep installed. `install` is a no-op for ones already present.
local parsers = {
	"bash",
	"c",
	"css",
	"dockerfile",
	"gitignore",
	"go",
	"html",
	"javascript",
	"json",
	"lua",
	"markdown",
	"markdown_inline",
	"prisma",
	"python",
	"query",
	"typescript",
	"tsx",
	"vim",
	"vimdoc",
	"yaml",
}

return {
	"nvim-treesitter/nvim-treesitter",
	-- `main` is the rewrite, and the only branch that works on Neovim 0.12.
	-- `master` is archived and stops at 0.11: 0.12 removed the `all = false`
	-- option its query directives relied on, so every directive received a
	-- list of nodes instead of a node. In Markdown that raised
	-- "attempt to call method 'range' (a nil value)" from languagetree.lua on
	-- every reparse -- i.e. on nearly every cursor move.
	--
	-- `main` has no `nvim-treesitter.configs` and no modules: highlighting and
	-- indent are enabled per buffer below, and incremental selection is gone
	-- (Neovim 0.12's built-in `an`/`in` in visual mode covers it where an LSP
	-- is attached). It needs the `tree-sitter` CLI to build parsers.
	branch = "main",
	commit = "37e52c733ada9d8d544d53a763140ef1ba404353",
	-- `main` does not support lazy-loading.
	lazy = false,
	build = ":TSUpdate",
	dependencies = {
		{ "windwp/nvim-ts-autotag", commit = "e239a560f338be31337e7abc3ee42515daf23f5e" },
	},
	config = function()
		require("nvim-treesitter").install(parsers)

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("davidkhanks-treesitter", { clear = true }),
			callback = function(args)
				-- Errors when no parser exists for this filetype; that just
				-- means no treesitter here, so leave the buffer alone.
				if not pcall(vim.treesitter.start, args.buf) then
					return
				end
				local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
				if lang and vim.treesitter.query.get(lang, "indents") then
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})

		-- Used to be enabled through nvim-treesitter's `autotag` module, which
		-- `main` no longer has.
		require("nvim-ts-autotag").setup()
	end,
}
