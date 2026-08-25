return {
	"windwp/nvim-autopairs",
	commit = "ee297f215e95a60b01fde33275cc3c820eddeebe",
	event = { "InsertEnter" },
	dependencies = {
		{ "hrsh7th/nvim-cmp", commit = "ae644feb7b67bf1ce4260c231d1d4300b19c6f30" },
	},
	config = function()
		-- import nvim-autopairs
		local autopairs = require("nvim-autopairs")

		-- configure autopairs
		autopairs.setup({
			check_ts = true, -- enable treesitter
			ts_config = {
				lua = { "string" }, -- don't add pairs in lua string treesitter nodes
				javascript = { "template_string" }, -- don't add pairs in javscript template_string treesitter nodes
				java = false, -- don't check treesitter on java
			},
		})

		-- import nvim-autopairs completion functionality
		local cmp_autopairs = require("nvim-autopairs.completion.cmp")

		-- import nvim-cmp plugin (completions plugin)
		local cmp = require("cmp")

		-- make autopairs and completion work together
		cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
	end,
}
