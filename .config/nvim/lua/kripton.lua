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

local hl = vim.api.nvim_set_hl

vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "BufferLineFill", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineBackground", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = "#dfdfdd", bg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", { bg = "#000000", fg = "#000000", nocombine = true })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#20242a", nocombine = true })
vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = "#20242a" })
vim.api.nvim_set_hl(0, "Visual", { fg = "#000000", bg = "#fab387", nocombine = true })
vim.api.nvim_set_hl(0, "YankHighlight", { bg = "#dfdfdd", fg = "#000000", nocombine = true })

-- Basics
hl(0, "@comment", { fg = "#9bbfbf" })
hl(0, "@string", { fg = "#e0d8a4" })
hl(0, "@string.regex", { fg = "#fab387" })
hl(0, "@string.escape", { fg = "#e78284" })
hl(0, "@number", { fg = "#c8a4e0" })
hl(0, "@boolean", { fg = "#eebebe" })
hl(0, "@keyword", { fg = "#eebebe" })
hl(0, "@operator", { fg = "#eebebe" })
hl(0, "@punctuation.bracket", { fg = "#dfdfdd" })
hl(0, "@punctuation.delimiter", { fg = "#dfdfdd" })
hl(0, "@punctuation.special", { fg = "#eebebe" })

-- Identifiers
hl(0, "@variable", { fg = "#dfdfdd" })
hl(0, "@variable.builtin", { fg = "#eebebe", italic = true })
hl(0, "@variable.parameter", { fg = "#fab387" })
hl(0, "@variable.member", { fg = "#e0d8a4" })
hl(0, "@constant", { fg = "#c8a4e0" })
hl(0, "@constant.builtin", { fg = "#c8a4e0", italic = true })
hl(0, "@constant.macro", { fg = "#c8a4e0" })
hl(0, "@module", { fg = "#9bbfbf" })
hl(0, "@label", { fg = "#c8a4e0" })

-- Functions & Types
hl(0, "@function", { fg = "#b6e0a4" })
hl(0, "@function.builtin", { fg = "#b6e0a4", italic = true })
hl(0, "@function.call", { fg = "#b6e0a4" })
hl(0, "@function.macro", { fg = "#b6e0a4" })
hl(0, "@method", { fg = "#b6e0a4" })
hl(0, "@method.call", { fg = "#b6e0a4" })
hl(0, "@constructor", { fg = "#9bbfbf" })
hl(0, "@type", { fg = "#9bbfbf" })
hl(0, "@type.builtin", { fg = "#9bbfbf", italic = true })
hl(0, "@type.definition", { fg = "#9bbfbf", bold = true })
hl(0, "@type.qualifier", { fg = "#eebebe" })
hl(0, "@storageclass", { fg = "#eebebe" })
hl(0, "@structure", { fg = "#9bbfbf" })
hl(0, "@namespace", { fg = "#9bbfbf" })
hl(0, "@include", { fg = "#eebebe" })

-- Control Flow
hl(0, "@conditional", { fg = "#eebebe" })
hl(0, "@repeat", { fg = "#eebebe" })
hl(0, "@debug", { fg = "#e78284" })
hl(0, "@exception", { fg = "#e78284" })
hl(0, "@preproc", { fg = "#eebebe" })
hl(0, "@define", { fg = "#eebebe" })

-- Text & Markup
hl(0, "@text", { fg = "#dfdfdd" })
hl(0, "@text.strong", { fg = "#dfdfdd", bold = true })
hl(0, "@text.emphasis", { fg = "#dfdfdd", italic = true })
hl(0, "@text.underline", { fg = "#dfdfdd", underline = true })
hl(0, "@text.strike", { fg = "#dfdfdd", strikethrough = true })
hl(0, "@text.title", { fg = "#c8a4e0", bold = true })
hl(0, "@text.literal", { fg = "#e0d8a4" })
hl(0, "@text.reference", { fg = "#9bbfbf", underline = true })
hl(0, "@text.uri", { fg = "#9bbfbf", italic = true, underline = true })
hl(0, "@text.todo", { fg = "#e78284", bold = true })
hl(0, "@text.note", { fg = "#9bbfbf", italic = true })
hl(0, "@text.warning", { fg = "#fab387", bold = true })
hl(0, "@text.danger", { fg = "#e78284", bold = true })
hl(0, "@text.diff.add", { fg = "#b6e0a4" })
hl(0, "@text.diff.delete", { fg = "#e78284" })

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
