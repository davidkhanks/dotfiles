return {
	"nvim-tree/nvim-tree.lua",
	commit = "f5f67892996b280ae78b1b0a2d07c4fa29ae0905",
	dependencies = { { "nvim-tree/nvim-web-devicons", commit = "19d257cf889f79f4022163c3fbb5e08639077bd8" } },
	config = function()
		local nvimtree = require("nvim-tree")

		-- Recommended settings from nvim-tree docs
		vim.g.loaded = 1
		vim.g.loaded_netrwPlugin = 1

		nvimtree.setup({
			renderer = {
				indent_markers = {
					enable = true,
				},
				icons = {
					glyphs = {
						folder = {
							arrow_closed = "", -- arrow when folder is closed
							arrow_open = "", -- arrow when folder is open
						},
					},
				},
			},

			filters = {
				git_ignored = true,
				dotfiles = false,
				git_clean = false,
				no_buffer = false,
				custom = { "^.git$", "^__pycache__$" },
				exclude = { "local.py", ".devhome", ".env" },
			},
			git = {
				show_on_open_dirs = false,
			},
			actions = {
				open_file = {
					window_picker = {
						chars = "JKL1234567890",
					},
				},
			},
			diagnostics = {
				enable = true,
				show_on_dirs = true,
				show_on_open_dirs = true,
				severity = {
					min = vim.diagnostic.severity.ERROR,
					max = vim.diagnostic.severity.ERROR,
				},
			},
		})

		-- Custom keybindings for Spacemacs-like experience
		-- Jump to tree
		vim.keymap.set("n", "<leader>pt", function()
			vim.cmd("NvimTreeFocus")
		end, { desc = "Nvim-tree Focus" })

		-- Close the tree
		vim.keymap.set("n", "<leader>pq", function()
			vim.cmd("NvimTreeClose")
		end, { desc = "Nvim-tree Close" })

		-- Collapse the tree
		vim.keymap.set("n", "<leader>ph", function()
			vim.cmd("NvimTreeCollapse")
		end, { desc = "Nvim-tree Collapse all" })

		-- Collapse the tree except for where there are open buffers
		vim.keymap.set("n", "<leader>pH", function()
			vim.cmd("NvimTreeCollapseKeepBuffers")
		end, { desc = "Nvim-tree Collapse non-open" })

		-- Make the tree window bigger by 10
		vim.keymap.set("n", "<leader>p]", function()
			vim.cmd("NvimTreeResize +10")
		end, { desc = "Nvim-tree increase size" })

		-- Make the tree window smaller by 10
		vim.keymap.set("n", "<leader>p[", function()
			vim.cmd("NvimTreeResize -10")
		end, { desc = "Nvim-tree increase size" })

		-- Jump to tree and go to currently open buffer
		vim.keymap.set("n", "<leader>ff", function()
			vim.cmd("NvimTreeFindFile")
		end, { desc = "Find file in Nvim-tree" })
	end,
}
