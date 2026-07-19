#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local HOME = os.getenv("HOME")
local SHELL = os.getenv("SHELL") or "/bin/bash"
local THEME = HOME .. "/.config/rofi/scripts/RUN/RUN.rasi"
local MODE_THEME = HOME .. "/.config/rofi/scripts/RUN/RUNOK.rasi"
local HIST_FILE = HOME .. "/.cache/rofi-run-history"
local HIST_MAX = 100

local ICON_T = string.char(0xEE, 0xAA, 0x85)
local ICON_P = string.char(0xF3, 0xB0, 0x98, 0x94)
local ICON_B = string.char(0xEE, 0xB8, 0xA3)

local function strip_prefix(s)
    local _, pos = s:find("  ", 1, true)
    if pos then return s:sub(pos + 1) end
    return s
end

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function rofi(input, args)
    local cmd = string.format(
        "echo -ne %s | rofi %s; echo \"__EXIT:$?\"",
        shell_quote(input), args)
    local handle = io.popen(cmd)
    if not handle then return nil, -1 end
    local out = handle:read("*a")
    handle:close()
    if not out then return nil, -1 end
    local exit_code = tonumber(out:match("__EXIT:(%d+)")) or -1
    local result = out:gsub("__EXIT:%d+\n?$", ""):gsub("\n$", "")
    if result == "" then return nil, exit_code end
    return result, exit_code
end

local function read_history()
    local f = io.open(HIST_FILE, "r")
    if not f then return {} end
    local lines = {}
    for line in f:lines() do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    f:close()
    return lines
end

local function add_to_history(entry, mode)
    local hist = read_history()
    local tag = mode == "Terminal" and ICON_T or ICON_P
    local formatted = tag .. "  " .. entry
    local filtered = {}
    for _, e in ipairs(hist) do
        if e ~= formatted then
            filtered[#filtered + 1] = e
        end
    end
    table.insert(filtered, 1, formatted)
    while #filtered > HIST_MAX do
        table.remove(filtered)
    end
    local f = io.open(HIST_FILE, "w")
    if not f then return end
    for _, e in ipairs(filtered) do
        f:write(e .. "\n")
    end
    f:close()
end

local function delete_from_history(entry)
    local hist = read_history()
    local filtered = {}
    for _, e in ipairs(hist) do
        if e ~= entry then
            filtered[#filtered + 1] = e
        end
    end
    local f = io.open(HIST_FILE, "w")
    if not f then return end
    for _, e in ipairs(filtered) do
        f:write(e .. "\n")
    end
    f:close()
end

local function run(mode, cmd)
    add_to_history(cmd, mode)
    local quoted = shell_quote(cmd)
    if mode == "Terminal" then
        os.execute(string.format(
            "setsid kitty -1 --detach --hold %s -i -c %s >/dev/null 2>&1",
            SHELL, quoted))
    elseif mode == "Process" then
        os.execute(string.format(
            "setsid %s -i -c %s >/dev/null 2>&1",
            SHELL, quoted))
    end
end

local function prompt_run()
    local hist = read_history()
    local hist_input = table.concat(hist, "\n")
    local raw, exit_code = rofi(hist_input, string.format(
        "-dmenu -no-auto-select -i -p 'Run' -kb-accept-custom 'Alt+Return' -kb-custom-1 'Alt+Delete' -theme '%s'", THEME))

    if not raw or raw == "" then
        if exit_code == 10 then
            return
        end
        os.exit(0)
    end

    if exit_code == 10 then
        delete_from_history(raw)
        return
    end

    if raw:sub(1, #ICON_T) == ICON_T then
        run("Terminal", raw:sub(#ICON_T + 3))
        os.exit(0)
    elseif raw:sub(1, #ICON_P) == ICON_P then
        run("Process", raw:sub(#ICON_P + 3))
        os.exit(0)
    end

    local mesg_escaped = raw:gsub("'", "'\\''")
    local term_label = ICON_T .. "  Terminal"
    local process_label = ICON_P .. "  Process"
    local back_label = ICON_B .. "  Back"
    local mode = rofi(term_label .. "\n" .. process_label .. "\n" .. back_label, string.format(
        "-dmenu -p 'Mode' -mesg '%s' -selected-row 0 -theme '%s'",
        mesg_escaped, MODE_THEME))

    if not mode or mode == "" then
        return
    end

    mode = strip_prefix(mode)
    if mode == "Back" then
        return
    end

    run(mode, raw)
    os.exit(0)
end

while true do
    prompt_run()
end
