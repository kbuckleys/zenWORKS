-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

require("pack")
require("options")
require("colors")
require("binds")

-- Kill all child processes on exit
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.cmd("silent !kill $(pgrep -P $$)")
  end,
})
