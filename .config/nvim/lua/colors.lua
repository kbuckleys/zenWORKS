-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })   

local kripton = {
  normal = { 
    c = { bg = "#20242a" },
    a = { bg = "#20242a", gui = "bold" }
  },
  insert = { 
    c = { fg = "#000000", bg = "#b6e0a4" },
    a = { fg = "#000000", bg = "#b6e0a4", gui = "bold" }
  },
  visual = { 
    c = { fg = "#000000", bg = "#fab387" },
    a = { fg = "#000000", bg = "#fab387", gui = "bold" }
  },
  replace = {
    c = { fg = "#000000", bg = "#e78284" },
    a = { fg = "#000000", bg = "#e78284", gui = "bold" }
  },
  command = {
    c = { fg = "#000000", bg = "#9bbfbf" },
    a = { fg = "#000000", bg = "#9bbfbf", gui = "bold" }
  },
  inactive = {
    c = { bg = "black" }, a = { bg = "black" },
    a = { bg = "black" }, a = { bg = "black", gui = "bold" }
  },
}

require("lualine").setup({
  options = {
    theme = kripton,
    icons_enabled = false,
    section_separators = " 󰇙 ",
    component_separators = " 󰇙 ",
  },
})
