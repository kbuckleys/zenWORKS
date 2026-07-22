-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

vim.opt.termguicolors = true
vim.opt.background = "dark"

local term_colors = {
  black           = "#000000",
  lblack          = "#20242a",
  red             = "#e78284",
  green           = "#b6e0a4",
  yellow          = "#fab387",
  blue            = "#9fcbfc",
  magenta         = "#c8a4e0",
  cyan            = "#9bbfbf",
  white           = "#dfdfdd",
  bright_black    = "#6a707f",
  bright_red      = "#eebebe",
  bright_green    = "#b6e0a4",
  bright_yellow   = "#e0d8a4",
  bright_blue     = "#9fcbfc",
  bright_magenta  = "#c8a4e0",
  bright_cyan     = "#9bbfbf",
  bright_white    = "#dfdfdd",
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

-- UI
vim.api.nvim_set_hl(0, "YankHighlight", { fg = "#000000", bg = "#eebebe", nocombine = true })
vim.api.nvim_set_hl(0, "Visual", { fg = "#000000", bg = "#c8a4e0", nocombine = true })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#20242a", nocombine = true })
vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#20242a", bg = "#20242a" })

-- Bufferline
vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", { fg = "#000000", bg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = "#dfdfdd", bg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "BufferLineBackground", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineFill", { bg = "#20242a" })

-- Searching
vim.api.nvim_set_hl(0, "CurSearch", { fg = "#000000", bg = "#e78284", bold = true, nocombine = true, })
vim.api.nvim_set_hl(0, "Search", { fg = "#000000", bg = "#eebebe", nocombine = true, })
vim.api.nvim_set_hl(0, "IncSearch", { fg = "#000000", bg = "#e78284" })

-- Matching
vim.api.nvim_set_hl(0, "Substitute", { fg = "#000000", bg = "#e78284" })

-- Completion
vim.api.nvim_set_hl(0, "PmenuSel", { fg = "#000000", bg = "#b6e0a4" })
vim.api.nvim_set_hl(0, "Pmenu", { fg = "#dfdfdd", bg = "#20242a" })

-- Diagnostics
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = "#e78284", bg = "NONE" })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn", { fg = "#fab387", bg = "NONE" })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo", { fg = "#eebebe", bg = "NONE" })
vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint", { fg = "#9bbfbf", bg = "NONE" })

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
    String          = term_colors.yellow,
    Constant        = term_colors.bright_red,
    Number          = term_colors.yellow,
    Boolean         = term_colors.bright_red,
    Character       = term_colors.yellow,

    Statement       = term_colors.magenta,
    Keyword         = term_colors.magenta,
    Conditional     = term_colors.magenta,
    Repeat          = term_colors.magenta,
    Label           = term_colors.magenta,
    Operator        = term_colors.magenta,

    Function        = term_colors.green,
    Identifier      = term_colors.green,

    Type            = term_colors.cyan,
    StorageClass    = term_colors.cyan,
    Structure       = term_colors.cyan,
    Typedef         = term_colors.cyan,

    PreProc         = term_colors.magenta,
    Include         = term_colors.magenta,
    Define          = term_colors.magenta,
    Macro           = term_colors.magenta,

    Special         = term_colors.bright_red,
    SpecialChar     = term_colors.bright_red,

    Error           = term_colors.red,
    Todo            = term_colors.bright_red,
  }

  for group, color in pairs(syntax_map) do
    vim.api.nvim_set_hl(0, group, { fg = color, bg = "NONE" })
  end

  local ts_map = {
    ["@comment"]              = term_colors.bright_black,

    ["@string"]               = term_colors.cyan,
    ["@string.escape"]        = term_colors.cyan,
    ["@character"]            = term_colors.cyan,

    ["@constant"]             = term_colors.bright_red,
    ["@constant.builtin"]     = term_colors.bright_red,
    ["@number"]               = term_colors.yellow,
    ["@boolean"]              = term_colors.bright_red,

    ["@keyword"]              = term_colors.magenta,
    ["@keyword.function"]     = term_colors.magenta,
    ["@keyword.return"]       = term_colors.magenta,
    ["@conditional"]          = term_colors.magenta,
    ["@repeat"]               = term_colors.magenta,
    ["@operator"]             = term_colors.magenta,
    ["@preproc"]              = term_colors.magenta,

    ["@function"]             = term_colors.green,
    ["@function.call"]        = term_colors.green,
    ["@function.method"]      = term_colors.green,
    ["@function.method.call"] = term_colors.green,
    ["@constructor"]          = term_colors.green,

    ["@variable"]             = term_colors.white,
    ["@parameter"]            = term_colors.white,
    ["@field"]                = term_colors.white,
    ["@property"]             = term_colors.white,
    ["@punctuation"]          = term_colors.white,

    ["@type"]                 = term_colors.yellow,
    ["@type.builtin"]         = term_colors.yellow,
    ["@module"]               = term_colors.yellow,
    ["@namespace"]            = term_colors.yellow,

    ["@special"]              = term_colors.bright_red,
    ["@error"]                = term_colors.red,
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
