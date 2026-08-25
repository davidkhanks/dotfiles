return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")
		harpoon.setup()

		-- Custom function to open the Harpoon menu and map number keys
		local function open_harpoon_with_number_nav()
			harpoon.ui:toggle_quick_menu(harpoon:list())

			-- Get the buffer ID of the currently open Harpoon UI
			local current_buf = vim.api.nvim_get_current_buf()

			-- Get the total number of files in the Harpoon list
			local num_files = harpoon:list():length()

			-- Map number keys for navigation
			for i = 1, math.min(num_files, 9) do
				local key = tostring(i)
				vim.api.nvim_buf_set_keymap(current_buf, "n", key, "", {
					callback = function()
						-- Close the UI window
						harpoon.ui:toggle_quick_menu()
						-- Navigate to the selected file
						harpoon:list():select(i) -- Navigate to the specific file
					end,
					noremap = true,
					silent = true,
				})
			end
		end
		-- Bind the custom picker to a key
		vim.keymap.set("n", "<leader>h", function()
			open_harpoon_with_number_nav()
		end, { desc = "Open Harpoon Quick Menu with number navigation" })

		vim.keymap.set("n", "<leader>a", function()
			harpoon:list():add()
		end, { desc = "Harpoon add file" })

		-- Keeping this around as I haven't decided if I want to keep the custom function yet
		-- vim.keymap.set("n", "<leader>bb", function()
		-- 	harpoon.ui:toggle_quick_menu(harpoon:list())
		-- end, { desc = "Harpoon quick list" })

		-- Loop through 1-9 and set key maps for <leader>1 - <leader>9 for quick selecting files
		for i = 1, 9 do
			vim.keymap.set("n", "<leader>" .. i, function()
				harpoon:list():select(i)
			end, { desc = "Harpoon File " .. i })
		end

		-- vim.keymap.set("n", "<leader>1", function()
		-- 	harpoon:list():select(1)
		-- end, { desc = "Harpoon File 1" })
		-- vim.keymap.set("n", "<leader>2", function()
		-- 	harpoon:list():select(2)
		-- end, { desc = "Harpoon File 2" })
		-- vim.keymap.set("n", "<leader>3", function()
		-- 	harpoon:list():select(3)
		-- end, { desc = "Harpoon File 3" })
		-- vim.keymap.set("n", "<leader>4", function()
		-- 	harpoon:list():select(4)
		-- end, { desc = "Harpoon File 4" })

		-- Toggle previous & next buffers stored within Harpoon list
		vim.keymap.set("n", "<C-S-P>", function()
			harpoon:list():prev()
		end)
		vim.keymap.set("n", "<C-S-N>", function()
			harpoon:list():next()
		end)
	end,
}
