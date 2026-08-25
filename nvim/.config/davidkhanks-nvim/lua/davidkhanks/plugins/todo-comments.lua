return {
	"folke/todo-comments.nvim",
	commit = "ae0a2afb47cf7395dc400e5dc4e05274bf4fb9e0",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		{ "nvim-lua/plenary.nvim", commit = "2d9b06177a975543726ce5c73fca176cedbffe9d" },
	},
	config = function()
		local todo_comments = require("todo-comments")

		-- set keymaps
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "]t", function()
			todo_comments.jump_next()
		end, { desc = "Next todo comment" })

		keymap.set("n", "[t", function()
			todo_comments.jump_prev()
		end, { desc = "Previous todo comment" })

		todo_comments.setup()
	end,
}
