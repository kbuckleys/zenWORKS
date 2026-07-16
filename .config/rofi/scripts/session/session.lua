#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local entries = {
  { id="lockscreen", label="Lock", cmd="hyprlock", confirm=false },
  { id="kill", label="Kill", cmd=os.getenv("HOME").."/.config/rofi/scripts/PKILL/PKILL.lua", confirm=false },
  { id="suspend", label="Suspend", cmd="systemctl suspend", confirm=false },
  { id="logout", label="Logout", cmd="hyprshutdown -p 'loginctl terminate-session " .. (os.getenv("XDG_SESSION_ID") or "") .. "'", confirm=true },
  { id="reboot", label="Reboot", cmd="hyprshutdown -p 'systemctl reboot'", confirm=true },
  { id="shutdown", label="Shutdown", cmd="hyprshutdown -p 'systemctl poweroff'", confirm=true },
}

local dryrun = false
local args = { ... }

if #args >= 1 and args[1] == "--dry-run" then
  dryrun = true
  table.remove(args, 1)
end

local CANCEL = '<span font_size="medium">CANCEL</span>'

local function row(label)
  return string.format('<span font_size="medium">%s</span>', label)
end

local function confirm_row(label)
  return string.format('<span font_size="medium">Confirm %s</span>', label)
end

local function shell_quote(s)
  return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function execute(id, cmd)
  if dryrun then
    io.stderr:write("Selected: " .. id .. "\n")
    return
  end
  if id == "kill" then
    os.execute("setsid " .. shell_quote(cmd) .. " >/dev/null 2>&1 &")
  else
    os.execute(cmd .. " >/dev/null 2>&1 &")
  end
end

print("\0no-custom\x1ftrue")
print("\0markup-rows\x1ftrue")

local selection = table.concat(args, " ")

if selection == "" then
  print("\0prompt\x1fPower Menu")
  for _, e in ipairs(entries) do
    print(row(e.label))
  end
  os.exit(0)
end

for _, e in ipairs(entries) do
  if selection == row(e.label) then
    if e.id == "lockscreen" or not e.confirm then
      execute(e.id, e.cmd)
    else
      print("\0prompt\x1fAre you sure?")
      print(confirm_row(e.label))
      print(CANCEL)
    end
    os.exit(0)
  end

  if e.confirm and selection == confirm_row(e.label) then
    execute(e.id, e.cmd)
    os.exit(0)
  end
end

if selection == CANCEL then os.exit(0) end
io.stderr:write("Invalid selection: " .. selection .. "\n")
os.exit(1)
