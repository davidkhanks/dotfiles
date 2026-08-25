return {
	"nvim-treesitter/nvim-treesitter",
	commit = "92725df6222614307c4712eb9982e5287f21aa11",
	event = { "BufReadPre", "BufNewFile" },
	build = ":TSUpdate",
	dependencies = {
		{ "windwp/nvim-ts-autotag", commit = "e239a560f338be31337e7abc3ee42515daf23f5e" },
	},
	config = function()
		-- import nvim-treesitter plugin
		local treesitter = require("nvim-treesitter.configs")

		-- configure treesitter
		treesitter.setup({ -- enable syntax highlighting
			highlight = {
				enable = true,
			},
			-- enable indentation
			indent = { enable = true },
			-- enable autotagging (w/ nvim-ts-autotag plugin)
			autotag = {
				enable = true,
			},
			-- ensure these language parsers are installed
			ensure_installed = {
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
			},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<C-space>",
					node_incremental = "<C-space>",
					scope_incremental = false,
					node_decremental = "<bs>",
				},
			},
		})
	end,
}
