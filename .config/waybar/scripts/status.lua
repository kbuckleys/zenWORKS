#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local ICON  = { mic = "", cam = "", loc = "", scr = "", rec = "" }
local COLOR = { mic = "#b6e0a4", cam = "#fab387", loc = "#9bbfbf", scr = "#c8a4e0", rec = "#e78284" }
local LABEL = { mic = "Mic", cam = "Cam", loc = "Location", scr = "Screen sharing", rec = "Recording" }
local KEYS  = { "mic", "cam", "loc", "scr", "rec" }

local STATE = {}
local APP   = {}

local CACHE = {}

local function _getpid()
    local f = io.open("/proc/self/stat")
    if not f then return 0 end
    local pid = f:read("*a"):match("^(%d+)")
    f:close()
    return tonumber(pid) or 0
end
local _tmplock = _getpid()
local _tmp_n   = 0

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function pango_escape(s)
    return s:gsub('&', '&amp;')
            :gsub('<', '&lt;')
            :gsub('>', '&gt;')
end

local function run(cmd)
    local h = io.popen(cmd)
    if not h then return "", false end
    local r = trim(h:read("*a"))
    local ok = h:close()
    return r, ok ~= nil
end

local function have(cmd)
    if CACHE[cmd] == nil then
        local _, ok = run("command -v " .. cmd .. " 2>/dev/null")
        CACHE[cmd] = ok
    end
    return CACHE[cmd]
end

local function append_app(key, value)
    if not value or value == "" then return end
    local prev = APP[key]
    if prev and prev ~= "" then
        APP[key] = prev .. ", " .. value
    else
        APP[key] = value
    end
end

local function batch_app(key, pids)
    if #pids == 0 then return end
    local joined = table.concat(pids, ",")
    local out = run("ps -p " .. joined .. " -o comm= 2>/dev/null")
    for comm in out:gmatch("[^\n]+") do
        append_app(key, trim(comm))
    end
end

local function detect_process(proc, key)
    if not have("pgrep") then return end
    local pids = run("pgrep -x " .. proc .. " 2>/dev/null")
    if pids == "" then return end
    STATE[key] = true
    local plist = {}
    for pid in pids:gmatch("%d+") do
        plist[#plist + 1] = pid
    end
    batch_app(key, plist)
end

local function with_tmpfile(content, fn)
    _tmp_n = _tmp_n + 1
    local path = string.format("/tmp/lua_status_%d_%d", _tmplock, _tmp_n)
    local f = io.open(path, "w")
    f:write(content)
    f:close()
    local ok, result = pcall(fn, path)
    os.remove(path)
    if not ok then error(result) end
    return result
end

local function jq(datafile, filter)
    return with_tmpfile(filter, function(filterfile)
        return run(string.format("jq -r -f '%s' '%s'", filterfile, datafile))
    end)
end

-- PipeWire
if have("pw-dump") and have("jq") then
    local dump, ok = run("pw-dump 2>/dev/null")
    if ok and dump ~= "" then
        with_tmpfile(dump, function(dumpfile)
            local out = jq(dumpfile, [==[
                (any(.[]; .type=="PipeWire:Interface:Node"
                    and (.info.props."media.class"=="Audio/Source"
                        or .info.props."media.class"=="Audio/Source/Virtual")
                    and (.info.state=="running" or .state=="running"))) as $mic
                | ([.[] | select(.type=="PipeWire:Interface:Node")
                    | select(.info.props."media.class"=="Stream/Input/Audio")
                    | select(.info.state=="running" or .state=="running")
                    | .info.props["node.name"]] | unique | join(", ")) as $mic_apps
                | (any(.[]; (.info.props["media.name"]? // "")
                    | test("^(xdph-streaming|gsr-default|game capture)"))) as $scr
                | ([.[] | select(.type=="PipeWire:Interface:Node")
                    | select(.info.props."media.class"=="Stream/Input/Video"
                        or .info.props."media.name"=="gsr-default_output"
                        or .info.props."media.name"=="game capture")
                    | select(.info.state=="running" or .state=="running")
                    | .info.props["media.name"]] | unique | join(", ")) as $scr_apps
                | $mic, $mic_apps, $scr, $scr_apps
            ]==])

            local lines = {}
            for line in out:gmatch("[^\n]+") do
                lines[#lines + 1] = line
            end

            if lines[1] == "true" then
                STATE.mic = true
                APP.mic = lines[2]
            end
            if lines[3] == "true" then
                STATE.scr = true
                APP.scr = lines[4]
            end
        end)
    end
end

-- Camera
if have("fuser") then
    local seen = {}
    local handle = io.popen("ls -1 /sys/class/video4linux/ 2>/dev/null")
    if handle then
        for entry in handle:lines() do
            if entry:match("^video%d+$") then
                local dev = "/dev/" .. entry
                local pids = run("fuser " .. dev .. " 2>/dev/null")
                if pids ~= "" then
                    STATE.cam = true
                    for pid in pids:gmatch("%d+") do
                        if not seen[pid] then
                            seen[pid] = true
                        end
                    end
                end
            end
        end
        handle:close()
    end
    local plist = {}
    for pid in pairs(seen) do
        plist[#plist + 1] = pid
    end
    batch_app("cam", plist)
end

-- Other process detection
detect_process("geoclue", "loc")
detect_process("wf-recorder", "rec")

-- Waybar output
local text = ""
local tooltip = ""
local classes = "status"

for _, key in ipairs(KEYS) do
    local on = STATE[key]
    if on then
        text = text .. '<span foreground="' .. COLOR[key] .. '">' .. ICON[key] .. "</span>  "
    end
    tooltip = tooltip .. LABEL[key] .. ": " .. pango_escape(APP[key] or "OFF") .. "\n"
    classes = classes .. " " .. key .. (on and "-on" or "-off")
end

tooltip = tooltip:match("^(.-)\n$") or tooltip
text = text:match("^(.-)  $") or text

local function json_escape(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\t', '\\t')
end

print(string.format('{"text":"%s","tooltip":"%s","class":"%s"}',
    json_escape(text), json_escape(tooltip), json_escape(classes)))
