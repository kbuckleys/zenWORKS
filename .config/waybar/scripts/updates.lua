#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local ICON          = " "
local OFFICIAL_ICON = "󰣇"
local AUR_ICON      = ""
local MAX_ENTRIES      = 10     -- tooltip lines shown per section
local NOTIFY_MAX_LINES = 10     -- package names shown in the notification body
local SYNC_INTERVAL    = 3600   -- seconds between background `paru -Sy` attempts

local CACHE_DIR  = (os.getenv("XDG_CACHE_HOME") or os.getenv("HOME") .. "/.cache") .. "/waybar"
local CACHE_FILE = CACHE_DIR .. "/updates.list"
local SYNC_FILE  = CACHE_DIR .. "/last_sync"
local LOCK_FILE  = CACHE_DIR .. "/sync.lock"

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Runs cmd and returns (stdout, exit_code). Previously exit status was
-- discarded entirely, so a broken/missing tool looked identical to
-- "no output" -- which build_output silently treated as "up to date".
local function run(cmd)
    local h = io.popen(cmd .. " ; echo \"__EXIT:$?\"")
    if not h then return "", 127 end
    local out = h:read("*a")
    h:close()
    local body, code = out:match("^(.*)__EXIT:(%d+)%s*$")
    if not body then return trim(out), 0 end
    return trim(body), tonumber(code)
end

local function have(cmd)
    local out = run("command -v " .. cmd .. " 2>/dev/null")
    return out ~= ""
end

local function json_escape(s)
    return s:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
            :gsub('\t', '\\t')
            :gsub('\r', '\\r')
            :gsub('\f', '\\f')
            :gsub('\b', '\\b')
end

local function lines_of(s)
    local t = {}
    for line in s:gmatch("[^\n]+") do
        t[#t + 1] = line
    end
    return t
end

-- paru/pacman -Qu lines look like: "pkgname 1.0-1 -> 1.1-1"
-- Matching that shape (rather than just "first word on the line") means
-- a stray informational line that leaks past `2>/dev/null` gets ignored
-- instead of being miscounted as a package update.
local function extract_pkg(line)
    return line:match("^(%S+)%s+%S+%s*%-%>%s*%S+")
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

-- Resolved once, up front -- and only referenced by build_output below
-- AFTER it exists. In the original script this was declared as a
-- `local` further down the file, after build_output was defined. Lua
-- resolves free variables lexically at the point a function is
-- written, so build_output's `HAS_NOTIFY` was permanently bound to an
-- unset global, and notify-send was never actually invoked.
local HAS_NOTIFY = have("notify-send")
local HAS_PARU   = have("paru")
local HAS_FLOCK  = have("flock")

local function send_notification(official_count, aur_count, official_lines, aur_lines, total)
    local body = "Official: " .. official_count .. "\\nAUR: " .. aur_count
    local shown = 0
    for _, line in ipairs(official_lines) do
        if shown >= NOTIFY_MAX_LINES then break end
        local pkg = extract_pkg(line)
        body = body .. "\\n• " .. (pkg or line)
        shown = shown + 1
    end
    for _, line in ipairs(aur_lines) do
        if shown >= NOTIFY_MAX_LINES then break end
        local pkg = extract_pkg(line)
        body = body .. "\\n• " .. (pkg or line)
        shown = shown + 1
    end
    if total > NOTIFY_MAX_LINES then body = body .. "\\n..." end
    os.execute('notify-send "󰚰 Package Updates Available" "' .. body .. '"')
end

local function build_output(updates)
    local raw_lines = {}
    for _, line in ipairs(lines_of(updates)) do
        if line ~= "" then raw_lines[#raw_lines + 1] = line end
    end

    if #raw_lines == 0 then
        os.remove(CACHE_FILE)
        return '{"text":"","tooltip":"System is up to date","class":"none"}'
    end

    -- Only worth spawning `pacman -Qm` once we know there's at least
    -- one update to classify.
    local aur_pkgs = get_aur_pkgs()

    local official_lines = {}
    local aur_lines = {}
    for _, line in ipairs(raw_lines) do
        local pkg = extract_pkg(line)
        if pkg then
            if aur_pkgs[pkg] then
                aur_lines[#aur_lines + 1] = line
            else
                official_lines[#official_lines + 1] = line
            end
        end
    end

    -- Sort so the "did anything change" comparison below is stable
    -- even if paru's own output ordering isn't guaranteed run-to-run.
    table.sort(official_lines)
    table.sort(aur_lines)

    local official_count = #official_lines
    local aur_count = #aur_lines
    local total = official_count + aur_count

    if total == 0 then
        os.remove(CACHE_FILE)
        return '{"text":"","tooltip":"System is up to date","class":"none"}'
    end

    local canonical = table.concat(official_lines, "\n") .. "\n" .. table.concat(aur_lines, "\n")

    local cache_hit = false
    local cf = io.open(CACHE_FILE, "r")
    if cf then
        local cached = cf:read("*a")
        cf:close()
        if cached == canonical then cache_hit = true end
    end

    if not cache_hit then
        local wf = io.open(CACHE_FILE, "w")
        if wf then wf:write(canonical); wf:close() end

        if HAS_NOTIFY then
            send_notification(official_count, aur_count, official_lines, aur_lines, total)
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

if not HAS_PARU then
    print(string.format('{"text":"%s !","tooltip":"paru not found in PATH","class":"error"}', ICON))
    io.stdout:flush()
    os.exit(0)
end

local updates, exit_code = run("paru -Qu --color=never 2>/dev/null")

-- pacman/paru exit 1 just means "nothing to update" -- that's normal,
-- not a failure. Anything else (2+, or the shell itself failing to
-- launch) means the check broke, so surface that instead of silently
-- reporting "up to date" and hiding real updates.
if exit_code ~= 0 and exit_code ~= 1 then
    print(string.format('{"text":"%s !","tooltip":"paru -Qu failed (exit %d)","class":"error"}', ICON, exit_code))
    io.stdout:flush()
    os.exit(0)
end

local output = build_output(updates)
print(output)
io.stdout:flush()

-- Sync handling: don't hammer the network/db on every waybar poll, but
-- also don't let a failed sync silently freeze the "last synced" clock.
-- Only a *successful* background sync writes SYNC_FILE (the background
-- job does this itself, after `paru -Sy` succeeds), so a network
-- hiccup gets retried on the very next run instead of waiting out a
-- full interval for nothing. flock (if available) also stops two
-- overlapping sync jobs from racing if the previous one is still
-- running when this one fires.
local should_sync = true
local sf = io.open(SYNC_FILE, "r")
if sf then
    local last_sync = tonumber(sf:read("*a"))
    sf:close()
    if last_sync and (os.time() - last_sync) < SYNC_INTERVAL then
        should_sync = false
    end
end

if should_sync then
    local sync_cmd
    if HAS_FLOCK then
        sync_cmd = string.format(
            "( flock -n '%s' -c \"timeout 10 paru -Sy --quiet 2>/dev/null && date +%%s > '%s'\" ) &",
            LOCK_FILE, SYNC_FILE)
    else
        sync_cmd = string.format(
            "( timeout 10 paru -Sy --quiet 2>/dev/null && date +%%s > '%s' ) &",
            SYNC_FILE)
    end
    os.execute(sync_cmd)
end
