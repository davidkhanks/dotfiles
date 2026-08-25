return {
	"nvim-telescope/telescope.nvim",
	-- branch = "0.1.x",
	commit = "a0bbec21143c7bc5f8bb02e0005fa0b982edc026",
	dependencies = {
		{ "nvim-lua/plenary.nvim", commit = "2d9b06177a975543726ce5c73fca176cedbffe9d" },
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-tree/nvim-web-devicons", commit = "19d257cf889f79f4022163c3fbb5e08639077bd8" },
		-- "folke/todo-comments.nvim",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		-- local transform_mod = require("telescope.actions.mt").transform_mod
		--
		-- local trouble = require("trouble")
		-- local trouble_telescope = require("trouble.sources.telescope")
		--
		-- -- or create your custom action
		-- local custom_actions = transform_mod({
		--   open_trouble_qflist = function(prompt_bufnr)
		--     trouble.toggle("quickfix")
		--   end,
		-- })

		telescope.setup({
			defaults = {
				-- path_display = { "smart" }, -- This truncates any parents above 3 levels
				mappings = {
					n = {
						["dd"] = actions.delete_buffer,
						["q"] = actions.close,
					},
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						-- ["<C-q>"] = function(prompt_bufnr)
						-- 	actions.open_qflist(prompt_bufnr)
						-- end,
						-- ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
						-- ["<C-t>"] = trouble_telescope.open,
					},
				},
			},
		})

		telescope.load_extension("fzf")

		-- set keymaps
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>pf", "<cmd>Telescope find_files<CR>", { desc = "Fuzzy find files in cwd" })
		-- keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Fuzzy find recent files" })
		keymap.set(
			"n",
			"<leader>ss",
			"<cmd>Telescope current_buffer_fuzzy_find<CR>",
			{ desc = "Fuzzy find in current buffer" }
		)
		keymap.set(
			"n",
			"<leader>fb",
			"<cmd>Telescope buffers sort_mru=true sort_lastused=true initial_mode=normal<CR>",
			{ desc = "See currently open buffers" }
		)

		keymap.set(
			"n",
			"<leader>sp",
			"<cmd>lua require('telescope.builtin').live_grep({ prompt_title = 'Project Grep' })<CR>",
			{ noremap = true, silent = true, desc = "Find string in cwd" }
		)

		keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<CR>", { desc = "Find string under cursor in cwd" })
		keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { desc = "Find todos" })
	end,
}
