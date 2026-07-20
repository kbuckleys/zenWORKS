#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- ZENU Package Manager ~ Part of the ZENWORKS Suite
-- https://github.com/kbuckleys/

local HOME = os.getenv("HOME")
local LOGO_PATH = HOME .. "/.config/logo"

local ICON_INSTALL = "󱞡"
local ICON_REMOVE  = ""

local REPO_COLORS = {
  CORE     = "\027[36m", -- cyan
  EXTRA    = "\027[32m", -- green
  MULTILIB = "\027[33m", -- yellow
  AUR      = "\027[35m", -- magenta
  LOCAL    = "\027[97m", -- white
}
local COLOR_RESET = "\027[0m"

local CACHE = {}
local function invalidate_cache()
  CACHE.available_raw  = nil
  CACHE.installed_raw  = nil
  CACHE.repo_map       = nil
  CACHE.available_pkgs = nil
  CACHE.installed_set  = nil
  CACHE.installed_pkgs = nil
end
local FZF_COLOR   = "--color=fg+:#dfdfdd,bg+:#20242a,pointer:#e0d8a4,marker:#fab387,hl+:#b6e0a4,hl::#b6e0a4,spinner:#9bbfbf,border:#20242a"

-- low level helpers

local function sh(cmd)
  -- fire-and-forget / status only
  return os.execute(cmd)
end

local function capture(cmd)
  local f = io.popen(cmd, "r")
  if not f then return "" end
  local out = f:read("*a") or ""
  f:close()
  return out
end

local function lines_of(str)
  local t = {}
  for line in str:gmatch("([^\n]*)\n?") do
    if line ~= "" then t[#t + 1] = line end
  end
  return t
end

local function write_tmp(text)
  local path = os.tmpname()
  local f = io.open(path, "w")
  f:write(text)
  f:close()
  return path
end

-- Run fzf over a list of lines with arbitrary extra args, return the
-- selection (raw string, possibly multi-line for --multi selections).
local function fzf(items, args)
  local input = type(items) == "table" and table.concat(items, "\n") or items
  local tmp = write_tmp(input)
  local out = capture("fzf " .. args .. " < " .. tmp)
  os.remove(tmp)
  return out
end

local function term_width()
  -- tput's own stdout is a pipe here (we're capturing it), not the
  -- terminal, so it can't determine the real size via ioctl and may
  -- silently fall back to a stale default. Query /dev/tty directly
  -- instead, which always refers to the actual controlling terminal.
  local out = capture("stty size < /dev/tty 2>/dev/null")
  local _, cols = out:match("(%d+)%s+(%d+)")
  local w = tonumber(cols)
  return w or 80
end

-- Centers text within a given width, using UTF-8 codepoint count (not
-- byte count) so multi-byte glyphs like the keybind icons don't throw
-- off the math. The 󰇙 separator glyph renders double-width in some
-- terminal fonts, which would otherwise make the text drift right.
local function center_text(text, width)
  local len = (utf8 and utf8.len(text)) or #text
  local _, wide_count = text:gsub("󰇙", "")
  len = len + wide_count
  local pad = math.floor((width - len) / 2)
  if pad < 0 then pad = 0 end
  return string.rep(" ", pad) .. text
end

local function show_logo()
  local f = io.open(LOGO_PATH, "r")
  if f then
    io.write(f:read("*a"), "\n")
    f:close()
  end
end

local function hard_clear()
  io.write("\027c")
  sh("stty sane 2>/dev/null")
end

-- sudo keep-alive (mirrors the background `while true; do sudo -n true...`)

local sudo_handle = nil

local function sudo_start()
  -- mirrors: if ! sudo -v 2>/dev/null; then if ! sudo -v; then ... fi; fi
  if not sh("sudo -v 2>/dev/null") then
    if not sh("sudo -v") then
      print("Auth failed.")
      os.exit(1)
    end
  end
  -- Launch a background keep-alive loop and grab its PID (first line it prints).
  sudo_handle = io.popen([[
    bash -c '
      echo $$
      while true; do
        sudo -n true 2>/dev/null
        sleep 60
        kill -0 $PPID 2>/dev/null || exit
      done
    '
  ]], "r")
end

local function sudo_stop()
  if sudo_handle then
    local pid = sudo_handle:read("*l")
    if pid then sh("kill " .. pid .. " 2>/dev/null") end
    sudo_handle:close()
    sudo_handle = nil
  end
end

-- Ensure fzf and paru/paru-git are installed

local function fzf_installed()
  return sh("pacman -Qq fzf >/dev/null 2>&1")
end

local function ensure_fzf()
  if fzf_installed() then return end
  sh("sudo pacman -S --noconfirm fzf >/dev/null 2>&1")
end

local function paru_installed()
  return sh("pacman -Qq paru >/dev/null 2>&1") or sh("pacman -Qq paru-git >/dev/null 2>&1")
end

local function ensure_paru()
  if paru_installed() then return end

  hard_clear()
  show_logo()
  print("  It seems you do not have paru installed. Please select your desired variant to proceed.")
  print("")
  local choices = { "paru (stable)", "paru-git (recommended)" }
  local args = "--no-input --layout=reverse --height=4"
  local selected = fzf(choices, args):gsub("%s+$", "")

  local pkg = "paru"
  if selected:match("^paru%-git") then
    pkg = "paru-git"
  end

  print("")
  print("Installing " .. pkg .. " ...")
  local build_dir = "/tmp/" .. pkg .. "-bootstrap"
  sh("rm -rf " .. build_dir)
  sh("git clone https://aur.archlinux.org/" .. pkg .. ".git " .. build_dir)
  sh("cd " .. build_dir .. " && makepkg -si --noconfirm")
  sh("rm -rf " .. build_dir)
end

local function sync_repos()
  sh("paru -Sy && paru --clean")
  invalidate_cache()
end

-- Update Packages

local function build_log_entries()
  local log_path = "/var/log/pacman.log"
  local f = io.open(log_path, "r")
  if not f then return {} end

  local entries = {}
  for line in f:lines() do
    if line:find("%[ALPM%] installed") or line:find("%[ALPM%] upgraded") then
      entries[#entries + 1] = line
    end
  end
  f:close()

  -- Show last 50 entries
  local start = math.max(1, #entries - 49)
  local display = {}
  for i = start, #entries do
    local e = entries[i]
    local date, action, pkg, ver = e:match("%[(.-)%]%s*%[ALPM%]%s*(%w+)%s+(.-)%s*%((.-)%)")
    if date and pkg then
      local tag = action == "upgraded" and "↑" or "+"
      display[#display + 1] = date .. "  " .. tag .. "  " .. pkg .. " " .. ver
    else
      display[#display + 1] = e
    end
  end
  return display
end

local function refresh_updates(switch_tmp)
  sync_repos()

  local raw = capture("paru -Qu --color=never | sort -u")
  local updates = lines_of(raw)

  hard_clear()

  if #updates == 0 then
    print("No updates available.")
    sh("paru --clean")
    return false
  end

  -- Recompute layout against the current terminal width so the version
  -- columns stay flush against the right edge instead of a fixed offset.
  local VER_W  = 20
  local GAP    = 3
  local MARGIN = 4 -- fzf's pointer + multi-select marker gutter (fixed now that --no-scrollbar is set)
  local W      = term_width()
  local pkg_w  = W - (VER_W * 2 + GAP + MARGIN)
  if pkg_w < 10 then pkg_w = 10 end
  if pkg_w > 99 then pkg_w = 99 end -- Lua's string.format %s width hard-caps at 99

  local row_fmt = "%-" .. pkg_w .. "s%" .. VER_W .. "s" .. string.rep(" ", GAP) .. "%" .. VER_W .. "s"

  local selection_list = {}
  for _, line in ipairs(updates) do
    local pkg, old_ver, new_ver = line:match("^(%S+)%s+(%S+)%s+%-%>%s+(%S+)")
    pkg     = pkg or line
    old_ver = old_ver or ""
    new_ver = new_ver or ""

    local pkg_display     = pkg:sub(1, pkg_w)
    local old_ver_display = old_ver:sub(1, VER_W)
    local new_ver_display = new_ver:sub(1, VER_W)

    selection_list[#selection_list + 1] =
      string.format(row_fmt, pkg_display, old_ver_display, new_ver_display)
  end

  local log_list = build_log_entries()

  local header_text = "TAB Flag  󰇙  C-a Invert  󰇙  C-d Clear  󰇙  C-r History  󰇙  C-u Manage  󰇙  RETURN Sync"
  local header_centered = center_text(header_text, W)

  local q = "'\\''"
  local updates_tmp     = write_tmp(table.concat(selection_list, "\n"))
  local log_tmp         = write_tmp(table.concat(log_list, "\n"))
  local state_tmp       = write_tmp("updates")
  -- C-r toggle: read which list is currently shown from state_tmp,
  -- flip it, and print the newly-selected list for fzf to reload from.
  local toggle_script = 'state=$(cat "' .. state_tmp .. '"); '
    .. 'if [ "$state" = "updates" ]; then echo history > "' .. state_tmp .. '"; cat "' .. log_tmp .. '"; '
    .. 'else echo updates > "' .. state_tmp .. '"; cat "' .. updates_tmp .. '"; fi'
  local toggle_cmd = "bash -c " .. q .. toggle_script .. q

  local args = table.concat({
    "--multi", "--no-input", "--no-scrollbar", FZF_COLOR,
    "--no-input",
    "--no-scrollbar",
    "--border=top",
    "--header-border=line",
    "--bind 'esc:ignore,ctrl-a:toggle-all,ctrl-d:clear-multi,ctrl-r:reload(" .. toggle_cmd .. "),ctrl-u:execute-silent(echo manage > \"" .. switch_tmp .. "\")+abort'",
    '--header="' .. header_centered .. '"',
    "--delimiter ' '",
    '--preview="paru -Si {1}"',
    '--preview-window="bottom:50%,noinfo"',
  }, " ")

  local selected_raw = capture("fzf " .. args .. " < " .. updates_tmp)
  os.remove(updates_tmp)
  os.remove(log_tmp)
  os.remove(state_tmp)

  print("")
  local installed_any = false
  if selected_raw ~= "" then
    local selected = {}
    for _, line in ipairs(lines_of(selected_raw)) do
      local pkg = line:match("^(%S+)")
      if pkg then selected[#selected + 1] = pkg end
    end
    if #selected > 0 then
      sh("paru -S --noconfirm " .. table.concat(selected, " "))
      invalidate_cache()
      installed_any = true
    end
  end

  print("Cleaning paru cache...")
  sh("paru --clean")
  return installed_any
end

-- Forward-declared so update_packages and manage_packages can call
-- each other directly (the C-u toggle between the two views).
local update_packages
local manage_packages

local function ensure_cache()
  if not CACHE.available_raw then
    CACHE.available_raw = capture("paru -Sl 2>/dev/null")
    CACHE.repo_map = {}
    CACHE.available_pkgs = {}
    for _, line in ipairs(lines_of(CACHE.available_raw)) do
      local repo, pkg = line:match("^(%S+)%s+(%S+)")
      if repo and pkg then
        CACHE.available_pkgs[#CACHE.available_pkgs + 1] = pkg
        CACHE.repo_map[pkg] = repo:upper()
      end
    end
  end
  if not CACHE.installed_raw then
    CACHE.installed_raw = capture("paru -Qq")
    CACHE.installed_set = {}
    CACHE.installed_pkgs = {}
    for _, pkg in ipairs(lines_of(CACHE.installed_raw)) do
      CACHE.installed_set[pkg] = true
      CACHE.installed_pkgs[#CACHE.installed_pkgs + 1] = pkg
    end
  end
  return CACHE.repo_map, CACHE.available_pkgs, CACHE.installed_set, CACHE.installed_pkgs
end

update_packages = function()
  local switch_tmp = write_tmp("")
  while true do
    hard_clear()
    show_logo()
    print("")
    refresh_updates(switch_tmp)

    local sf = io.open(switch_tmp, "r")
    local switch = (sf and sf:read("*a") or ""):gsub("%s+$", "")
    if sf then sf:close() end
    local wf = io.open(switch_tmp, "w")
    if wf then wf:write(""); wf:close() end

    if switch == "manage" then
      -- C-u was pressed inside the fzf list - jump straight to the
      -- package manager.
      os.remove(switch_tmp)
      manage_packages()
      return -- safety net; manage_packages() only returns via its own toggle
    end

    local choice = fzf({
      "View History",
      "Re-check for updates",
      "Return to Package Manager",
    }, table.concat({
      "--no-input",
      "--no-scrollbar",
      "--layout=reverse",
      "--height=4",
      "--border=top",
      "--info=hidden",
      FZF_COLOR,
    }, " ")):gsub("%s+$", "")

    if choice == "Return to Package Manager" then
      os.remove(switch_tmp)
      manage_packages()
      return
    elseif choice == "View History" then
      local log_list = build_log_entries()
      if #log_list == 0 then
        hard_clear()
        print("No history found.")
      else
        local W = term_width()
        local header_text = "RETURN Close"
        local header_centered = center_text(header_text, W)
        local args = table.concat({
          "--no-input",
          "--no-scrollbar",
          "--border=top",
          "--header-border=line",
          "--info=hidden",
          "--height=60%",
          "--reverse",
          FZF_COLOR,
          '--header="' .. header_centered .. '"',
        }, " ")
        fzf(log_list, args)
      end
    end
  end
end

-- Add/Remove Packages

manage_packages = function()
  sync_repos()
  hard_clear()
  local switch_tmp2 = write_tmp("")

  while true do
    local repo_map, available_pkgs, installed_set, installed_pkgs_l = ensure_cache()

    -- Right-align a colorized repo tag to the terminal edge, same
    -- treatment as the version columns in the update view.
    local REPO_W    = 8 -- fits "MULTILIB" (8 chars), the longest repo tag
    local GAP       = 1
    local ICON_PAD  = " " -- padding between icon and package name
    local ICON_W    = 1 + #ICON_PAD -- icon glyph + its padding
    local MARGIN    = 4  -- fzf's pointer + multi-select marker gutter
    local W      = term_width()
    local pkg_w  = W - MARGIN - REPO_W - GAP - ICON_W
    if pkg_w < 10 then pkg_w = 10 end
    if pkg_w > 99 then pkg_w = 99 end -- Lua's string.format %s width hard-caps at 99

    local function repo_tag(pkg)
      local repo  = repo_map[pkg] or "LOCAL"
      local plain = string.format("%" .. REPO_W .. "s", repo)
      local color = REPO_COLORS[repo] or "\027[37m"
      return color .. plain .. COLOR_RESET
    end

    local function row(icon, pkg)
      local pkg_display = string.format("%-" .. pkg_w .. "s", pkg:sub(1, pkg_w))
      return icon .. ICON_PAD .. pkg_display .. string.rep(" ", GAP) .. repo_tag(pkg)
    end

    local combined = {}
    local installed_only = {}
    for _, pkg in ipairs(available_pkgs) do
      if pkg ~= "" and not installed_set[pkg] then
        combined[#combined + 1] = row(ICON_INSTALL, pkg)
      end
    end
    for _, pkg in ipairs(installed_pkgs_l) do
      local r = row(ICON_REMOVE, pkg)
      combined[#combined + 1] = r
      installed_only[#installed_only + 1] = r
    end

    -- Strip any ANSI codes before parsing so this works whether fzf hands
    -- {} the colorized or the stripped form of the line.
    local strip_ansi = 'sed -E "s/\\x1b\\[[0-9;]*m//g"'
    local inner = 'line="$1"; clean=$(printf %s "$line" | ' .. strip_ansi .. '); '
      .. 'prefix="${clean%% *}"; rest="${clean#* }"; '
      .. 'pkg=$(printf %s "$rest" | sed -E "s/[A-Z]+[[:space:]]*$//" | xargs); '
      .. 'if [[ "$prefix" == "' .. ICON_INSTALL .. '" ]]; then paru -Si "$pkg"; else paru -Qi "$pkg"; fi'
    local q = "'\\''" -- represents the shell escape sequence '\''
    local preview_arg = "--preview='bash -c " .. q .. inner .. q .. " -- {}'"

    local header_text = "TAB Flag  󰇙  C-a Invert  󰇙  C-d Clear  󰇙  C-s Source  󰇙  C-u Update  󰇙  RETURN Sync"
    local header_centered = center_text(header_text, W)

    local full_tmp      = write_tmp(table.concat(combined, "\n"))
    local installed_tmp = write_tmp(table.concat(installed_only, "\n"))
    local state_tmp      = write_tmp("full")
    -- C-s toggle: read which list is currently shown from state_tmp,
    -- flip it, and print the newly-selected list for fzf to reload from.
    local toggle_script = 'state=$(cat "' .. state_tmp .. '"); '
      .. 'if [ "$state" = "full" ]; then echo installed > "' .. state_tmp .. '"; cat "' .. installed_tmp .. '"; '
      .. 'else echo full > "' .. state_tmp .. '"; cat "' .. full_tmp .. '"; fi'
    local toggle_cmd = "bash -c " .. q .. toggle_script .. q

    local args = table.concat({
      "--multi", "--ansi", "--nth 2", "--tiebreak=chunk,index", "--no-scrollbar", FZF_COLOR,
      "--ansi",
      "--nth 2",
      "--tiebreak=chunk,index",
      "--no-scrollbar",
      "--border=top",
      "--info=hidden",
      "--header-border=line",
      "--bind 'esc:ignore,ctrl-a:toggle-all,ctrl-d:clear-multi,ctrl-s:reload(" .. toggle_cmd .. "),ctrl-u:execute-silent(echo update > \"" .. switch_tmp2 .. "\")+abort'",
      '--header="' .. header_centered .. '"',
      '--prompt="\027[38;2;155;191;191m  > \027[0m"',
      preview_arg,
      '--preview-window="bottom:50%,noinfo"',
    }, " ")

    local selected_raw = capture("fzf " .. args .. " < " .. full_tmp)
    os.remove(full_tmp)
    os.remove(installed_tmp)
    os.remove(state_tmp)
    local sf2 = io.open(switch_tmp2, "r")
    local switch2 = (sf2 and sf2:read("*a") or ""):gsub("%s+$", "")
    if sf2 then sf2:close() end

    if switch2 == "update" then
      -- C-u was pressed inside the fzf list - reset the switch file
      -- and jump straight to the update view.
      local rf2 = io.open(switch_tmp2, "w")
      if rf2 then rf2:write(""); rf2:close() end
      update_packages()
      -- falls through: loop back and show the manage view again
    elseif selected_raw == "" then
      -- ESC/cancelled with nothing selected - just loop back and show
      -- the list again; ESC no longer quits the app.
    else
      local to_install, to_uninstall = {}, {}
      for _, raw_line in ipairs(lines_of(selected_raw)) do
        local line = raw_line:gsub("\027%[[%d;]*m", "")
        local icon, rest = line:match("^(%S+)%s+(.*)$")
        local pkg = rest
        if pkg then
          pkg = pkg:gsub("%s*%u+%s*$", ""):gsub("%s+$", "")
        end
        if icon == ICON_INSTALL then
          to_install[#to_install + 1] = pkg
        elseif icon == ICON_REMOVE then
          to_uninstall[#to_uninstall + 1] = pkg
        end
      end

      if #to_install > 0 then
        sh("paru -S " .. table.concat(to_install, " "))
      end
      if #to_uninstall > 0 then
        sh("paru -Rs --noconfirm " .. table.concat(to_uninstall, " "))
      end

      if #to_install > 0 or #to_uninstall > 0 then
        invalidate_cache()
        print("Cleaning paru cache...")
        sh("paru --clean")

        local choice = fzf({
          "Return to Package Manager",
          "Check for updates",
        }, table.concat({
          "--no-input",
          "--no-scrollbar",
          "--layout=reverse",
          "--height=4",
          "--border=top",
          "--info=hidden",
          FZF_COLOR,
        }, " ")):gsub("%s+$", "")

        hard_clear()

        if choice == "Check for updates" then
          update_packages()
        end
      end
    end
  end
end

-- Entry point

local function main()
  show_logo()
  sudo_start()
  ensure_fzf()
  ensure_paru()
  hard_clear()

  local mode = arg and arg[1]
  if mode == "update" then
    -- waybar on-click shortcut - jumps straight into the update view
    update_packages()
  else
    -- No menu anymore - Package Manager is the default landing view,
    -- reachable directly (no args, or mode == "manage"/"add-remove").
    manage_packages()
  end

end

local ok, err = pcall(main)
sudo_stop()
if not ok then
  io.stderr:write("ZENU error: " .. tostring(err) .. "\n")
  print("\027[1;31mZENU crashed - press RETURN to close.\027[0m")
  io.read("*l")
  os.exit(1)
end
