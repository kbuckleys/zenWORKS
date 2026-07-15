-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local M = {}

-- Tracks the currently open picker's window/buffer to guard
-- against stacking multiple floats on top of each other.
local state = { win = nil, buf = nil }

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
  bright_green    = "#c1e8ac",
  bright_yellow   = "#e0d8a4",
  bright_blue     = "#b3d4fd",
  bright_magenta  = "#d4b7e8",
  bright_cyan     = "#a8caca",
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
  return vim.o.background == "light" and "GitHub" or "ansi"
end

local function win_geometry()
  local width = math.min(100, vim.o.columns - 4)
  local height = math.floor(vim.o.lines * 0.9)
  return {
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  for _, exe in ipairs({ "fzf", "find" }) do
    if vim.fn.executable(exe) ~= 1 then
      vim.notify(("fzf.lua: required executable '%s' not found"):format(exe), vim.log.levels.ERROR)
      return
    end
  end
  local has_bat = vim.fn.executable("bat") == 1

  local tmpfile = vim.fn.tempname()
  local root = "~"

  local geo = win_geometry()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = geo.width,
    height = geo.height,
    row = geo.row,
    col = geo.col,
    style = "minimal",
    border = "single",
  })
  state.win, state.buf = win, buf

  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder,NormalFloat:Normal"

  -- Recenter/resize on terminal resize
  local group = vim.api.nvim_create_augroup("FzfFloatResize", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        local g = win_geometry()
        vim.api.nvim_win_set_config(win, {
          relative = "editor",
          width = g.width,
          height = g.height,
          row = g.row,
          col = g.col,
        })
      end
    end,
  })

  local fzf_colors = build_fzf_colors()
  local preview_cmd = has_bat
      and string.format("bat --theme=%s --style=numbers --color=always {} 2>/dev/null || cat {}", bat_theme())
    or "cat {}"

  local cmd = string.format(
    "find %s "
      .. "-path /proc -prune -o "
      .. "-path /sys -prune -o "
      .. "-path /dev -prune -o "
      .. "-path /run -prune -o "
      .. "-path /snap -prune -o "
      .. "-name .git -prune -o "
      .. "-name node_modules -prune -o "
      .. "-name .cache -prune -o "
      .. "-type f -print 2>/dev/null | "
      .. "FZF_DEFAULT_OPTS=\"--color=%s\" fzf -m "
      .. "--preview '%s' "
      .. "--preview-window=down:60%% > %s",
    root,
    fzf_colors,
    preview_cmd,
    tmpfile
  )

  local function cleanup()
    pcall(vim.api.nvim_del_augroup_by_id, group)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    if state.win == win then
      state.win, state.buf = nil, nil
    end
  end

  local job_id = vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      cleanup()
      local lines = vim.fn.readfile(tmpfile)
      vim.fn.delete(tmpfile)
      for _, path in ipairs(lines) do
        if path ~= "" then
          vim.cmd("edit " .. vim.fn.fnameescape(path))
        end
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("fzf.lua: failed to start fzf job", vim.log.levels.ERROR)
    cleanup()
    vim.fn.delete(tmpfile)
    return
  end

  vim.cmd("startinsert")
end

return M
