return {
	"ntpeters/vim-better-whitespace",
	commit = "86a0579b330b133b8181b8e088943e81c26a809e",
	config = function()
		local keymap = vim.keymap -- for conciseness
		keymap.set("n", "<leader>ws", "<cmd>StripWhitespace<CR>", { desc = "Strip Whitespace in file" })
	end,
}
