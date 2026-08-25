return {
	"karb94/neoscroll.nvim",
	commit = "4e0428a41c6ec191df543fc95349f6e1c598e53f",
	config = function()
		NeoScroll = require("neoscroll")
		NeoScroll.setup({})
		local keymap = {
			["<C-u>"] = function()
				NeoScroll.ctrl_u({ duration = 25 })
			end,
			["<C-d>"] = function()
				NeoScroll.ctrl_d({ duration = 25 })
			end,
			["<C-b>"] = function()
				NeoScroll.ctrl_b({ duration = 450 })
			end,
			["<C-f>"] = function()
				NeoScroll.ctrl_f({ duration = 450 })
			end,
			["<C-y>"] = function()
				NeoScroll.scroll(-0.1, { move_cursor = false, duration = 100 })
			end,
			["<C-e>"] = function()
				NeoScroll.scroll(0.1, { move_cursor = false, duration = 100 })
			end,
			["zt"] = function()
				NeoScroll.zt({ half_win_duration = 100 })
			end,
			["zz"] = function()
				NeoScroll.zz({ half_win_duration = 100 })
			end,
			["zb"] = function()
				NeoScroll.zb({ half_win_duration = 100 })
			end,
		}
		local modes = { "n", "v", "x" }
		for key, func in pairs(keymap) do
			vim.keymap.set(modes, key, func)
		end
	end,
}
