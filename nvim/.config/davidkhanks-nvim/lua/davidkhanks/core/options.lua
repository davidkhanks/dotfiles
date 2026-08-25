vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt

opt.relativenumber = true
opt.number = true

-- tabs & indentation
opt.tabstop = 2 -- 2 spaces for tabs (prettier default)
opt.shiftwidth = 2 -- 2 spaces for indent with
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

-- Line wrap
opt.wrap = true

-- Do not use swap files for unsaved buffers
opt.swapfile = false

-- Do not wriate a backup file while saving
opt.backup = false

-- Undo tree stored in file
opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
opt.undofile = true

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you inlclude mixed case, it assumes case-sensitive

-- Cursorline is highlighted
opt.cursorline = true

-- Keep at least 8 lines visible above or below the cursor when scrolling
opt.scrolloff = 8

-- highlight the 180th column to know where to line break
opt.colorcolumn = "180"

-- Allow @ in filenames
opt.isfname:append("@-@")

-- turn on termguicolors for onedark colorscheme to work
-- (have to use iterm2 or any other true color terminal)
opt.termguicolors = true

-- colorschemes that can be light or dark will be dark
opt.background = "dark"

-- Always show the sign column
opt.signcolumn = "yes"

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- split windows
opt.splitright = true
opt.splitbelow = true

-- Always show the signcolum
opt.signcolumn = "yes"

-- Set update idle time to 50 ms
opt.updatetime = 50

-- auto reload a file
vim.o.autoread = true

-- Custom autocommand to reload files for git changes on specific events
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
	command = "if mode() != 'c' | checktime | endif",
	pattern = { "*" },
})
