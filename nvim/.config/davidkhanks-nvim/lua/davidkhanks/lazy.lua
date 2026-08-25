local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- require("lazy").setup("davidkhanks.plugins", {
--   checker = {
--     enabled = true,
--     notify = false,
--   },
-- })
require("lazy").setup({ { import = "davidkhanks.plugins" }, { import = "davidkhanks.plugins.lsp" } }, {
  checker = {
    enabled = true,
    notify = false,
  },
  change_detection = {
    notify = false,
  },
})
