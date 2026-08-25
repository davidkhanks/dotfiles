return {
	"goolord/alpha-nvim",
	commit = "bf3c8bb8c02ed3d9644cc5bbc48e2bdc39349cd7",
	event = "VimEnter",
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		-- Set header
		-- dashboard.section.header.val = {
		-- 	"                                                     ",
		-- 	"  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
		-- 	"  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
		-- 	"  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
		-- 	"  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
		-- 	"  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
		-- 	"  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
		-- 	"                                                     ",
		-- }
		--
		-- Generated from: https://patorjk.com/software/taag/#p=display&v=0&f=ANSI%20Shadow&t=DAVIDKHANKS

		dashboard.section.header.val = {
			"                                                                                        ",
			" ██████╗  █████╗ ██╗   ██╗██╗██████╗ ██╗  ██╗██╗  ██╗ █████╗ ███╗   ██╗██╗  ██╗███████╗ ",
			" ██╔══██╗██╔══██╗██║   ██║██║██╔══██╗██║ ██╔╝██║  ██║██╔══██╗████╗  ██║██║ ██╔╝██╔════╝ ",
			" ██║  ██║███████║██║   ██║██║██║  ██║█████╔╝ ███████║███████║██╔██╗ ██║█████╔╝ ███████╗ ",
			" ██║  ██║██╔══██║╚██╗ ██╔╝██║██║  ██║██╔═██╗ ██╔══██║██╔══██║██║╚██╗██║██╔═██╗ ╚════██║ ",
			" ██████╔╝██║  ██║ ╚████╔╝ ██║██████╔╝██║  ██╗██║  ██║██║  ██║██║ ╚████║██║  ██╗███████║ ",
			" ╚═════╝ ╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝ ",
			"                                                                                        ",
			"                                                                                        ",
			"                  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗                    ",
			"                  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║                    ",
			"                  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║                    ",
			"                  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║                    ",
			"                  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║                    ",
			"                  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝                    ",
			"                                                                                        ",
		}

		-- Set menu
		dashboard.section.buttons.val = {
			dashboard.button("e", "  > New File", "<cmd>ene<CR>"),
			dashboard.button("SPC pt", "  > Toggle file explorer", "<cmd>NvimTreeToggle<CR>"),
			dashboard.button("SPC pf", "󰱼  > Find File", "<cmd>Telescope find_files<CR>"),
			dashboard.button("SPC sp", "  > Find Word", "<cmd>Telescope live_grep<CR>"),
			-- dashboard.button("SPC wr", "󰁯  > Restore Session For Current Directory", "<cmd>SessionRestore<CR>"),
			dashboard.button("q", "  > Quit NVIM", "<cmd>qa<CR>"),
		}

		-- Send config to alpha
		alpha.setup(dashboard.opts)

		-- Disable folding on alpha buffer
		vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
	end,
}
