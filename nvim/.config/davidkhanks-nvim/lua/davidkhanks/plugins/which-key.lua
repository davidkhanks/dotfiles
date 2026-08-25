return {
	"folke/which-key.nvim",
	commit = "8badb359f7ab8711e2575ef75dfe6fbbd87e4821",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
	},
}
