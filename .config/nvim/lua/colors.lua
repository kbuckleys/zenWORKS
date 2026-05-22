-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

vim.api.nvim_set_hl(0, "Normal", { bg = "black" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "black" })
vim.api.nvim_set_hl(0, "StatusLine", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "black" })

local mode_colors = {
  normal = "#20242a",
  insert = "#b6e0a4",
  visual = "#fab387",
}

local custom_theme = {
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
    theme = custom_theme,
    icons_enabled = false,
    section_separators = " 󰇙 ",
    component_separators = " 󰇙 ",
  },
})   
