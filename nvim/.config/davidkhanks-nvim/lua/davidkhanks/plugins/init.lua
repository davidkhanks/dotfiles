return {
	{ "nvim-lua/plenary.nvim", commit = "2d9b06177a975543726ce5c73fca176cedbffe9d" }, -- lua functions that many plugins use

	-- Seamless navigation between Neovim splits and terminal multiplexer panes,
	-- replacing vim-tmux-navigator. Same C-h/j/k/l, but it also speaks herdr
	-- (Omarchy's workspace manager). Navigation only: resizing stays on the
	-- multiplexer's own Ctrl+Alt+Shift+arrows, so M-h/j/k/l are free.
	--
	-- Deliberately NOT lazy-loaded. The tmux integration works by this plugin
	-- setting the pane-local @pane-is-vim variable on load; lazy-load it and the
	-- variable is unset until the plugin happens to load, so tmux swallows the
	-- keys instead of forwarding them.
	{
		"mrjones2014/smart-splits.nvim",
		lazy = false,
		config = function()
			require("smart-splits").setup({
				-- Stop at the outermost edge rather than wrapping around; wrapping
				-- makes a mistyped key jump to the far side of the screen.
				at_edge = "stop",
			})

			local ss = require("smart-splits")
			vim.keymap.set("n", "<C-h>", ss.move_cursor_left, { desc = "Move to split/pane left" })
			vim.keymap.set("n", "<C-j>", ss.move_cursor_down, { desc = "Move to split/pane below" })
			vim.keymap.set("n", "<C-k>", ss.move_cursor_up, { desc = "Move to split/pane above" })
			vim.keymap.set("n", "<C-l>", ss.move_cursor_right, { desc = "Move to split/pane right" })

		end,
	},
}
