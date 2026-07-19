#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/
-- Zero-miss Arch Linux update checker for waybar
-- Full rewrite of savely-krasovsky/waybar-updates in pure Lua

-- Dependencies
--   Core:            paru, pacman, awk, stat, cp, rm, mkdir
--   Conditional:     fakeroot (stale DB fallback), curl (-k, -d),
--                    git (-d), notify-send (-n)
--   Lua:             pure stdlib (no external modules)

local HOME = os.getenv("HOME") or "/tmp"
local CACHE_DIR = HOME .. "/.cache/ZARU"
local CFG_FILE = HOME .. "/.config/ZARU/config.lua"
local STATE_FILE = CACHE_DIR .. "/state.lua"

-- ====== defaults ======

local CFG = {
    format     = "{total}",
    tooltip    = "{}",
    interval   = 6,
    cycles     = 600,
    limit      = 2,
    devel      = false,
    notify     = false,
    kernel     = false,
    update_cmd = "alacritty -e sudo pacman -Syu",
    db_max_age = 21600,
}

local ICON  = { pacman = "",  aur = "",  dev = "󰘬",  kernel = "" }
local LABEL = { pacman = "pacman", aur = "AUR", dev = "dev", kernel = "kernel" }
local KEYS  = { "pacman", "aur", "dev", "kernel" }

-- ====== cli ======

local function usage()
    io.stderr:write([[
ZARU.lua [options]

  -f, --format   STR   Custom format: {aur} {pacman} {total} {dev} {kernel}
  -t, --tooltip  STR   Custom tooltip format
  -i, --interval INT   Seconds between checks       (default: ]] .. CFG.interval .. [[)
  -c, --cycles   INT   Offline cycles before re-sync (default: ]] .. CFG.cycles .. [[)
  -l, --limit    INT   Packages per source in notifications (default: ]] .. CFG.limit .. [[)
  -d, --devel          Also check -git/-hg devel packages
  -n, --notify         Send desktop notifications
  -k, --kernel         Check kernel vs kernel.org latest
      --update         Run update command and exit
      --once           Run one check cycle and exit
  -h, --help           Show this help
]])
    os.exit(2)
end

local function parse_args(a)
    a = a or {}
    local i = 1
    local action = "run"
    while i <= #a do
        local v = a[i]
        if v == "-f" or v == "--format" then i = i + 1; CFG.format = a[i] or CFG.format
        elseif v == "-t" or v == "--tooltip" then i = i + 1; CFG.tooltip = a[i] or CFG.tooltip
        elseif v == "-i" or v == "--interval" then i = i + 1; CFG.interval = tonumber(a[i]) or CFG.interval
        elseif v == "-c" or v == "--cycles" then i = i + 1; CFG.cycles = tonumber(a[i]) or CFG.cycles
        elseif v == "-l" or v == "--limit" then i = i + 1; CFG.limit = tonumber(a[i]) or CFG.limit
        elseif v == "-d" or v == "--devel" then CFG.devel = true
        elseif v == "-n" or v == "--notify" then CFG.notify = true
        elseif v == "-k" or v == "--kernel" then CFG.kernel = true
        elseif v == "--update" then action = "update"
        elseif v == "--once" then action = "once"
        elseif v == "-h" or v == "--help" then usage()
        else io.stderr:write("Unknown: " .. v .. "\n"); usage()
        end
        i = i + 1
    end
    return action
end

local function load_config()
    local f = io.open(CFG_FILE)
    if not f then return end
    local chunk = f:read("*a"); f:close()
    local fn, err = load(chunk, CFG_FILE, "t", setmetatable({}, {__index = _G}))
    if fn then
        local ok, result = pcall(fn)
        if ok and type(result) == "table" then
            for k, v in pairs(result) do CFG[k] = v end
        end
    end
end

-- ====== utilities ======

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function json_escape(s)
    return s:gsub("\\", "\\\\")
            :gsub('"', '\\"')
            :gsub("\n", "\\n")
            :gsub("\r", "\\r")
            :gsub("\t", "\\t")
end

local function shell(cmd, strict)
    if strict == nil then strict = true end
    local p = io.popen(cmd, "r")
    if not p then return nil end
    local data = p:read("*a")
    local _, _, code = p:close()
    if strict and code ~= nil and code ~= 0 then return nil end
    return data
end

local function curl(url, timeout)
    timeout = timeout or 15
    return shell(
        "curl -fsSL --max-time " .. timeout .. " --connect-timeout 5 '" .. url .. "'"
    )
end

local function file_mtime(path)
    local d = shell("stat -c %Y " .. path) or ""
    return tonumber(d:match("%d+")) or 0
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- ====== state persistence (Lua-syntax, safe dofile) ======

local state = {}

local function save_state()
    local function long_str(s)
        for n = 0, 9 do
            local eq = string.rep("=", n)
            if not s:find("]" .. eq .. "]", 1, true) then
                return "[" .. eq .. "[" .. s .. "]" .. eq .. "]"
            end
        end
        return string.format("%q", s)
    end
    local t = {"return {"}
    for k, v in pairs(state) do
        local lt = type(v)
        if lt == "string" then
            t[#t + 1] = "  " .. k .. "=" .. long_str(v) .. ","
        elseif lt == "number" then
            t[#t + 1] = "  " .. k .. "=" .. tostring(v) .. ","
        elseif lt == "boolean" then
            t[#t + 1] = "  " .. k .. "=" .. (v and "true" or "false") .. ","
        end
    end
    t[#t + 1] = "}"
    os.execute("mkdir -p " .. CACHE_DIR)
    local f = io.open(STATE_FILE, "w")
    if f then f:write(table.concat(t, "\n")); f:close() end
end

local function load_state()
    if not file_exists(STATE_FILE) then return end
    local ok, s = pcall(dofile, STATE_FILE)
    if ok and type(s) == "table" then
        for k, v in pairs(s) do state[k] = v end
    end
end

local function init_state()
    local defaults = {
        pacman_count=0, pacman_list="",
        aur_count=0,    aur_list="",
        devel_count=0,  devel_list="",  devel_cache="",
        kernel_count=0, kernel_list="",
        total_count=0,  pacman_stale=false,
        last_online=0,
    }
    for k, v in pairs(defaults) do
        if state[k] == nil then state[k] = v end
    end
end

-- ====== paru ======

local foreign_cache = nil
local build_dates_cache = nil

local function sort_by_build_date(lines)
    if #lines == 0 then return end
    if not build_dates_cache then
        build_dates_cache = {}
        local p = io.popen("for d in /var/lib/pacman/local/*/desc; do awk '/^%NAME%/{getline; n=$0} /^%BUILDDATE%/{getline; print n, $0}' \"$d\"; done", "r")
        if p then
            for line in p:read("*a"):gmatch("[^\n]+") do
                local n, d = line:match("^(%S+)%s+(%d+)")
                if n and d then build_dates_cache[n] = tonumber(d) end
            end
            p:close()
        end
    end
    local dates = build_dates_cache
    local function by_date(a, b)
        return (dates[a:match("^(%S+)")] or 0) > (dates[b:match("^(%S+)")] or 0)
    end
    table.sort(lines, by_date)
end

local function check_paru()
    local data = shell("timeout 120 paru -Qu --color=never 2>/dev/null")

    if not data or not data:match("%S") then
        state.pacman_count = 0; state.pacman_list = ""
        state.aur_count    = 0; state.aur_list    = ""
        state.pacman_stale = (os.time() - file_mtime("/var/lib/pacman/sync/core.db")) > CFG.db_max_age
        return
    end

    if not foreign_cache then
        foreign_cache = {}
        local qm = shell("pacman -Qm 2>/dev/null")
        if qm then
            for line in qm:gmatch("[^\r\n]+") do
                local name = line:match("^(%S+)")
                if name then foreign_cache[name] = true end
            end
        end
    end

    local pacman_lines = {}
    local aur_lines    = {}
    for line in data:gmatch("[^\r\n]+") do
        local cleaned = trim(line)
        if cleaned ~= "" then
            local name = cleaned:match("^(%S+)")
            if name and foreign_cache[name] then
                aur_lines[#aur_lines + 1] = cleaned
            else
                pacman_lines[#pacman_lines + 1] = cleaned
            end
        end
    end

    sort_by_build_date(pacman_lines)
    sort_by_build_date(aur_lines)

    if #pacman_lines > 0 then
        state.pacman_count = #pacman_lines
        state.pacman_list  = table.concat(pacman_lines, "\n")
    else
        state.pacman_count = 0; state.pacman_list = ""
    end

    if #aur_lines > 0 then
        state.aur_count = #aur_lines
        state.aur_list  = table.concat(aur_lines, "\n")
    else
        state.aur_count = 0; state.aur_list = ""
    end

    state.pacman_stale = (os.time() - file_mtime("/var/lib/pacman/sync/core.db")) > CFG.db_max_age
end

local function fresh_pacman_sync()
    local tmp = CACHE_DIR .. "/sync." .. tostring(os.getpid())
    os.execute("mkdir -p " .. tmp)

    local ok = shell(string.format(
        "timeout 120 fakeroot pacman -Sy --dbonly --noconfirm --disable-sandbox --dbpath '%s' 2>/dev/null", tmp
    ), true)
    if not ok then os.execute("rm -rf " .. tmp); return end

    os.execute(string.format("rm -rf '%s/local' && cp -al /var/lib/pacman/local '%s/local' 2>/dev/null || cp -a /var/lib/pacman/local '%s/local'", tmp, tmp, tmp))

    local data = shell(string.format(
        "pacman -Qu --dbpath '%s' 2>/dev/null", tmp
    ))
    os.execute("rm -rf " .. tmp)

    if not data or not data:match("%S") then return end

    local lines = {}
    for line in data:gmatch("[^\r\n]+") do
        local cleaned = trim(line)
        if cleaned ~= "" then lines[#lines + 1] = cleaned end
    end
    if #lines == 0 then return end

    sort_by_build_date(lines)

    state.pacman_count = #lines
    state.pacman_list  = table.concat(lines, "\n")
    state.pacman_stale = false
end

-- ====== devel ======

local function check_devel(online)
    if not CFG.devel then
        state.devel_count = 0; state.devel_list = ""
        return
    end

    local ignored_data = shell("pacman-conf IgnorePkg 2>/dev/null", false)
    local ignored = {}
    if ignored_data then
        for pkg in ignored_data:gmatch("%S+") do ignored[pkg] = true end
    end

    local qm = shell("pacman -Qm 2>/dev/null | grep -iE '(git|hg|svn|bzr)'")
    if not qm or not qm:match("%S") then
        state.devel_count = 0; state.devel_list = ""
        return
    end

    if not online then
        local list = state.devel_cache or ""
        local n = 0
        for _ in list:gmatch("[^\r\n]+") do n = n + 1 end
        if list == "" then n = 0 end
        state.devel_count = n
        state.devel_list = list
        return
    end

    local updates = {}
    for line in qm:gmatch("[^\r\n]+") do
        local n, v = line:match("^(%S+)%s+(%S+)")
        if not n or not v or ignored[n] then goto next_dev end

        local pkgbuild = curl("https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=" .. n, 15)
        if not pkgbuild then goto next_dev end

        local src = pkgbuild:match("source%s*=%s*%b()") or ""
        src = src:match("http[^\"'%s%)]+")
        if not src then goto next_dev end
        src = src:match("^(.-)#") or src

        local remote = shell(
            "timeout 30 git ls-remote --heads " .. src .. " 2>/dev/null | head -1 | awk '{print $1}' | cut -c1-7"
        )
        if not remote or not remote:match("%S+") then goto next_dev end
        remote = remote:match("%S+")

        if not v:find(remote, 1, true) then
            updates[#updates + 1] = n .. " " .. v .. " -> " .. remote
        end
        ::next_dev::
    end

    local list = table.concat(updates, "\n")
    state.devel_cache = list
    state.devel_count = #updates
    state.devel_list = list
end

-- ====== kernel ======

local kernel_running = nil

local function check_kernel(remote_data, is_prefetched)
    if not CFG.kernel then state.kernel_count = 0; return end

    if not kernel_running then
        local full = shell("uname -r")
        if full then kernel_running = trim(full) end
    end
    if not kernel_running then return end
    local running = kernel_running:match("^(%d+%.%d+%.%d+)") or kernel_running

    local latest
    if is_prefetched then
        latest = remote_data
        if not latest then return end
    else
        latest = curl("https://www.kernel.org/finger_banner", 10)
        if not latest then return end
    end
    latest = latest:match("The latest stable version[^:]*:%s*([%d.]+)")
    if not latest then return end
    latest = trim(latest)

    local dots = select(2, latest:gsub("%.", "")) or 0
    if dots < 2 then latest = latest .. ".0" end

    if running == latest then
        state.kernel_count = 0; state.kernel_list = ""
    else
        state.kernel_count = 1
        state.kernel_list = "kernel " .. kernel_running .. " -> " .. latest
    end
end

-- ====== aggregate ======

local function check_updates()
    local online = (os.time() - (state.last_online or 0)) >= (CFG.cycles * CFG.interval)
    if online then
        state.last_online = os.time()
        foreign_cache = nil
        build_dates_cache = nil
    end
    check_paru()
    check_devel(online)
    if state.pacman_stale then fresh_pacman_sync() end

    local kernel_h
    if online and CFG.kernel then
        kernel_h = io.popen("curl -fsSL --max-time 10 --connect-timeout 5 'https://www.kernel.org/finger_banner'", "r")
    end

    if kernel_h then
        local data = kernel_h:read("*a")
        local _, _, code = kernel_h:close()
        if code == 0 and data and data ~= "" then
            check_kernel(data, true)
        end
    elseif not online then
        check_kernel(nil, false)
    end

    state.total_count = state.pacman_count + state.aur_count + state.devel_count
end

-- ====== format engine ======

local function format(str, mode)
    if not str then return "" end
    local counts = { total = state.total_count }
    for _, key in ipairs(KEYS) do
        counts[key] = state[key .. "_count"]
    end
    for key, count in pairs(counts) do
        str = str:gsub("{" .. "([^}]-):%s*" .. key .. "%s*:?([^}]*)}", function(pfx, sfx)
            if count > 0 then return pfx .. tostring(count) .. sfx end
            return ""
        end)
        str = str:gsub("{" .. key .. "}", function()
            if count > 0 then return tostring(count) end
            return ""
        end)
    end
    if mode == "tooltip" then
        str = str:gsub("{}", function()
            local blocks = {}
            for _, key in ipairs(KEYS) do
                local count = state[key .. "_count"] or 0
                local list  = state[key .. "_list"] or ""
                if count > 0 and list ~= "" then
                    if key == "kernel" then
                        blocks[#blocks + 1] = string.format(
                            "<span foreground='#e0d8a4'>%s %s</span>", ICON[key], list
                        )
                    else
                        local header = ICON[key] .. " " .. count
                        local items = {}
                        for line in list:gmatch("[^\r\n]+") do
                            local cleaned = trim(line)
                            if cleaned ~= "" then
                                items[#items + 1] = cleaned
                            end
                        end
                        blocks[#blocks + 1] = header .. "\n" .. table.concat(items, "\n")
                    end
                end
            end
            return table.concat(blocks, "\n\n")
        end)
    else
        str = str:gsub("{}", tostring(state.total_count))
    end
    return str
end

-- ====== output ======

local function emit(text, alt, tooltip, class)
    local ok, err = pcall(function()
        io.stdout:write(string.format(
            '{"text":"%s","alt":"%s","tooltip":"%s","class":"%s","exec":"%s"}\n',
            json_escape(text), json_escape(alt), json_escape(tooltip),
            json_escape(class), json_escape(CFG.update_cmd)
        ))
        io.stdout:flush()
    end)
    if not ok then os.exit(0) end
end

local function notify_all()
    if not CFG.notify or state.total_count == 0 then return end

    local lines = { "" }
    local first = true
    for _, key in ipairs(KEYS) do
        if key == "kernel" then goto next_src end
        local count = state[key .. "_count"] or 0
        local list  = state[key .. "_list"] or ""
        if count > 0 and list ~= "" then
            if not first then lines[#lines + 1] = "" end
            first = false
            lines[#lines + 1] = ICON[key] .. " " .. LABEL[key] .. " " .. count
            local shown = 0
            for line in list:gmatch("[^\r\n]+") do
                shown = shown + 1
                if shown <= CFG.limit then
                    lines[#lines + 1] = trim(line)
                end
            end
            if shown > CFG.limit then
                lines[#lines + 1] = "+" .. (shown - CFG.limit) .. " more"
            end
        end
        ::next_src::
    end

    local body = table.concat(lines, "\n")
    shell(
        "notify-send -a update -u normal -t 10000 -i software-update-available-symbolic " ..
        "'" .. state.total_count .. " Updates available' '" ..
        body:gsub("'", "'\\''") .. "'"
    )
end

local function send_output()
    if state.total_count == 0 then
        emit("", "updated", "System is up to date", "updated")
        return false
    end

    local text = format(CFG.format, "text")
    local tip = format(CFG.tooltip, "tooltip")

    local cls = "pending-updates"
    if state.pacman_stale then
        cls = cls .. " stale"
        tip = tip .. "\n\n[DB stale - sudo pacman -Sy]"
    end

    emit(text, "pending-updates", tip, cls)
    return true
end

local function show_progress()
    emit("󰚰", "checking", "Checking for updates...", "checking")
end

-- ====== update action ======

local function run_update()
    io.stderr:write("Running: " .. CFG.update_cmd .. "\n")
    os.execute(CFG.update_cmd)
    os.exit(0)
end

-- ====== main ======

local function main()
    local action = parse_args(arg)
    load_config()

    if action == "update" then run_update() end

    os.execute("mkdir -p " .. CACHE_DIR)
    load_state()
    init_state()

    if action == "once" then
        local trigger = CACHE_DIR .. "/refresh"
        if file_exists(trigger) then
            os.remove(trigger)
            show_progress()
            local ok, err = pcall(function() check_updates() end)
            if not ok then
                io.stderr:write("[ZARU] refresh: " .. tostring(err) .. "\n")
            end
            send_output()
            save_state()
            os.exit(0)
        end

        local prev_pl = state.pacman_list
        local prev_al = state.aur_list
        local prev_dl = state.devel_list

        if state.last_online == 0 then show_progress() end
        local ok, err = pcall(function() check_updates() end)
        if not ok then
            io.stderr:write("[ZARU] " .. tostring(err) .. "\n")
        end
        send_output()
        if state.pacman_list ~= prev_pl or state.aur_list ~= prev_al
           or state.devel_list ~= prev_dl then
            if state.total_count > 0 then notify_all() end
        end
        save_state()
        os.exit(0)
    end

    io.stdout:setvbuf("line")

    show_progress()
    local ok, err = pcall(function() check_updates() end)
    if not ok then
        io.stderr:write("[ZARU] startup: " .. tostring(err) .. "\n")
    end

    local prev_pl = state.pacman_list
    local prev_al = state.aur_list
    local prev_dl = state.devel_list

    local changed = send_output()
    if changed then
        notify_all()
    end
    save_state()

    while true do
        os.execute("sleep " .. CFG.interval)

        local trigger = CACHE_DIR .. "/refresh"
        if file_exists(trigger) then
            os.remove(trigger)
            prev_pl = state.pacman_list
            prev_al = state.aur_list
            prev_dl = state.devel_list
            show_progress()
            local ok, err = pcall(function() check_updates() end)
            if not ok then
                io.stderr:write("[ZARU] refresh: " .. tostring(err) .. "\n")
            end
            if state.pacman_list ~= prev_pl or state.aur_list ~= prev_al
               or state.devel_list ~= prev_dl then
                send_output()
                save_state()
            end
        end

        prev_pl = state.pacman_list
        prev_al = state.aur_list
        prev_dl = state.devel_list

        local ok, err = pcall(function() check_updates() end)
        if not ok then
            io.stderr:write("[ZARU] " .. tostring(err) .. "\n")
        elseif state.pacman_list ~= prev_pl or state.aur_list ~= prev_al
               or state.devel_list ~= prev_dl then
            local changed = send_output()
            if changed then
                notify_all()
            end
            save_state()
        end

        collectgarbage("collect")
    end
end

main()
