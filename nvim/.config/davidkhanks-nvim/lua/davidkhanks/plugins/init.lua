return {
	{ "nvim-lua/plenary.nvim", commit = "2d9b06177a975543726ce5c73fca176cedbffe9d" }, -- lua functions that many plugins use

	-- Seamless navigation between Neovim splits and terminal multiplexer panes,
	-- replacing vim-tmux-navigator. Same C-h/j/k/l, but it also speaks herdr
	-- (Omarchy's workspace manager) and adds resize across the same boundary,
	-- which vim-tmux-navigator never did.
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

			-- Resizing across the same boundary. vim-tmux-navigator had no
			-- equivalent; these were tmux-side bindings before.
			vim.keymap.set("n", "<M-h>", ss.resize_left, { desc = "Resize split/pane left" })
			vim.keymap.set("n", "<M-j>", ss.resize_down, { desc = "Resize split/pane down" })
			vim.keymap.set("n", "<M-k>", ss.resize_up, { desc = "Resize split/pane up" })
			vim.keymap.set("n", "<M-l>", ss.resize_right, { desc = "Resize split/pane right" })
		end,
	},
}
