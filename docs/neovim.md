# Neovim

A plain `lazy.nvim` config (not LazyVim), living at
`nvim/.config/davidkhanks-nvim/` so it can coexist with another config under a
different `NVIM_APPNAME`.

`bootstrap.sh` symlinks `~/.config/nvim` → `davidkhanks-nvim`, so plain `nvim`
picks it up everywhere — terminal, desktop launchers, git editor — with no env
var. Omarchy's stock LazyVim was moved aside to `~/.config/nvim.lazyvim.bak`.

## Never `:Lazy sync` or `:Lazy update`

Use **`:Lazy restore`**, which pins every plugin to `lazy-lock.json`.

`sync`/`update` walk plugins forward off their pinned commits. Doing that once
broke two things at once:

- `nvim-treesitter` jumped from `master` to `main` (the rewrite), which has no
  `nvim-treesitter.configs` → hard error on every startup
- `mason-lspconfig` jumped to v2, which removed `setup_handlers()` → hard error

`bootstrap.sh --nvim-sync` uses `restore` for this reason.

## Branch pins are load-bearing

Two plugins pin a commit that exists **only on a non-default branch**. Without
an explicit `branch`, lazy.nvim clones the repo's default branch and cannot
reach the pinned commit — it silently lands on the branch HEAD instead.

| Plugin | Required | Why |
|---|---|---|
| `nvim-treesitter` | `branch = "master"` | default is now `main`, the rewrite |
| `telescope.nvim` | `branch = "0.1.x"` | pinned commit lives only on `0.1.x` |

Both would bite on any fresh clone. If you pin a commit, check it is reachable
from the branch lazy will actually clone.

## LSP uses the native API

Migrated off `mason-lspconfig.setup_handlers()` + `lspconfig[server].setup{}` to
Neovim's built-in configuration (0.11+):

```lua
vim.lsp.config("*", { capabilities = ... })          -- global defaults
vim.lsp.config("lua_ls", { settings = {...} })       -- per-server override
vim.lsp.enable(require("davidkhanks.lsp-servers"))   -- activate
```

Key points:

- **`nvim-lspconfig` is `lazy = false`.** Its job now is putting `lsp/<server>.lua`
  definitions on the runtimepath; a lazy-loaded plugin is not on the rtp yet
  when `vim.lsp.enable()` resolves configs.
- **`mason-lspconfig` has `automatic_enable = false`.** Enabling happens
  explicitly at the end of `lspconfig.lua`, strictly *after* the
  `vim.lsp.config()` calls, rather than racing them at startup.
- **`lua/davidkhanks/lsp-servers.lua`** is the single server list, consumed by
  both `mason.lua` (install) and `lspconfig.lua` (enable). It sits *outside*
  `lua/davidkhanks/plugins/` on purpose — lazy.nvim imports every file in that
  directory as a plugin spec, and a list of strings would be read as plugin names.

### Merge order

Per `:h lsp-config-merge`, increasing priority:

1. `vim.lsp.config('*', ...)`
2. `lsp/<name>.lua` on the runtimepath (nvim-lspconfig ships these)
3. `after/lsp/<name>.lua`
4. `vim.lsp.config('<name>', ...)` ← highest

So per-server overrides live in `lspconfig.lua` and win over nvim-lspconfig's
own definitions. List values (e.g. `filetypes`) are **replaced**, not appended.

### lazydev, not neodev

`neodev.nvim` is archived *and* worked by hooking lspconfig's old framework — it
would be silently inert after this migration. `lazydev.nvim` replaces it and
works with the native path.

## Theme follows Omarchy

`plugins/colorscheme.lua` reads Omarchy's active theme at
`~/.local/state/omarchy/current/theme/neovim.lua` and translates it.

That file is a *LazyVim* spec — colorscheme plugins plus a `LazyVim/LazyVim`
entry whose `opts.colorscheme` names the scheme. Symlinking it the way Omarchy
does for its stock config would install LazyVim as a plugin here *and* never
apply the colorscheme. So the config `dofile`s it, keeps the real plugin specs,
reads the name off the marker entry, and applies it on `VimEnter`.

Seven stock themes ship no `neovim.lua` (ethereal, last-horizon, lupine,
miasma, ristretto, vantablack, white); those fall back to onedark.

Live theme changes are pushed to running instances by
`omarchy/.config/omarchy/hooks/theme-set.d/nvim-colorscheme`, which uses
`nvim --server ... --remote-expr`. (`--remote-send` would type the keys into
whatever mode the buffer is in.) A theme whose colorscheme plugin has never
been installed cannot apply to a running instance — restart nvim and lazy.nvim
installs it.

`lualine` uses `theme = "auto"` so the status bar follows too.

## Known cosmetic gap

`gopls` is in `lsp-servers.lua` but cannot install without the Go toolchain.
Either `omarchy pkg add go` or drop it from the list.
