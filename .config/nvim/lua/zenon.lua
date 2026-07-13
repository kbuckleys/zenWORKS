-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

vim.opt.termguicolors = true
vim.opt.background = "dark"

local term_colors = {
  black                = "#000000",
  red                  = "#e78284",
  green                = "#b6e0a4",
  yellow               = "#e0d8a4",
  blue                 = "#9fcbfc",
  magenta              = "#c8a4e0",
  cyan                 = "#9bbfbf",
  white                = "#dfdfdd",
  bright_black         = "#6a707f",
  bright_red           = "#fab387",
  bright_green         = "#b6e0a4",
  bright_yellow        = "#e0d8a4",
  bright_blue          = "#9fcbfc",
  bright_magenta       = "#c8a4e0",
  bright_cyan          = "#9bbfbf",
  bright_white         = "#dfdfdd",
}

local zenon = {
  normal = { 
    c = { bg = "#20242a" },
    a = { bg = "#20242a", gui = "bold" }
  },
  insert = { 
    c = { fg = "#000000", bg = "#b6e0a4" },
    a = { fg = "#000000", bg = "#b6e0a4", gui = "bold" }
  },
  visual = { 
    c = { fg = "#000000", bg = "#c8a4e0" },
    a = { fg = "#000000", bg = "#c8a4e0", gui = "bold" }
  },
  replace = {
    c = { fg = "#000000", bg = "#e78284" },
    a = { fg = "#000000", bg = "#e78284", gui = "bold" }
  },
  command = {
    c = { fg = "#000000", bg = "#fab387" },
    a = { fg = "#000000", bg = "#fab387", gui = "bold" }
  },
  inactive = {
    c = { bg = "#000000" }, 
    a = { bg = "#000000", gui = "bold" }
  }
}

vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "BufferLineFill", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineBackground", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = "#dfdfdd", bg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", { bg = "#000000", fg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#20242a", nocombine = true })
vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "Visual", { fg = "#000000", bg = "#c8a4e0", nocombine = true })
vim.api.nvim_set_hl(0, "YankHighlight", { bg = "#dfdfdd", fg = "#000000", nocombine = true })

require("lualine").setup({
  options = {
    theme = zenon,
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
    modified = { fg = "#FFFFFF", bg = "#20242a" },
    modified_selected = { bg = "#000000" }
  }
})

local function apply_terminal_syntax()
  local syntax_map = {
    Comment         = term_colors.bright_black,
    String          = term_colors.magenta,
    Constant        = term_colors.white,
    Number          = term_colors.white,
    Statement       = term_colors.Magenta,
    Keyword         = term_colors.Magenta,
    Function        = term_colors.green,
    Identifier      = term_colors.green,
    Type            = term_colors.yellow,
    PreProc         = term_colors.magenta,
    Special         = term_colors.bright_red,
    Error           = term_colors.red,
    Todo            = term_colors.bright_red,
  }

  for group, color in pairs(syntax_map) do
    vim.api.nvim_set_hl(0, group, { fg = color, bg = "NONE" })
  end

  local ts_map = {
    ["@comment"]          = term_colors.bright_black,
    ["@string"]           = term_colors.yellow,
    ["@constant"]         = term_colors.bright_red,
    ["@number"]           = term_colors.yellow,
    ["@keyword"]          = term_colors.magenta,
    ["@function"]         = term_colors.cyan,
    ["@function.call"]    = term_colors.cyan,
    ["@variable"]         = term_colors.white,
    ["@type"]             = term_colors.white,
    ["@preproc"]          = term_colors.magenta,
    ["@special"]          = term_colors.red,
    ["@error"]            = term_colors.red,
  }

  for group, color in pairs(ts_map) do
    vim.api.nvim_set_hl(0, group, { fg = color, bg = "NONE" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = apply_terminal_syntax
})
apply_terminal_syntax()   
