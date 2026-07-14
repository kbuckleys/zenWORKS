-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local M = {}

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

local function build_fzf_colors()
    return table.concat({
      "fg:"        .. term_colors.white,
      "bg:"        .. term_colors.black,
      "fg+:"       .. term_colors.green,
      "bg+:"       .. term_colors.black,
      "hl:"        .. term_colors.yellow,
      "hl+:"       .. term_colors.yellow,
      "prompt:"    .. term_colors.green,
      "pointer:"   .. term_colors.green,
      "marker:"    .. term_colors.magenta,
      "spinner:"   .. term_colors.bright_red,
      "info:"      .. term_colors.bright_red,
      "header:"    .. term_colors.magenta,
      "border:"    .. term_colors.black,
      "label:"     .. term_colors.green,
      "query:"     .. term_colors.white,
      "separator:" .. term_colors.lblack,
      "scrollbar:" .. term_colors.bright_black,
    }, ",")
end

local function bat_theme()
  -- crude but effective: match bat's theme to light/dark background
  return vim.o.background == "light" and "GitHub" or "ansi"
end

function M.open()
  local tmpfile = vim.fn.tempname()
  local root = "/"

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "single",
  })

  -- Make the float's own bg/border follow your colorscheme instead of defaults
  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder,NormalFloat:Normal"

  local fzf_colors = build_fzf_colors()

  local cmd = string.format(
    "find %s "
      .. "-path /proc -prune -o "
      .. "-path /sys -prune -o "
      .. "-path /dev -prune -o "
      .. "-path /run -prune -o "
      .. "-path /snap -prune -o "
      .. "-type f -print 2>/dev/null | "
      .. "FZF_DEFAULT_OPTS=\"--color=%s\" fzf "
      .. "--preview 'bat --theme=%s --style=numbers --color=always {} 2>/dev/null || cat {}' "
      .. "--preview-window=down:60%% > %s",
    root,
    fzf_colors,
    bat_theme(),
    tmpfile
  )

  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      local lines = vim.fn.readfile(tmpfile)
      vim.fn.delete(tmpfile)
      if lines[1] and lines[1] ~= "" then
        vim.cmd("edit " .. vim.fn.fnameescape(lines[1]))
      end
    end,
  })

  vim.cmd("startinsert")
end

return M
