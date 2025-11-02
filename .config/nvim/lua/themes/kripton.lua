-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local M = {}

local colors = {
  black = "#000000",
  red = "#e0aea4",
  green = "#b6e0a4",
  yellow = "#e0d8a4",
  blue = "#9BB1BF",
  magenta = "#c8a4e0",
  cyan = "#9bbfbf",
  white = "#dfdfdd",
  gray = "#6C7887",
}

function M.setup()
  vim.cmd("hi clear")

  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  vim.o.background = "dark"
  vim.o.termguicolors = true

  local hi = function(name, opts)
    local cmd = "hi " .. name

    if opts.fg then
      cmd = cmd .. " guifg=" .. opts.fg
    end

    if opts.bg then
      cmd = cmd .. " guibg=" .. opts.bg
    end

    if opts.gui then
      cmd = cmd .. " gui=" .. opts.gui
    end

    vim.cmd(cmd)
  end

  hi("Normal", { fg = colors.white, bg = colors.black })
  hi("Comment", { fg = colors.gray, gui = "italic" })

  hi("Constant", { fg = colors.green })
  hi("String", { fg = colors.green })
  hi("Character", { fg = colors.white })
  hi("Number", { fg = colors.yellow })
  hi("Boolean", { fg = colors.yellow })

  hi("Identifier", { fg = colors.blue })
  hi("Function", { fg = colors.blue })

  hi("Statement", { fg = colors.red, gui = "bold" })
  hi("Conditional", { fg = colors.red, gui = "bold" })
  hi("Repeat", { fg = colors.red, gui = "bold" })

  hi("Label", { fg = colors.red })
  hi("Operator", { fg = colors.cyan })

  hi("Keyword", { fg = colors.magenta, gui = "bold" })
  hi("PreProc", { fg = colors.green })
  hi("Type", { fg = colors.yellow })
  hi("Special", { fg = colors.cyan, gui = "bold" })

  hi("Underlined", { fg = colors.blue, gui = "underline" })

  hi("Error", { fg = colors.red, gui = "bold" })
  hi("Todo", { fg = colors.magenta, gui = "bold" })

  hi("VertSplit", { fg = colors.red, bg = colors.black })
  hi("FloatBorder", { fg = colors.cyan, bg = colors.black })

  hi("CursorLine", { bg = "#1a1a1a" })
  hi("LineNr", { fg = colors.gray, bg = colors.black })
  hi("CursorLineNr", { fg = colors.cyan, bg = "#1a1a1a", gui = "bold" })

  hi("Pmenu", { fg = colors.cyan, bg = colors.green })
  hi("PmenuSel", { fg = colors.cyan, bg = colors.yellow })

  hi("StatusLineSeparator", { fg = colors.red, bg = colors.black })

  vim.cmd([[
    hi StatusLine    guifg=]] .. colors.black .. [[ guibg=]] .. colors.red .. [[ gui=bold
    hi StatusLineNC  guifg=]] .. colors.white .. [[ guibg=]] .. colors.black .. [[
  ]])
end

M.lualine_theme = {
  normal = {
    a = { fg = colors.black, bg = colors.red, gui = "bold" },
    b = { fg = colors.cyan, bg = colors.red },
    c = { fg = colors.red, bg = colors.black },
    x = { fg = colors.white, bg = colors.black },
    y = { fg = colors.white, bg = colors.black },
    z = { fg = colors.red, bg = colors.black },
  },
  insert = {
    a = { fg = colors.black, bg = colors.green, gui = "bold" },
    b = { fg = colors.white, bg = colors.green },
    c = { fg = colors.green, bg = colors.black },
    x = { fg = colors.white, bg = colors.black },
    y = { fg = colors.white, bg = colors.black },
    z = { fg = colors.green, bg = colors.black },
  },
  visual = {
    a = { fg = colors.black, bg = colors.yellow, gui = "bold" },
    b = { fg = colors.white, bg = colors.yellow },
    c = { fg = colors.yellow, bg = colors.black },
    x = { fg = colors.white, bg = colors.black },
    y = { fg = colors.white, bg = colors.black },
    z = { fg = colors.yellow, bg = colors.black },
  },
  replace = {
    a = { fg = colors.black, bg = colors.magenta, gui = "bold" },
    b = { fg = colors.white, bg = colors.magenta },
    c = { fg = colors.magenta, bg = colors.black },
    x = { fg = colors.white, bg = colors.black },
    y = { fg = colors.white, bg = colors.black },
    z = { fg = colors.magenta, bg = colors.black },
  },
  command = {
    a = { fg = colors.black, bg = colors.blue, gui = "bold" },
    b = { fg = colors.white, bg = colors.blue },
    c = { fg = colors.blue, bg = colors.black },
    x = { fg = colors.white, bg = colors.black },
    y = { fg = colors.white, bg = colors.black },
    z = { fg = colors.blue, bg = colors.black },
  },
  inactive = {
    a = { fg = colors.red, bg = colors.black, gui = "bold" },
    b = { fg = colors.white, bg = colors.black },
    c = { fg = colors.white, bg = colors.black },
    x = { fg = colors.white, bg = colors.black },
    y = { fg = colors.white, bg = colors.black },
    z = { fg = colors.white, bg = colors.black },
  },
}

return M
