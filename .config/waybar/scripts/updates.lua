#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local ICON          = " "
local OFFICIAL_ICON = "󰣇"
local AUR_ICON      = ""
local MAX_ENTRIES   = 10
local INTERVAL      = 300

local CACHE_DIR  = (os.getenv("XDG_CACHE_HOME") or os.getenv("HOME") .. "/.cache") .. "/waybar"
local CACHE_FILE = CACHE_DIR .. "/updates.list"

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function run(cmd)
    local h = io.popen(cmd)
    if not h then return "" end
    local r = trim(h:read("*a"))
    h:close()
    return r
end

local function have(cmd)
    return run("command -v " .. cmd .. " 2>/dev/null") ~= ""
end

local function json_escape(s)
    return s:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
end

local function lines_of(s)
    local t = {}
    for line in s:gmatch("[^\n]+") do
        t[#t + 1] = line
    end
    return t
end

local function get_aur_pkgs()
    local pkgs = {}
    local out = run("pacman -Qm 2>/dev/null")
    for line in out:gmatch("[^\n]+") do
        local pkg = line:match("^(%S+)")
        if pkg then pkgs[pkg] = true end
    end
    return pkgs
end

local function build_output(updates)
    local aur_pkgs = get_aur_pkgs()

    local official_lines = {}
    local aur_lines = {}
    for _, line in ipairs(lines_of(updates)) do
        if line ~= "" then
            local pkg = line:match("^(%S+)")
            if aur_pkgs[pkg] then
                aur_lines[#aur_lines + 1] = line
            else
                official_lines[#official_lines + 1] = line
            end
        end
    end

    local official_count = #official_lines
    local aur_count = #aur_lines
    local total = official_count + aur_count

    if total == 0 then
        os.remove(CACHE_FILE)
        return '{"text":"","tooltip":"System is up to date","class":"none"}'
    end

    local cache_hit = false
    local cf = io.open(CACHE_FILE, "r")
    if cf then
        local cached = cf:read("*a")
        cf:close()
        if cached == updates then cache_hit = true end
    end

    if not cache_hit then
        local wf = io.open(CACHE_FILE, "w")
        if wf then wf:write(updates); wf:close() end

        if HAS_NOTIFY then
            local body = "Official: " .. official_count .. "\\nAUR: " .. aur_count
            local shown = 0
            for _, line in ipairs(official_lines) do
                local pkg = line:match("^(%S+)")
                body = body .. "\\n• " .. pkg
                shown = shown + 1
                if shown >= 10 then break end
            end
            for _, line in ipairs(aur_lines) do
                if shown >= 10 then break end
                local pkg = line:match("^(%S+)")
                body = body .. "\\n• " .. pkg
                shown = shown + 1
            end
            if total > 10 then body = body .. "\\n..." end
            os.execute('notify-send "󰚰 Package Updates Available" "' .. body .. '"')
        end
    end

    local tooltip = ""

    if official_count > 0 then
        tooltip = OFFICIAL_ICON .. " " .. official_count .. "\n"
        local shown = 0
        for _, line in ipairs(official_lines) do
            tooltip = tooltip .. line .. "\n"
            shown = shown + 1
            if shown >= MAX_ENTRIES then break end
        end
        if official_count > MAX_ENTRIES then tooltip = tooltip .. "...\n" end
        if aur_count > 0 then tooltip = tooltip .. "\n" end
    end

    if aur_count > 0 then
        tooltip = tooltip .. AUR_ICON .. " " .. aur_count .. "\n"
        local shown = 0
        for _, line in ipairs(aur_lines) do
            tooltip = tooltip .. line .. "\n"
            shown = shown + 1
            if shown >= MAX_ENTRIES then break end
        end
        if aur_count > MAX_ENTRIES then tooltip = tooltip .. "..." end
    end

    tooltip = tooltip:match("^(.-)\n$") or tooltip

    return string.format('{"text":"%s %d","tooltip":"%s","class":"updates"}',
        ICON, total, json_escape(tooltip))
end

os.execute("mkdir -p " .. CACHE_DIR)

local HAS_NOTIFY = have("notify-send")
local last_output = nil

while true do
    local updates = run("paru -Qu 2>/dev/null || true")
    local output = build_output(updates)
    if output ~= last_output then
        print(output)
        io.stdout:flush()
        last_output = output
    end
    os.execute("sleep " .. INTERVAL)
end
