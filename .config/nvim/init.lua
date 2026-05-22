-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

require("options")
require("binds")
require("pack")

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Set editor background to black
vim.api.nvim_set_hl(0, "Normal", { bg = "black" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "black" })
vim.api.nvim_set_hl(0, "StatusLine", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "black" })
