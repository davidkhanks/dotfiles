-- Colorscheme, driven by the active Omarchy theme.
--
-- Omarchy publishes the current theme's Neovim colorscheme at
--   ~/.local/state/omarchy/current/theme/neovim.lua
-- but it writes that file as a *LazyVim* plugin spec: one or more real
-- colorscheme plugins, plus a "LazyVim/LazyVim" entry whose opts.colorscheme
-- names the scheme to activate.
--
-- This config is plain lazy.nvim, not LazyVim, so we cannot symlink that file
-- the way Omarchy does for its stock config -- doing so would install LazyVim
-- as a plugin and still never apply the colorscheme. Instead we read the file,
-- keep the genuine plugin specs, drop the LazyVim marker, and apply the
-- colorscheme ourselves.
--
-- Some stock themes (ethereal, last-horizon, lupine, miasma, ristretto,
-- vantablack, white) ship no neovim.lua at all; those fall back to onedark.

local OMARCHY_SPEC = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

local fallback = {
	"navarasu/onedark.nvim",
	commit = "fae34f7c635797f4bf62fb00e7d0516efa8abe37",
	priority = 1000,
	config = function()
		require("onedark").setup({
			style = "deep",
			transparent = false,
			term_colors = true,
			ending_tildes = true,
		})
		vim.cmd.colorscheme("onedark")
	end,
}

-- Translate Omarchy's LazyVim spec into specs this config can use.
-- Returns nil when there is nothing usable, so the caller can fall back.
local function omarchy_theme()
	if vim.uv.fs_stat(OMARCHY_SPEC) == nil then
		return nil
	end

	local ok, specs = pcall(dofile, OMARCHY_SPEC)
	if not ok or type(specs) ~= "table" then
		return nil
	end

	local colorscheme
	local plugins = {}

	for _, spec in ipairs(specs) do
		local repo = spec[1]
		if repo == "LazyVim/LazyVim" then
			-- Marker entry: carries the colorscheme name, not a plugin we want.
			colorscheme = spec.opts and spec.opts.colorscheme
		elseif type(repo) == "string" then
			-- A real colorscheme plugin. lazy.nvim handles `opts` and
			-- `dependencies` itself, so pass the spec through untouched
			-- apart from making sure it loads during startup.
			spec.priority = spec.priority or 1000
			spec.lazy = false
			table.insert(plugins, spec)
		end
	end

	if not colorscheme or #plugins == 0 then
		return nil
	end

	-- Apply after startup plugins are loaded. The plugins above are
	-- priority 1000 / lazy=false, so they are ready by VimEnter.
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			if not pcall(vim.cmd.colorscheme, colorscheme) then
				vim.notify(
					("Omarchy theme colorscheme %q is not installed yet -- run :Lazy sync and restart"):format(
						colorscheme
					),
					vim.log.levels.WARN
				)
			end
		end,
	})

	return plugins
end

return omarchy_theme() or fallback
