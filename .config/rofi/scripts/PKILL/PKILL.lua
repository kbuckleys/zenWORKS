#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local HOME = os.getenv("HOME")
local THEME = HOME .. "/.config/rofi/scripts/PKILL/PKILL.rasi"
local CONFIRM_THEME = HOME .. "/.config/rofi/scripts/PKILL/PKILLOK.rasi"

local function rofi(input, args)
    local escaped = input:gsub("'", "'\\''")
    local cmd = string.format("printf '%s' | rofi %s", escaped, args)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local out = handle:read("*a")
    handle:close()
    return out and out:gsub("\n$", "") or nil
end

local function show_error(msg)
    local escaped = msg:gsub("'", "'\\''")
    os.execute(string.format(
        "rofi -e '%s' -theme '%s'",
        escaped, CONFIRM_THEME))
end

local function main()
    local ps_handle = io.popen("ps -eo pid=,user=,args= --sort=pid")
    if not ps_handle then
        show_error("Failed to list processes")
        os.exit(1)
    end

    local lines = {}
    for line in ps_handle:lines() do
        local pid, user, rest = line:match("^%s*(%S+)%s+(%S+)%s+(.*)$")
        if pid and user and rest then
            lines[#lines + 1] = string.format("%-6s %-8s %s", pid, user, rest)
        end
    end
    ps_handle:close()

    if #lines == 0 then
        show_error("No processes found")
        os.exit(1)
    end
    local formatted = table.concat(lines, "\n") .. "\n"

    local uptime_handle = io.popen("uptime -p")
    local uptime_str = uptime_handle and uptime_handle:read("*a"):gsub("^up ", ""):gsub("\n$", "") or "unknown uptime"
    if uptime_handle then uptime_handle:close() end

    local mesg = string.format("%d Processes ~ Uptime: %s", #lines, uptime_str)

    local selection = rofi(formatted, string.format(
        "-dmenu -i -p 'Kill Process' -mesg '%s' -theme '%s'", mesg, THEME))

    if not selection or selection == "" then
        os.exit(0)
    end

    local pid = selection:match("^(%d+)")
    if not pid then
        os.exit(1)
    end

    local escaped = selection:gsub("'", "'\\''")
    local confirm = rofi("Kill Process\nAbort", string.format(
        "-dmenu -p 'Confirm' -mesg '%s' -selected-row 0 -theme '%s'",
        escaped, CONFIRM_THEME))

    if confirm ~= "Kill Process" then
        return
    end

    local ret = os.execute(string.format("kill %s 2>/dev/null", pid))
    local success = (ret == true) or (ret == 0)

    if success then
        os.exit(0)
    else
        show_error(string.format("Failed to kill PID %s (permission denied?)", pid))
        os.exit(1)
    end
end

while true do
    main()
end
