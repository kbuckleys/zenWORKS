-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

require("options")
require("binds")
require("pack")
require("ibl").setup()
require("bufferline").setup({
  options = {
    always_show_bufferline = false,
  }
})

-- Set editor background to black
vim.api.nvim_set_hl(0, "Normal", { bg = "black" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "black" })
vim.api.nvim_set_hl(0, "StatusLine", { bg = "black" })
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "black" })
