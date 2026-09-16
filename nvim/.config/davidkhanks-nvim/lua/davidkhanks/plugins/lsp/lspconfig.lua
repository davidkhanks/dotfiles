return {
	"neovim/nvim-lspconfig",
	commit = "af9adce488c75ca0a81017945c2b7fa7b461bc23",
	-- Not lazy: this plugin's job is now to put `lsp/<server>.lua` definitions
	-- on the 'runtimepath' so that vim.lsp.enable() (at the bottom of `config`)
	-- can resolve them. A lazy-loaded plugin is not on the runtimepath yet.
	lazy = false,
	dependencies = {
		{ "hrsh7th/cmp-nvim-lsp", commit = "39e2eda76828d88b773cc27a3f61d2ad782c922d" },
		{
			"antosha417/nvim-lsp-file-operations",
			config = true,
			commit = "92a673de7ecaa157dd230d0128def10beb56d103",
		},
		-- Replaces the archived neodev.nvim. neodev worked by hooking
		-- lspconfig's old framework, which we no longer use, so it would be
		-- inert here. lazydev teaches lua_ls about the Neovim API and works
		-- with the native vim.lsp.config() path.
		{
			"folke/lazydev.nvim",
			commit = "ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d",
			ft = "lua",
			opts = {
				library = {
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
			},
		},
	},
	config = function()
		-- ── Diagnostics ──────────────────────────────────────────────────────
		-- Signs are configured through vim.diagnostic.config() now;
		-- sign_define() for diagnostics is deprecated.
		vim.diagnostic.config({
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = " ",
					[vim.diagnostic.severity.WARN] = " ",
					[vim.diagnostic.severity.HINT] = "󰠠 ",
					[vim.diagnostic.severity.INFO] = " ",
				},
			},
		})

		-- ── Keymaps ──────────────────────────────────────────────────────────
		-- Neovim 0.11+ already provides grn (rename), gra (code action),
		-- grr (references), gri (implementation), grt (type definition),
		-- grx (codelens), gO (document symbol) and i_CTRL-S (signature help).
		-- The maps below are kept because they route through Telescope, which
		-- gives a nicer picker than the built-in list.
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local keymap = vim.keymap
				local opts = { buffer = ev.buf, silent = true }

				opts.desc = "Show LSP references"
				keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts)

				opts.desc = "Go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

				opts.desc = "Show LSP definitions"
				keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts)

				opts.desc = "Show LSP implementations"
				keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)

				opts.desc = "Show LSP type definitions"
				keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

				opts.desc = "See available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

				opts.desc = "Smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)

				opts.desc = "Show line diagnostics"
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

				-- vim.diagnostic.goto_prev/goto_next are deprecated in favour
				-- of vim.diagnostic.jump().
				opts.desc = "Go to previous diagnostic"
				keymap.set("n", "[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end, opts)

				opts.desc = "Go to next diagnostic"
				keymap.set("n", "]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end, opts)

				opts.desc = "Show documentation for what is under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts)

				-- :LspRestart came from lspconfig's framework; :lsp restart is
				-- the built-in equivalent.
				opts.desc = "Restart LSP"
				keymap.set("n", "<leader>rs", "<cmd>lsp restart<CR>", opts)
			end,
		})

		-- ── Global server defaults ───────────────────────────────────────────
		-- Lowest-priority layer in the merge order (see :h lsp-config-merge),
		-- so every server inherits these unless it overrides them.
		vim.lsp.config("*", {
			capabilities = vim.tbl_deep_extend(
				"force",
				require("cmp_nvim_lsp").default_capabilities(),
				require("lsp-file-operations").default_capabilities()
			),
		})

		-- ── Per-server overrides ─────────────────────────────────────────────
		-- vim.lsp.config("<name>", ...) is the highest-priority layer, so these
		-- win over nvim-lspconfig's own lsp/<name>.lua definitions. List-like
		-- values (such as `filetypes`) are replaced wholesale, not appended.
		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					-- Recognise the `vim` global.
					diagnostics = { globals = { "vim" } },
					completion = { callSnippet = "Replace" },
				},
			},
		})

		vim.lsp.config("html", {
			filetypes = { "html", "htm" },
		})

		vim.lsp.config("graphql", {
			filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
		})

		vim.lsp.config("emmet_ls", {
			filetypes = {
				"html",
				"htm",
				"typescriptreact",
				"javascriptreact",
				"css",
				"sass",
				"scss",
				"less",
				"svelte",
			},
		})

		vim.lsp.config("svelte", {
			on_attach = function(client, _)
				vim.api.nvim_create_autocmd("BufWritePost", {
					pattern = { "*.js", "*.ts" },
					callback = function(ctx)
						-- Client:notify() -- client.notify() is deprecated.
						client:notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
					end,
				})
			end,
		})

		-- ── Activate ─────────────────────────────────────────────────────────
		-- mason-lspconfig's automatic_enable is switched off (see mason.lua) so
		-- that enabling happens here, strictly after the configs above.
		vim.lsp.enable(require("davidkhanks.lsp-servers"))
	end,
}
