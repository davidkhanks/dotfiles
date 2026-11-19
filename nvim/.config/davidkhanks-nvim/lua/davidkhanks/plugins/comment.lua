return {
	"numToStr/Comment.nvim",
	commit = "e30b7f2008e52442154b66f7c519bfd2f1e32acb",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		{ "JoosepAlviste/nvim-ts-context-commentstring", commit = "6141a40173c6efa98242dc951ed4b6f892c97027" },
	},
	config = function()
		-- import comment plugin safely
		local comment = require("Comment")

		local ts_context_commentstring = require("ts_context_commentstring.integrations.comment_nvim")

		-- enable comment
		comment.setup({
			-- for commenting tsx, jsx, svelte, html files
			pre_hook = ts_context_commentstring.create_pre_hook(),
		})
		-- Yank and comment visual block
		vim.keymap.set("v", "<leader>yc", function()
			vim.cmd("normal! y") -- yank the selection
			require("Comment.api").toggle.linewise("visual")
		end, { desc = "Yank and comment visual block" })
	end,
}
