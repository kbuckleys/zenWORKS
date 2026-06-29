-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

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
    c = { bg = "#000000" }, a = { bg = "#000000" },
    a = { bg = "#000000" }, a = { bg = "#000000", gui = "bold" }
  }
}

vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "BufferLineFill", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineBackground", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = "#dfdfdd", bg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", { bg = "#000000", fg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#20242a", nocombine = true })
vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "Visual", { fg = "#000000", bg = "#fab387", nocombine = true })
vim.api.nvim_set_hl(0, "YankHighlight", { bg = "#dfdfdd", fg = "#000000", nocombine = true })

require("lualine").setup({
  options = {
    theme = kripton,
    icons_enabled = false,
    section_separators = " 󰇙 ",
    component_separators = " 󰇙 "
  }
})

require("bufferline").setup({
  options = {
    separator_style = { "", "" },
    show_buffer_close_icons = false,
    always_show_bufferline = false,
    show_buffer_icons = false,
    tab_size = 25,
    modified_icon = "✎"
  },
  highlights = {
    modified = {
      fg = "#FFFFFF",
      bg = "#20242a"
    },
    modified_selected = {
      bg = "#000000"
    }
  }
})
