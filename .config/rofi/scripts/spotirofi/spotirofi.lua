#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/
-- spotirofi v3 — rofi interface for spotifyd

local HOME       = os.getenv("HOME")
local DIR        = HOME .. "/.config/rofi/scripts/spotirofi"
local CACHE      = HOME .. "/.cache/spotirofi"
local LYRICS_DIR = CACHE .. "/lyrics"
local SCR_TOKEN  = CACHE .. "/token.json"
local LIKED_CACHE = CACHE .. "/liked_tracks.json"
local ALBUM_CACHE = CACHE .. "/saved_albums.json"
local ARTIST_CACHE = CACHE .. "/followed_artists.json"
local SESSION_FILE = CACHE .. "/session.json"
local QUEUE_FILE   = CACHE .. "/playback_queue.json"
local ART_DIR      = CACHE .. "/art"
local LIKED_IDS    = CACHE .. "/liked_ids.json"

local THEME      = DIR .. "/main.rasi"
local THEME_MENU = DIR .. "/menu.rasi"
local THEME_LYR  = DIR .. "/lyrics.rasi"
local THEME_MSG  = DIR .. "/message.rasi"
local THEME_SUB  = DIR .. "/sub.rasi"

local MAX_RESULTS = 20
local CACHE_TTL  = 43200
local SPOTIFY_ID  = "d420a117a32841c2b3474932e49fb54b"
local liked = {}  -- set of liked track IDs

local current_track = nil
local current_id    = nil
local is_playing    = false
local is_shuffle    = false
local repeat_state  = "off"
local last_playback = 0

local json = require("cjson")

--===================================================================
-- UTILITIES
--===================================================================

local function shell(cmd)
    local h = io.popen(cmd, "r")
    if not h then return nil end
    local r = h:read("*a"); h:close()
    return r
end

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function url_encode(s)
    return (s:gsub(" ", "+"):gsub("[^%w+]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local d = f:read("*a"); f:close()
    return d
end

local function write_file(p, d)
    local t = p .. ".tmp"
    local f = io.open(t, "w")
    if not f then return false end
    f:write(d); f:close()
    return os.rename(t, p)
end

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function strip_nulls(t)
    if type(t) ~= "table" then return t end
    local rm = {}
    for k, v in pairs(t) do
        if v == json.null then rm[#rm+1] = k
        elseif type(v) == "table" then strip_nulls(v) end
    end
    for _, k in ipairs(rm) do t[k] = nil end
    return t
end

local function safe_decode(s)
    s = trim(s or "")
    if s == "" then return nil end
    local ok, data = pcall(json.decode, s)
    if not ok or type(data) ~= "table" then return nil end
    return strip_nulls(data)
end

local function ensure_cache()
    os.execute("mkdir -p " .. shell_quote(CACHE) .. " " .. shell_quote(LYRICS_DIR))
end

local _mem = {}
local function mem_get(key)
    local e = _mem[key]
    if e and (not e.expire or os.time() < e.expire) then return e.value end
    _mem[key] = nil
    return nil
end
local function mem_set(key, value, ttl)
    _mem[key] = {value = value, expire = ttl and (os.time() + ttl)}
end
local function mem_bust(key) _mem[key] = nil end
local function disk_get(path, ttl)
    local raw = read_file(path)
    if not raw then return nil end
    local d = safe_decode(raw)
    if not d or type(d) ~= "table" or not d.fetched_at then return nil end
    if ttl and os.time() - d.fetched_at >= ttl then return nil end
    return d.data
end
local function disk_set(path, data)
    ensure_cache()
    write_file(path, json.encode({data=data, fetched_at=os.time()}))
end
local function disk_bust(path) os.remove(path) end
local function cached_fetch(key, disk_path, ttl, fetch_fn)
    local v = mem_get(key)
    if v ~= nil then return v end
    if disk_path then
        v = disk_get(disk_path, ttl)
        if v ~= nil then mem_set(key, v, ttl); return v end
    end
    v = fetch_fn()
    if v ~= nil then
        mem_set(key, v, ttl)
        if disk_path then disk_set(disk_path, v) end
    end
    return v
end

-- populate liked IDs for display helpers (lightweight, from cache)
local function populate_liked_ids()
    liked = {}
    local ids = safe_decode(read_file(LIKED_IDS))
    if ids and type(ids) == "table" and #ids > 0 then
        for _, id in ipairs(ids) do liked[id] = true end
        return
    end
    local c = safe_decode(read_file(LIKED_CACHE))
    if c and c.tracks then
        for _, t in ipairs(c.tracks) do
            if t.id then liked[t.id] = true end
        end
    end
end

--===================================================================
-- SESSION STACK
--===================================================================

local function session_peek()
    local raw = read_file(SESSION_FILE)
    if not raw then return nil end
    local ok, d = pcall(json.decode, raw)
    if not ok or type(d) ~= "table" then return nil end
    local s = d.stack
    if type(s) ~= "table" or #s == 0 then return nil end
    return s[#s]
end

local function session_push(data)
    local raw = read_file(SESSION_FILE)
    local stack = {}
    if raw then
        local ok, s = pcall(json.decode, raw)
        if ok and s and type(s.stack) == "table" then stack = s.stack end
    end
    stack[#stack+1] = data
    write_file(SESSION_FILE, json.encode({stack=stack}))
end

local function session_pop()
    local raw = read_file(SESSION_FILE)
    if not raw then return end
    local ok, d = pcall(json.decode, raw)
    if not ok or type(d) ~= "table" then return end
    local s = d.stack
    if type(s) ~= "table" or #s == 0 then return end
    table.remove(s)
    if #s == 0 then os.remove(SESSION_FILE)
    else write_file(SESSION_FILE, json.encode({stack=s})) end
end

local function session_clear()
    os.remove(SESSION_FILE)
end

--===================================================================
-- ROFI
--===================================================================

local search_pending = false
local main_pending   = false
local view_actions, view_artist, view_lyrics, view_add_pl
local get_playback

local function rofi_dmenu(entries, opts)
    if search_pending or main_pending then return nil end
    opts = opts or {}
    local prompt   = opts.prompt or ""
    local mesg     = opts.mesg
    local markup   = opts.markup
    local by_index = opts.by_index
    local theme    = opts.theme or (opts.use_menu and THEME_MENU or THEME)
    local eh       = opts.eh
    local sel      = opts.sel

    while true do
        local args = {"rofi","-dmenu","-theme",theme,"-p",prompt,"-i",
                      "-kb-custom-1","Alt+BackSpace","-kb-custom-2","Alt+space",
                      "-kb-custom-3","Alt+slash","-kb-custom-4","Alt+Return",
                      "-kb-custom-5","Alt+KP_Enter"}
        if opts.custom == false then args[#args+1] = "-no-custom" end
        if markup then args[#args+1] = "-markup-rows"; args[#args+1] = "-markup" end
        if by_index then args[#args+1] = "-format"; args[#args+1] = "i" end
        if eh then args[#args+1] = "-eh"; args[#args+1] = tostring(eh) end
        if sel and sel > 0 then args[#args+1] = "-selected-row"; args[#args+1] = tostring(sel) end
        if mesg then args[#args+1] = "-mesg"; args[#args+1] = mesg end

        local entry_tf = os.tmpname()
        local f = io.open(entry_tf, "w")
        if not f then return nil end
        for _, e in ipairs(entries or {}) do f:write(e, "\n") end
        f:close()

        local qa = {}
        for _, a in ipairs(args) do qa[#qa+1] = shell_quote(a) end
        local out_tf = os.tmpname()
        local cmd = table.concat(qa, " ") .. " < " .. shell_quote(entry_tf)
                 .. " > " .. shell_quote(out_tf)
                 .. " 2>/dev/null; printf '\\n__EXIT__%d__' $? >> " .. shell_quote(out_tf)
        os.execute(cmd)
        local raw = read_file(out_tf)
        os.remove(entry_tf)
        os.remove(out_tf)

        local exit_code = tonumber((raw or ""):match("__EXIT__(%d+)__")) or 0
        local result    = trim((raw or ""):match("^(.-)\n__EXIT__%d+__") or "")

        if exit_code == 10 then session_pop(); return nil end
        if exit_code == 11 then session_clear(); main_pending = true; return nil end
        if exit_code == 12 then session_clear(); search_pending = true; return nil end
        if exit_code == 13 or exit_code == 14 then
            last_playback = 0
            get_playback()
            if current_track then view_actions(current_track, "track") end
        else
            if result == "" then os.exit(0) end
            if by_index then
                local n = tonumber(result)
                if not n or n < 0 then return nil end
                return n + 1
            end
            return result
        end
    end
end

local function rofi_message(msg)
    local tf = os.tmpname()
    os.execute("rofi -e " .. shell_quote(msg) .. " -theme " .. shell_quote(THEME_MSG) .. " -markup 2>/dev/null; printf '\\n__EXIT__%d__' $? >> " .. shell_quote(tf))
    local raw = read_file(tf)
    os.remove(tf)
    local ec = tonumber((raw or ""):match("__EXIT__(%d+)__")) or 1
    return ec == 0
end

local function rofi_input(prompt, preset)
    local in_tf  = os.tmpname()
    local out_tf = os.tmpname()
    local f = io.open(in_tf, "w")
    if f then f:write(preset or ""); f:close() end
    os.execute("rofi -dmenu -p " .. shell_quote(prompt)
        .. " -theme " .. shell_quote(THEME_MENU)
        .. " < " .. shell_quote(in_tf)
        .. " > " .. shell_quote(out_tf) .. " 2>/dev/null")
    local r = trim(read_file(out_tf) or "")
    os.remove(in_tf)
    os.remove(out_tf)
    return r
end

--===================================================================
-- TOKEN
--===================================================================

local function get_token()
    local raw = read_file(SCR_TOKEN)
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return nil end
    if not data.access_token then return nil end
    if data.expires_at and type(data.expires_at) == "number" then
        if os.time() > data.expires_at - 120 then
            if data.refresh_token and type(data.refresh_token) == "string" then
                local r = shell("curl -s --max-time 10 -X POST https://accounts.spotify.com/api/token "
                    .. "-d grant_type=refresh_token -d refresh_token=" .. data.refresh_token
                    .. " -d client_id=" .. SPOTIFY_ID)
                local rd = safe_decode(r)
                if rd and rd.access_token then
                    data.access_token = rd.access_token
                    if rd.refresh_token then data.refresh_token = rd.refresh_token end
                    data.expires_at = os.time() + (rd.expires_in or 3600) - 60
                    write_file(SCR_TOKEN, json.encode(data))
                    return data.access_token
                end
            end
            return nil
        end
    end
    return data.access_token
end

local function oauth_get_token()
    local verifier = trim(shell("openssl rand -base64 96 | tr -d '=+\\n/' | head -c 128"))
    local challenge = trim(shell("echo -n " .. shell_quote(verifier)
        .. " | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '='"))
    local scopes = "app-remote-control playlist-modify playlist-modify-private playlist-modify-public"
        .. " playlist-read playlist-read-collaborative playlist-read-private streaming"
        .. " user-follow-modify user-follow-read user-library-modify user-library-read"
        .. " user-read-recently-played user-top-read"
        .. " user-modify-playback-state user-read-currently-playing user-read-playback-state"
        .. " user-read-private"
        .. " user-read-playback-position"
    local auth_url = "https://accounts.spotify.com/authorize"
        .. "?client_id=" .. SPOTIFY_ID
        .. "&response_type=code"
        .. "&redirect_uri=http://127.0.0.1:8989/login"
        .. "&code_challenge_method=S256"
        .. "&code_challenge=" .. challenge
        .. "&scope=" .. scopes:gsub("%s+", "+")

    local srv = "perl -MIO::Socket::INET -e '"
        .. "$s=IO::Socket::INET->new(LocalPort=>8989,Listen=>1,ReuseAddr=>1);"
        .. "$c=$s->accept();$r=<$c>;($x)=$r=~/code=([^&\\s]+)/;"
        .. "if($x){open(F,\">\",\"/tmp/spotirofi_code\");print F $x;close(F)}"
        .. "print $c \"HTTP/1.1 200 OK\\r\\n\\r\\nok\";close $c;close $s'"
    os.execute(srv .. " &")
    os.execute("xdg-open " .. shell_quote(auth_url) .. " 2>/dev/null &")

    while true do
        local code = trim(read_file("/tmp/spotirofi_code") or "")
        if #code > 0 then
            os.remove("/tmp/spotirofi_code")
            local r = shell("curl -s --max-time 10 -X POST https://accounts.spotify.com/api/token "
                .. "-d grant_type=authorization_code -d code=" .. code
                .. " -d redirect_uri=http://127.0.0.1:8989/login"
                .. " -d client_id=" .. SPOTIFY_ID
                .. " -d code_verifier=" .. verifier)
            local d = safe_decode(r)
            if d and d.access_token then
                ensure_cache()
                write_file(SCR_TOKEN, json.encode({
                    access_token = d.access_token,
                    refresh_token = d.refresh_token,
                    expires_at = os.time() + (d.expires_in or 3600) - 60,
                }))
                return d.access_token
            end
            return nil
        end
        os.execute("sleep 1")
    end
end

local function ensure_auth()
    if get_token() then return end
    oauth_get_token()
end

--===================================================================
-- NOTIFY
--===================================================================

local function artist_names(item)
    local a = {}
    for _, v in ipairs(item.artists or {}) do if v.name then a[#a+1] = v.name end end
    return table.concat(a, ", ")
end

local function notify_track(track)
    local title  = (track and track.name) or "Unknown"
    local artist = (track and artist_names(track)) or ""
    if track and track.id then
        write_file("/tmp/spotirofi_last_notify", track.id)
    end
    local ic = ""
    if track and track.album and track.album.images then
        local art_url = track.album.images[1].url
        local hash = art_url:match("/image/([%w]+)") or art_url:match("/([%w_%-]+)$")
        local art_path = (hash) and (ART_DIR .. "/" .. hash .. ".jpg") or ""
        if art_path ~= "" then
            os.execute("mkdir -p " .. shell_quote(ART_DIR))
            local fh = io.open(art_path, "r")
            if not fh then
                os.execute("curl -s --max-time 5 -o " .. shell_quote(art_path) .. " " .. shell_quote(art_url) .. " &")
            else
                fh:close()
            end
            ic = "--icon=" .. shell_quote(art_path)
        end
    end
    local cmd = "notify-send --app-name=spotirofi " .. ic
        .. " " .. shell_quote(title) .. " " .. shell_quote(artist)
    os.execute(cmd .. " &")
end

--===================================================================
-- SPOTIFYD MANAGEMENT
--===================================================================

local function get_spotifyd_device()
    local cached = mem_get("spotifyd_device")
    if cached then return cached end
    local token = get_token()
    if not token then return nil end
    local d = safe_decode(shell("curl -s --max-time 3 -H 'Authorization: Bearer " .. token .. "' 'https://api.spotify.com/v1/me/player/devices'"))
    if not d or not d.devices then return nil end
    local dev_id, dev_supports_vol = nil, false
    for _, dev in ipairs(d.devices) do
        if dev.name and dev.name:lower():find("spotirofi") then dev_id = dev.id; dev_supports_vol = dev.supports_volume; break end
    end
    if not dev_id then
        for _, dev in ipairs(d.devices) do
            if dev.is_active then dev_id = dev.id; dev_supports_vol = dev.supports_volume; break end
        end
    end
    if not dev_id and #d.devices > 0 then dev_id = d.devices[1].id; dev_supports_vol = d.devices[1].supports_volume end
    if dev_id then
        mem_set("spotifyd_device", dev_id, 120)
        mem_set("spotifyd_device_vol", dev_supports_vol, 120)
    end
    return dev_id
end

local SPOTIFYD_CREDS = HOME .. "/.cache/spotifyd/oauth/credentials.json"

local function ensure_spotifyd_auth()
    if io.open(SPOTIFYD_CREDS) then return end
    os.execute("spotifyd authenticate")
end

local function ensure_spotifyd()
    local pid = trim(shell("pgrep -x spotifyd 2>/dev/null") or "")
    if pid == "" then
        os.execute("spotifyd --no-daemon --device-name spotirofi --backend pulseaudio --use-mpris --initial-volume 100 > /dev/null 2>&1 &")
        for _ = 1, 15 do
            pid = trim(shell("pgrep -x spotifyd 2>/dev/null") or "")
            if pid ~= "" then break end
            os.execute("sleep 0.2")
        end
        -- spotifyd just started, give it a moment to register
        os.execute("sleep 1")
    end
end

--===================================================================
-- DATA CACHE
--===================================================================

local rate_limit_shown = false

local function api_get(path, params)
    local token = get_token()
    if not token then return nil end
    local url = "https://api.spotify.com/v1/" .. path
    if params then url = url .. "?" .. params end
    local hdr = os.tmpname()
    local r = shell("curl -s --max-time 5 -D " .. shell_quote(hdr) .. " -w '\\n%{http_code}' -H 'Authorization: Bearer " .. token .. "' " .. shell_quote(url))
    local status = tonumber(string.match(r or "", "\n(%d+)$")) or 0
    local body = string.match(r or "", "^(.-)\n%d+$") or r or ""
    local function read_retry_after()
        local hf = io.open(hdr, "r")
        if not hf then return "30" end
        local headers = hf:read("*a"); hf:close()
        return string.match(headers, "[Rr]etry%-[Aa]fter:%s*(%d+)") or "30"
    end
    if status == 429 and not rate_limit_shown then
        rate_limit_shown = true
        local secs = read_retry_after()
        os.remove(hdr)
        write_file("/tmp/spotirofi_rate_cooldown", os.time() + tonumber(secs) + 30)
        rofi_message("Spotify API rate limit reached (429). Retry after " .. secs .. "s.")
        os.exit(0)
    end
    os.remove(hdr)
    if status == 401 and not rate_limit_shown then
        rate_limit_shown = true
        rofi_message("Spotify token expired (401). Restart rofi to refresh.")
        os.exit(0)
    end
    if status >= 400 then return nil end
    local d = safe_decode(body)
    rate_limit_shown = false
    return d
end

local function load_liked_tracks_full()
    local tracks = {}
    local token = get_token()
    if not token then return tracks end
    local offset = 0
    while true do
        local d = api_get("me/tracks", "limit=50&offset=" .. offset)
        if not d or not d.items or #d.items == 0 then break end
        for _, entry in ipairs(d.items) do
            local t = entry.track
            if t then
                t.added_at = entry.added_at
                tracks[#tracks+1] = t
            end
        end
        if #d.items < 50 then break end
        offset = offset + 50
    end
    table.sort(tracks, function(a,b) return (a.added_at or "") > (b.added_at or "") end)
    return tracks
end

local function load_liked_tracks()
    local c = safe_decode(read_file(LIKED_CACHE))
    if c and c.tracks and type(c.tracks) == "table" and #c.tracks > 0 then
        if not c.fetched_at or os.time() - c.fetched_at < CACHE_TTL then
            return c.tracks
        end
    end
     local tracks = load_liked_tracks_full()
    if #tracks > 0 then
        ensure_cache()
        write_file(LIKED_CACHE, json.encode({tracks=tracks, fetched_at=os.time()}))
        -- write lightweight ID list
        local ids = {}
        for _, t in ipairs(tracks) do if t.id then ids[#ids+1] = t.id end end
        write_file(LIKED_IDS, json.encode(ids))
    end
    return tracks
end

local function load_saved_albums()
    local c = safe_decode(read_file(ALBUM_CACHE))
    if c and c.items and type(c.items) == "table" and #c.items > 0 then
        if not c.fetched_at or os.time() - c.fetched_at < CACHE_TTL then
            return c.items
        end
    end
    local items = {}
    local offset = 0
    while true do
        local d = api_get("me/albums", "limit=50&offset=" .. offset)
        if not d or not d.items or #d.items == 0 then break end
        for _, e in ipairs(d.items) do
            if e.album then items[#items+1] = e.album end
        end
        if #d.items < 50 then break end
        offset = offset + 50
    end
    table.sort(items, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    if #items > 0 then
        ensure_cache()
        write_file(ALBUM_CACHE, json.encode({items=items, fetched_at=os.time()}))
    end
    return items
end

local function load_followed_artists()
    local c = safe_decode(read_file(ARTIST_CACHE))
    if c and c.items and type(c.items) == "table" and #c.items > 0 then
        if not c.fetched_at or os.time() - c.fetched_at < CACHE_TTL then
            return c.items
        end
    end
    local items = {}
    local after = nil
    while true do
        local p = "type=artist&limit=50"
        if after then p = p .. "&after=" .. after end
        local d = api_get("me/following", p)
        if not d or not d.artists or not d.artists.items or #d.artists.items == 0 then break end
        for _, a in ipairs(d.artists.items) do items[#items+1] = a end
        if not d.artists.next then break end
        after = d.artists.cursors and d.artists.cursors.after
    end
    table.sort(items, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    if #items > 0 then
        ensure_cache()
        write_file(ARTIST_CACHE, json.encode({items=items, fetched_at=os.time()}))
    end
    return items
end

--===================================================================
-- PLAYBACK STATE
--===================================================================

get_playback = function()
    if os.time() - last_playback < 5 then return end
    last_playback = os.time()
    local d = api_get("me/player")
    if not d or not d.item then
        current_track = nil; current_id = nil; is_playing = false; return
    end
    local prev_id = current_id
    current_track = d.item
    current_id    = d.item.id
    is_playing    = d.is_playing == true
    is_shuffle    = d.shuffle_state == true
    repeat_state  = d.repeat_state or "off"
    if is_playing and current_id and current_id ~= prev_id then
        local last = read_file("/tmp/spotirofi_last_notify") or ""
        if trim(last) ~= current_id then
            notify_track(current_track)
        end
    end
end

local function inv_playback()
    current_track = nil; current_id = nil; is_playing = false; last_playback = 0
end

--===================================================================
-- DISPLAY HELPERS
--===================================================================

local function display_track(item, hide_artist)
    local an = hide_artist and "" or artist_names(item)
    local p  = item.id == current_id and (is_playing and "\u{f04b} " or "\u{f04c} ") or ""
    local l  = liked[item.id] and "\u{f05d}  " or ""
    local txt = p .. l .. (item.name or "Unknown") .. (hide_artist and "" or "  " .. an)
    if item.id == current_id then txt = "<span foreground=\"#b6e0a4\">" .. txt .. "</span>" end
    return txt
end

local function display_album(item)
    return (item.name or "Unknown") .. "  " .. artist_names(item)
end

local function display_artist(item)
    return item.name or "Unknown"
end

local function display_playlist(item)
    return (item.name or "Unknown")
end

local function get_playerctl_position()
    local raw = shell("playerctl position 2>/dev/null")
    return tonumber(trim(raw or "")) or 0
end

local function track_mesg(item)
    local p = item.id == current_id and (is_playing and "\u{f04b}" or "\u{f04c}") or ""
    local l = liked[item.id] and "\u{f05d}" or ""
    return p .. "  " .. (item.name or "") .. "  " .. artist_names(item) .. "  " .. l
end

local function seek_mesg(item)
    local row1 = track_mesg(item)
    local pos = math.max(get_playerctl_position(), 0)
    local dur = (item.duration_ms or 0) / 1000
    if dur <= 0 then return row1 end
    local elapsed = string.format("%d:%02d", math.floor(pos / 60), math.floor(pos % 60))
    local total = string.format("%d:%02d", math.floor(dur / 60), math.floor(dur % 60))
    local pct = math.min(pos / dur, 1)
    local bar_w = 20
    local filled = math.floor(pct * bar_w + 0.5)
    local bar = string.rep("\u{2588}", filled) .. string.rep("\u{2591}", bar_w - filled)
    return row1 .. "\n" .. elapsed .. "  " .. bar .. "  " .. total
end

--===================================================================
-- QUEUE
--===================================================================

local queue_tracks = nil
local queue_idx    = 0

local function load_queue()
    local raw = read_file(QUEUE_FILE)
    if not raw then return end
    local ok, d = pcall(json.decode, raw)
    if ok and type(d) == "table" then
        queue_tracks = d.tracks
        queue_idx    = d.idx or 0
    end
end

local function save_queue(items, idx)
    local tids = {}
    for _, t in ipairs(items or {}) do
        if type(t) == "table" and t.id then tids[#tids+1] = t.id end
    end
    queue_tracks = tids
    queue_idx    = idx
    write_file(QUEUE_FILE, json.encode({tracks=tids, idx=idx}))
end

local function flush_queue()
    if not queue_tracks then return end
    write_file(QUEUE_FILE, json.encode({tracks=queue_tracks, idx=queue_idx}))
end

--===================================================================
-- ACTIONS
--===================================================================

local function do_play(item, ctx, ctx_type, ctx_id, all_items, idx)
    if all_items and idx then save_queue(all_items, idx) end
    local token = get_token()
    if not token then return end
    local device_id = get_spotifyd_device()
    local dparam = device_id and "?device_id=" .. device_id or ""

    local context_uri
    if ctx_type and ctx_id then context_uri = "spotify:" .. ctx_type .. ":" .. ctx_id
    elseif ctx == "discover-weekly" then context_uri = "spotify:playlist:37i9dQZEVXcQHbTJZxVQMH"
    elseif ctx == "release-radar"   then context_uri = "spotify:playlist:37i9dQZEVXbxxd7f2YoHEu"
    elseif ctx == "new-music-friday" then context_uri = "spotify:playlist:37i9dQZF1DWXJfnUiYjUKT"
    end

    if context_uri then
        local body = json.encode({context_uri=context_uri, offset={position=(idx or 1)-1}})
        shell(string.format("curl -s --max-time 3 -o /dev/null -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/play%s' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s", dparam, token, shell_quote(body)))
    elseif all_items and idx then
        local uris = {}
        for i = idx, math.min(#all_items, idx + 49) do
            if all_items[i] and all_items[i].id then uris[#uris+1] = "spotify:track:" .. all_items[i].id end
        end
        if #uris > 0 then
            local body = json.encode({uris=uris, offset={position=0}})
            shell(string.format("curl -s --max-time 3 -o /dev/null -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/play%s' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s", dparam, token, shell_quote(body)))
        end
    else
        local body = json.encode({uris={"spotify:track:" .. item.id}})
        shell(string.format("curl -s --max-time 3 -o /dev/null -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/play%s' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s", dparam, token, shell_quote(body)))
    end
end

local function do_like(item, unlike)
    local token = get_token()
    if not token then rofi_message("Cannot like: no token"); return false end
    local verb = unlike and "DELETE" or "PUT"
    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -o /dev/null -X %s 'https://api.spotify.com/v1/me/tracks?ids=%s' -H 'Authorization: Bearer %s'", verb, item.id, token))
    if not r or not tonumber(r) or tonumber(r) >= 300 then
        rofi_message(unlike and "Failed to unlike" or "Failed to like")
        return false
    end
    if unlike then liked[item.id] = nil else liked[item.id] = true end
    -- update local cache
    local cache = safe_decode(read_file(LIKED_CACHE))
    if cache and cache.tracks then
        if unlike then
            for i = #cache.tracks, 1, -1 do
                if cache.tracks[i].id == item.id then table.remove(cache.tracks, i); break end
            end
        else
            item.added_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
            table.insert(cache.tracks, 1, item)
        end
        cache.fetched_at = os.time()
        write_file(LIKED_CACHE, json.encode(cache))
    end
    -- update lightweight ID list
    local ids = {}
    for _, t in ipairs(cache.tracks or {}) do if t.id then ids[#ids+1] = t.id end end
    write_file(LIKED_IDS, json.encode(ids))
    return true
end

local function api_check_following(artist_id)
    local token = get_token()
    if not token then return false end
    local r = api_get("me/following/contains?type=artist&ids=" .. artist_id)
    return r and r[1] == true
end

local function do_follow_artist(artist_id, follow)
    local token = get_token()
    if not token then return false end
    local verb = follow and "PUT" or "DELETE"
    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -o /dev/null -X %s 'https://api.spotify.com/v1/me/following?type=artist&ids=%s' -H 'Authorization: Bearer %s' -H 'Content-Length: 0'", verb, artist_id, token))
    return r and r:match("2..")
end

local function do_add_queue(track_id)
    local token = get_token()
    if not token then rofi_message("Cannot add to queue: no token"); return end
    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X POST 'https://api.spotify.com/v1/me/player/queue?uri=spotify:track:%s' -H 'Authorization: Bearer %s' -o /dev/null", track_id, token))
    if not r or not r:match("2..") then rofi_message("Failed to add to queue"); return end
    -- also add to local queue tracking
    if not queue_tracks then queue_tracks = {}; queue_idx = 0 end
    queue_tracks[#queue_tracks+1] = track_id
    flush_queue()
end

local function do_save_album(album_id)
    local token = get_token()
    if not token then rofi_message("Cannot save album: no token"); return false end
    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/albums?ids=%s' -H 'Authorization: Bearer %s' -o /dev/null", album_id, token))
    if r and r:match("2..") then
        disk_bust(ALBUM_CACHE)
        return true
    end
    return false
end

local function do_save_playlist(playlist_id)
    local token = get_token()
    if not token then rofi_message("Cannot save playlist: no token"); return false end
    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/playlists/%s/followers' -H 'Authorization: Bearer %s' -H 'Content-Length: 0' -o /dev/null", playlist_id, token))
    if r and r:match("2..") then
        disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists")
        disk_bust(CACHE .. "/made_for_you.json"); mem_bust("made_for_you")
        return true
    end
    return false
end

local function do_playback_cmd(cmd)
    local token = get_token()
    if not token then return nil end
    return shell(string.format("curl -s --max-time 3 -o /dev/null -w '%%{http_code}' -X POST 'https://api.spotify.com/v1/me/player/%s' -H 'Authorization: Bearer %s' -H 'Content-Length: 0'", cmd, token))
end

--===================================================================
-- API HELPERS
--===================================================================

local function api_get_album(album_id)
    return cached_fetch("album_" .. album_id, CACHE .. "/album_" .. album_id .. ".json", 86400, function()
        local d = api_get("albums/" .. album_id)
        if not d then return nil end
        if d.tracks then
            local tracks = {}
            if d.tracks.items then
                for _, t in ipairs(d.tracks.items) do tracks[#tracks+1] = t end
            end
            local next_url = d.tracks.next
            while next_url and #tracks < (d.total_tracks or 999) do
                local params = next_url:match("%?(.+)")
                local page = api_get("albums/" .. album_id .. "/tracks", params)
                if not page or not page.items or #page.items == 0 then break end
                for _, t in ipairs(page.items) do tracks[#tracks+1] = t end
                next_url = page.next
            end
            d.tracks = tracks
        end
        return d
    end)
end

local function api_get_playlist_tracks(playlist_id)
    return cached_fetch("playlist_tracks_" .. playlist_id, CACHE .. "/playlist_tracks_" .. playlist_id .. ".json", 1800, function()
        local all_tracks = {}
        local offset = 0
        while true do
            local params = "limit=100&offset=" .. offset .. "&fields=items(track(id,name,duration_ms,artists,album(id,name,images)),added_at),next"
            local d = api_get("playlists/" .. playlist_id .. "/tracks", params)
            if not d or not d.items or #d.items == 0 then break end
            for _, entry in ipairs(d.items) do
                if entry.track and entry.track.id then
                    entry.track.added_at = entry.added_at
                    all_tracks[#all_tracks+1] = entry.track
                end
            end
            if not d.next or #d.items < 100 then break end
            offset = offset + 100
        end
        return #all_tracks > 0 and all_tracks or nil
    end)
end

local function api_search(query, stype)
    local mem_key = "search:" .. query .. ":" .. stype
    local cached = mem_get(mem_key)
    if cached then return cached end
    local d = api_get("search", "q=" .. query:gsub(" ", "+") .. "&type=" .. stype .. "&limit=" .. MAX_RESULTS)
    if d then
        for _, k in ipairs({"tracks","albums","artists","playlists"}) do
            if d[k] and d[k].items then d[k] = d[k].items end
        end
        mem_set(mem_key, d, 30)
    end
    return d
end

local function api_get_me()
    return cached_fetch("me_profile", CACHE .. "/me_profile.json", 3600, function()
        return api_get("me")
    end)
end

local function api_get_my_playlists()
    return cached_fetch("my_playlists", CACHE .. "/my_playlists.json", 300, function()
        local all = {}
        local offset = 0
        while true do
            local d = api_get("me/playlists", "limit=50&offset=" .. offset)
            if not d or not d.items or #d.items == 0 then break end
            for _, pl in ipairs(d.items) do all[#all+1] = pl end
            if not d.next or #d.items < 50 then break end
            offset = offset + 50
        end
        return #all > 0 and all or nil
    end)
end

local function api_get_artist_albums(artist_id)
    return cached_fetch("artist_albums_" .. artist_id, CACHE .. "/artist_albums_" .. artist_id .. ".json", 86400, function()
        return api_get("artists/" .. artist_id .. "/albums", "limit=50&include_groups=album,single,compilation")
    end)
end

local function api_get_artist_top_tracks(artist_id)
    return cached_fetch("artist_top_" .. artist_id, CACHE .. "/artist_top_" .. artist_id .. ".json", 3600, function()
        local me = api_get_me()
        local market = me and me.country
        local params = market and ("market=" .. market) or ""
        return api_get("artists/" .. artist_id .. "/top-tracks", params)
    end)
end

local function api_get_artist_related(artist_id)
    return cached_fetch("artist_related_" .. artist_id, CACHE .. "/artist_related_" .. artist_id .. ".json", 86400, function()
        return api_get("artists/" .. artist_id .. "/related-artists")
    end)
end

local function api_get_categories()
    return cached_fetch("categories", CACHE .. "/categories.json", 86400, function()
        local d = api_get("browse/categories", "limit=50")
        if d and d.categories and d.categories.items then return d.categories.items end
    end)
end

local function api_get_category_playlists(cat_id)
    return cached_fetch("category_playlists_" .. cat_id, CACHE .. "/category_playlists_" .. cat_id .. ".json", 3600, function()
        local d = api_get("browse/categories/" .. cat_id .. "/playlists", "limit=20")
        if d and d.playlists and d.playlists.items then return d.playlists.items end
    end)
end

local function api_get_top_tracks()
    for _, rng in ipairs({"medium_term","long_term","short_term"}) do
        local tracks = cached_fetch("top_tracks_" .. rng, CACHE .. "/top_tracks_" .. rng .. ".json", 3600, function()
            local d = api_get("me/top/tracks", "limit=50&time_range=" .. rng)
            return (d and d.items and #d.items > 0) and d.items
        end)
        if tracks then return tracks end
    end
end



local function api_get_new_releases()
    return cached_fetch("new_releases", CACHE .. "/new_releases.json", 86400, function()
        local d = api_get("browse/new-releases", "limit=20")
        if d and d.albums and d.albums.items and #d.albums.items > 0 then return d.albums.items end
    end)
end

local function api_get_made_for_you()
    return cached_fetch("made_for_you", CACHE .. "/made_for_you.json", 86400, function()
        local all = api_get_my_playlists() or {}
        local spotify_pls = {}
        for _, pl in ipairs(all) do
            if pl.owner and pl.owner.id == "spotify" then
                spotify_pls[#spotify_pls+1] = pl
            end
        end
        return #spotify_pls > 0 and spotify_pls or nil
    end)
end

local function lyrics_to_lines(plain)
    if not plain then return nil end
    local lines = {}
    for line in plain:gmatch("[^\n]+") do
        if #line > 0 then lines[#lines+1] = line end
    end
    return #lines > 0 and lines or nil
end

local function normalize_str(s)
    return (s or ""):lower():gsub("[^%w%s]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function api_get_lyrics(track_name, artist_name, album_name, duration)
    local get_url = "https://lrclib.net/api/get?track_name=" .. url_encode(track_name)
    if artist_name and #artist_name > 0 then get_url = get_url .. "&artist_name=" .. url_encode(artist_name) end
    if album_name and #album_name > 0 then get_url = get_url .. "&album_name=" .. url_encode(album_name) end
    if duration and duration > 0 then get_url = get_url .. "&duration=" .. tostring(math.floor(duration)) end
    local r = trim(shell("curl -s --max-time 5 " .. shell_quote(get_url)))
    local d = safe_decode(r)
    if d and d.plainLyrics then
        local lines = lyrics_to_lines(d.plainLyrics)
        if lines then return lines end
    end

    local search_url = "https://lrclib.net/api/search?track_name=" .. url_encode(track_name)
    if artist_name and #artist_name > 0 then search_url = search_url .. "&artist_name=" .. url_encode(artist_name) end
    r = trim(shell("curl -s --max-time 5 " .. shell_quote(search_url)))
    d = safe_decode(r)
    if not d or #d == 0 then return nil end

    local norm_track  = normalize_str(track_name)
    local norm_artist = normalize_str(artist_name)
    local norm_album  = normalize_str(album_name)
    local best, best_score = nil, -1
    for _, entry in ipairs(d) do
        if entry.plainLyrics then
            local score = 0
            if normalize_str(entry.trackName)  == norm_track  then score = score + 10 end
            if normalize_str(entry.artistName) == norm_artist then score = score + 10 end
            if norm_album ~= "" and normalize_str(entry.albumName) == norm_album then score = score + 3 end
            if duration and entry.duration then
                local diff = math.abs(duration - entry.duration)
                if diff <= 2 then score = score + 5
                elseif diff <= 10 then score = score + 2 end
            end
            if score > best_score then best_score = score; best = entry end
        end
    end
    return best and lyrics_to_lines(best.plainLyrics)
end

--===================================================================
-- VIEW: BROWSE
--===================================================================

local function view_browse(entries, items, mesg, ctx, ctx_type, ctx_id)
    local is_track = ctx == "liked" or ctx == "top-tracks"
                  or ctx == "discover-weekly" or ctx == "release-radar"
                  or ctx == "new-music-friday" or ctx == "your-queue"
                  or ctx == "liked-by-artist" or ctx == "top-by-artist"
                  or ctx == "track"
                  or (ctx_type and ctx_id)
    local is_album_list   = ctx == "album-list" or (ctx_type == "album" and not ctx_id) or ctx == "album" or ctx == "search-album"
    local is_artist_list  = ctx == "artist-list" or ctx == "artist"
    local is_playlist_list = ctx_type == "playlist" and not ctx_id or ctx == "search-playlist"
    local is_search_all   = ctx == "all"

    while true do
        local idx = rofi_dmenu(entries, {prompt=ctx or "Browse", mesg=mesg, custom=false, by_index=true, markup=is_track, use_menu=true})
        if not idx then return nil end
        if idx < 1 or idx > #items then goto br_next end
        local item = items[idx]

        if is_track then
            view_actions(item, ctx, ctx_type, ctx_id, items, idx, entries)
            entries[idx] = string.format("%2d. %s", idx, display_track(item))
        elseif is_search_all then
            local st = item._stype
            if st == "tracks" then view_actions(item, ctx, ctx_type, ctx_id, items, idx, entries)
            elseif st == "albums" then
                local action = rofi_dmenu({"Open Album", "Save Album"}, {prompt=item.name or "Album", mesg=artist_names(item), custom=false, theme=THEME_SUB})
                if action == "Save Album" then
                    rofi_message(do_save_album(item.id) and "Album saved" or "Failed to save album")
                elseif action == "Open Album" then
                    local ad = api_get_album(item.id)
                    if ad and ad.tracks and #ad.tracks > 0 then
                        session_push({view="album", album_id=item.id})
                        local te = {}
                        for i, t in ipairs(ad.tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t, true)) end
                        view_browse(te, ad.tracks, item.name .. " - " .. artist_names(item), "album", "album", item.id)
                    else rofi_message("Failed to load album") end
                end
            elseif st == "artists" then
                view_artist(item)
            elseif st == "playlists" then
                local action = rofi_dmenu({"Open Playlist", "Save Playlist"}, {prompt=item.name or "Playlist", mesg=artist_names(item), custom=false, theme=THEME_SUB})
                if action == "Save Playlist" then
                    rofi_message(do_save_playlist(item.id) and "Playlist saved" or "Failed to save playlist")
                elseif action == "Open Playlist" then
                local tracks = api_get_playlist_tracks(item.id)
                if tracks and #tracks > 0 then
                    session_push({view="playlist", playlist_id=item.id})
                    local te = {}
                    for i, t in ipairs(tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t)) end
                    view_browse(te, tracks, item.name .. " - " .. #tracks .. " tracks", "playlist", "playlist", item.id)
                else rofi_message("Failed to load playlist") end
                end
            end
            local pf = ""
            if st=="tracks" then pf="\u{F0387} " elseif st=="albums" then pf="\u{F0025} "
            elseif st=="artists" then pf="\u{F415} " elseif st=="playlists" then pf="\u{F0411} " end
            entries[idx] = string.format("%2d. %s", idx, pf .. (item.name or "Unknown"))
        elseif is_album_list then
            local do_open = true
            if ctx == "search-album" then
                local action = rofi_dmenu({"Open Album", "Save Album"}, {prompt=item.name or "Album", mesg=artist_names(item), custom=false, theme=THEME_SUB})
                if action == "Save Album" then
                    rofi_message(do_save_album(item.id) and "Album saved" or "Failed to save album")
                    do_open = false
                elseif action == "Open Album" then
                end
            elseif ctx == "album-list" then
                local action = rofi_dmenu({"Open Album", "Remove from Library"}, {prompt=item.name or "Album", mesg=artist_names(item), custom=false, theme=THEME_SUB})
                if action == "Remove from Library" then
                    local token = get_token()
                    if token then
                        local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X DELETE 'https://api.spotify.com/v1/me/albums?ids=%s' -H 'Authorization: Bearer %s' -o /dev/null", item.id, token))
                        if r and r:match("2..") then
                            disk_bust(ALBUM_CACHE)
                            rofi_message("Removed from library")
                            table.remove(entries, idx); table.remove(items, idx); goto br_next
                        else rofi_message("Failed to remove") end
                    end
                    do_open = false
                elseif action == "Open Album" then
                end
            end
            if do_open then
                local ad = api_get_album(item.id)
                if ad and ad.tracks and #ad.tracks > 0 then
                    session_push({view="album", album_id=item.id})
                    local te = {}
                    for i, t in ipairs(ad.tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t, true)) end
                    view_browse(te, ad.tracks, item.name .. " - " .. artist_names(item), "album", "album", item.id)
                else rofi_message("Failed to load album") end
            end
        elseif is_artist_list then
            view_artist(item)
            entries[idx] = string.format("%2d. %s", idx, display_artist(item))
        elseif is_playlist_list then
            local do_open = true
            if ctx == "search-playlist" then
                local action = rofi_dmenu({"Open Playlist", "Save Playlist"}, {prompt=item.name or "Playlist", mesg=artist_names(item), custom=false, theme=THEME_SUB})
                if action == "Save Playlist" then
                    rofi_message(do_save_playlist(item.id) and "Playlist saved" or "Failed to save playlist")
                    do_open = false
                elseif action == "Open Playlist" then
                end
            end
            if do_open then
                local tracks = api_get_playlist_tracks(item.id)
                if tracks and #tracks > 0 then
                    session_push({view="playlist", playlist_id=item.id})
                    local te = {}
                    for i, t in ipairs(tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t)) end
                    view_browse(te, tracks, item.name .. " - " .. #tracks .. " tracks", "playlist", "playlist", item.id)
                else rofi_message("Failed to load playlist") end
            end
        end
        ::br_next::
    end
end

--===================================================================
-- VIEW: TRACK ACTIONS
--===================================================================

view_actions = function(item, ctx, ctx_type, ctx_id, all_items, cidx, entries)
    session_push({view="action", track_id=item.id, track_name=item.name or "",
                  track_artists=item.artists or {}, track_album=item.album or {},
                  track_duration_ms=item.duration_ms or 0})
    local is_liked = liked[item.id]
    local in_pl    = ctx_type == "playlist" and ctx_id

    local play_label = item.id == current_id and (is_playing and "Pause" or "Resume") or "Play"
    local actions = {play_label, "Seek", "Add to Queue",
                     is_liked and "Unlike" or "Like",
                     "Go to Album", "Go to Artist", "Add to Playlist"}
    if in_pl then actions[#actions+1] = "Remove from Playlist" end
    actions[#actions+1] = "Lyrics"
    actions[#actions+1] = "Copy URL"

    while true do
        local sel = rofi_dmenu(actions, {prompt="Action", mesg=track_mesg(item), sel=0, custom=false, theme=THEME_SUB})
        if not sel or sel == "" then return end

        if sel == "Resume" then
            os.execute("playerctl play 2>/dev/null")
            is_playing = true
            actions[1] = "Pause"
        elseif sel == "Play" then
            do_play(item, ctx, ctx_type, ctx_id, all_items, cidx)
            inv_playback()
            actions[1] = "Pause"
        elseif sel == "Pause" then
            os.execute("playerctl pause 2>/dev/null")
            is_playing = false
            actions[1] = "Resume"
        elseif sel == "Add to Queue" then do_add_queue(item.id)
        elseif sel == "Like" or sel == "Unlike" then
            if do_like(item, sel == "Unlike") then
                is_liked = not is_liked
                actions[3] = is_liked and "Unlike" or "Like"
            end
        elseif sel == "Go to Album" then
            local album = item.album
            if album and album.id then
                local ad = api_get_album(album.id)
                if ad and ad.tracks and #ad.tracks > 0 then
                    session_push({view="album", album_id=album.id})
                    local te = {}
                    for i, t in ipairs(ad.tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t, true)) end
                    view_browse(te, ad.tracks, album.name .. " - " .. artist_names(album), "album", "album", album.id)
                end
            end
        elseif sel == "Go to Artist" then
            if item.artists and #item.artists > 0 then view_artist(item.artists[1]) end
        elseif sel == "Add to Playlist" then view_add_pl(item.id)
        elseif sel == "Remove from Playlist" then
            local token = get_token()
            if token then
                local body = json.encode({tracks={{uri="spotify:track:" .. item.id}}})
                local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X DELETE 'https://api.spotify.com/v1/playlists/%s/tracks' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s -o /dev/null", ctx_id, token, shell_quote(body)))
                if r and r:match("2..") then
                    disk_bust(CACHE .. "/playlist_tracks_" .. ctx_id .. ".json"); mem_bust("playlist_tracks_" .. ctx_id)
                    if entries and cidx then
                        table.remove(entries, cidx)
                        table.remove(all_items, cidx)
                    end
                    session_pop(); return
                end
            end
        elseif sel == "Lyrics" then view_lyrics(item)
        elseif sel == "Seek" then
            session_push({view="seek", track_id=item.id, track_name=item.name or "", track_artists=item.artists or {}, track_duration_ms=item.duration_ms or 0})
            local seeks = {"+10s", "-10s", "+30s", "-30s", "1:00", "2:00", "0:00"}
            while true do
                local si = rofi_dmenu(seeks, {prompt="Seek", mesg=seek_mesg(item), sel=0, custom=false, theme=THEME_SUB})
                if not si or si == "" then break end
                if si:match("^([%+%-])(%d+)s$") then
                    local sign, secs = si:match("^([%+%-])(%d+)s$")
                    os.execute("playerctl position " .. secs .. sign .. " &")
                else
                    local m, s = si:match("^(%d+):(%d+)$")
                    if m and s then os.execute("playerctl position " .. (tonumber(m) * 60 + tonumber(s)) .. " &") end
                end
            end
        end
    end
end

--===================================================================
-- VIEW: ARTIST ACTIONS
--===================================================================

view_artist = function(artist)
    session_push({view="artist-actions", artist_id=artist.id, artist_name=artist.name or ""})
    local is_followed = api_check_following(artist.id)
    local actions = {"View All Albums", "View Liked Tracks", "View Top Tracks",
                     "Related Artists",
                     is_followed and "Unfollow Artist" or "Follow Artist"}

    while true do
        local sel = rofi_dmenu(actions, {prompt=artist.name or "Artist", mesg=(artist.name or "") .. " - Artist Options", sel=0, custom=false, use_menu=true})
        if not sel or sel == "" then return end

        if sel == "View All Albums" then
            session_push({view="artist-albums", artist_id=artist.id, artist_name=artist.name or ""})
            local d = api_get_artist_albums(artist.id)
            if not d or not d.items then session_pop(); rofi_message("No albums found")
            else
                local ae = {}
                for i, a in ipairs(d.items) do ae[i] = display_album(a) end
                while true do
                    local aidx = rofi_dmenu(ae, {prompt=artist.name, mesg=artist.name .. " - " .. #d.items .. " albums", custom=false, by_index=true, use_menu=true})
                    if not aidx then session_pop(); break end
                    if aidx >= 1 and aidx <= #d.items then
                        local ad = api_get_album(d.items[aidx].id)
                        if ad and ad.tracks and #ad.tracks > 0 then
                            session_push({view="album", album_id=d.items[aidx].id})
                            local te = {}
                            for i, t in ipairs(ad.tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t, true)) end
                            view_browse(te, ad.tracks, d.items[aidx].name .. " - " .. artist_names(d.items[aidx]), "album", "album", d.items[aidx].id)
                        end
                    end
                end
            end
        elseif sel == "View Liked Tracks" then
            session_push({view="liked-by-artist", artist_id=artist.id, artist_name=artist.name or ""})
            local all_tracks = load_liked_tracks()
            local tracks = {}
            for _, t in ipairs(all_tracks) do
                for _, a in ipairs(t.artists or {}) do
                    if a.id == artist.id or (a.name or ""):lower() == (artist.name or ""):lower() then
                        tracks[#tracks+1] = t; break
                    end
                end
            end
            if #tracks == 0 then session_pop(); rofi_message("No liked tracks by this artist")
            else
                table.sort(tracks, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
                local te = {}
                for i, t in ipairs(tracks) do te[i] = string.format("%2d. %s", i, display_track(t, true)) end
                view_browse(te, tracks, artist.name .. " - " .. #tracks .. " liked tracks", "liked-by-artist", nil, nil)
            end
        elseif sel == "View Top Tracks" then
            session_push({view="top-by-artist", artist_id=artist.id, artist_name=artist.name or ""})
            local d = api_get_artist_top_tracks(artist.id)
            if not d or not d.tracks or #d.tracks == 0 then session_pop(); rofi_message("No top tracks found")
            else
                local te = {}
                for i, t in ipairs(d.tracks) do te[i] = string.format("%2d. %s", i, display_track(t, true)) end
                view_browse(te, d.tracks, artist.name .. " - " .. #d.tracks .. " top tracks", "top-by-artist", nil, nil)
            end
        elseif sel == "Related Artists" then
            session_push({view="related", artist_id=artist.id, artist_name=artist.name or ""})
            local d = api_get_artist_related(artist.id)
            if not d or not d.artists or #d.artists == 0 then session_pop(); rofi_message("No related artists found")
            else
                local ae = {}
                for i, a in ipairs(d.artists) do ae[i] = display_artist(a) end
                while true do
                    local ridx = rofi_dmenu(ae, {prompt="Related to " .. artist.name, mesg=artist.name .. " - " .. #d.artists .. " related", custom=false, by_index=true, use_menu=true})
                    if not ridx then session_pop(); break end
                    if ridx >= 1 and ridx <= #d.artists then view_artist(d.artists[ridx]) end
                end
            end
        elseif sel == "Follow Artist" or sel == "Unfollow Artist" then
            local success = do_follow_artist(artist.id, sel == "Follow Artist")
            if success then
                is_followed = not is_followed
                actions[5] = is_followed and "Unfollow Artist" or "Follow Artist"
            else
                rofi_message("Failed to " .. (sel == "Follow Artist" and "follow" or "unfollow") .. " artist")
            end
        end
    end
end

--===================================================================
-- VIEW: LYRICS (via lrclib.net)
--===================================================================

view_lyrics = function(item)
    session_push({view="lyrics", track_id=item.id, track_name=item.name or "", track_artists=item.artists or {}})
    local id = item.id or ""
    local dur = item.duration_ms and item.duration_ms / 1000 or nil
    local alb = item.album and item.album.name or nil
    local lines = cached_fetch("lyrics_" .. id, LYRICS_DIR .. "/lyrics_" .. id .. ".json", nil, function()
        return api_get_lyrics(item.name, artist_names(item), alb, dur)
    end)
    if not lines or #lines == 0 then session_pop(); rofi_message("No lyrics found"); return end
    rofi_dmenu(lines, {prompt="Lyrics", mesg=track_mesg(item), custom=false, use_menu=true, theme=THEME_LYR})
end

--===================================================================
-- VIEW: ADD TO PLAYLIST
--===================================================================

view_add_pl = function(track_id)
    session_push({view="add-to-playlist", track_id=track_id})
    local token = get_token()
    if not token then session_pop(); return end
    local items = api_get_my_playlists()
    if not items then session_pop(); return end
    local me = api_get_me()
    local my_id = me and me.id

    local names = {"Create New Playlist"}
    local ids   = {"__create__"}
    for _, p in ipairs(items) do
        if p.owner and (p.owner.id == my_id or p.collaborative) then
            names[#names+1] = p.name; ids[#ids+1] = p.id
        end
    end

    local idx = rofi_dmenu(names, {prompt="Add to Playlist", mesg="Select a playlist", custom=false, by_index=true, use_menu=true})
    if not idx or idx < 1 or idx > #names then session_pop(); return end

    local target_id
    if ids[idx] == "__create__" then
        local pl_name = rofi_input("New Playlist", "")
        if pl_name == "" then session_pop(); return end
        local r = shell(string.format("curl -s --max-time 5 -X POST 'https://api.spotify.com/v1/users/%s/playlists' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s", my_id, token, shell_quote(json.encode({name=pl_name}))))
        local cr = safe_decode(r)
        if not cr or not cr.id then session_pop(); rofi_message("Failed to create playlist"); return end
        target_id = cr.id
        disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists")
    else
        target_id = ids[idx]
    end

    local body = json.encode({uris={"spotify:track:" .. track_id}})
    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X POST 'https://api.spotify.com/v1/playlists/%s/tracks' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s -o /dev/null", target_id, token, shell_quote(body)))
    if r and r:match("2..") then disk_bust(CACHE .. "/playlist_tracks_" .. target_id .. ".json"); mem_bust("playlist_tracks_" .. target_id) end
    rofi_message(r and r:match("2..") and "Added to playlist" or "Failed to add track")
    session_pop()
end

--===================================================================
-- VIEW: PLAYLISTS
--===================================================================

local function view_playlists()
    session_push({view="playlists"})
    local token = get_token()
    if not token then rofi_message("No auth"); return end
    local pls = api_get_my_playlists() or {}
    local entries = {"Create New Playlist"}
    for i, p in ipairs(pls) do entries[#entries+1] = display_playlist(p) end

    while true do
        local idx = rofi_dmenu(entries, {prompt="Playlists", mesg="Playlists - " .. #pls, custom=false, by_index=true, use_menu=true})
        if not idx then return end
        if idx == 1 then
            local pl_name = rofi_input("New Playlist", "")
            if pl_name == "" then goto pl_loop end
            local me = api_get_me()
            if me and me.id then
                local r = shell(string.format("curl -s --max-time 5 -X POST 'https://api.spotify.com/v1/users/%s/playlists' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s", me.id, token, shell_quote(json.encode({name=pl_name}))))
                local cr = safe_decode(r)
                if cr then pls[#pls+1] = cr; entries[#entries+1] = display_playlist(cr); disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists")
                else rofi_message("Failed to create") end
            end
        elseif idx >= 2 and idx - 1 <= #pls then
            local pl = pls[idx - 1]
            session_push({view="playlist-actions", playlist_id=pl.id, playlist_name=pl.name or "Playlist"})
            local acts = {"Open Playlist", "Rename Playlist", "Delete Playlist"}
            ::pl_act::
            local asel = rofi_dmenu(acts, {prompt=pl.name, mesg=display_playlist(pl), sel=0, custom=false, use_menu=true})
            if not asel or asel == "" then break end
            if asel == "Open Playlist" then
                local tracks = api_get_playlist_tracks(pl.id)
                if tracks then
                    session_push({view="playlist", playlist_id=pl.id})
                    local te = {}
                    for i, t in ipairs(tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t)) end
                    view_browse(te, tracks, pl.name .. " - " .. #tracks .. " tracks", "playlist", "playlist", pl.id)
                end
                goto pl_act
            elseif asel == "Rename Playlist" then
                local nn = rofi_input("New Name", pl.name or "")
                if nn == "" or nn == (pl.name or "") then goto pl_act end
                local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/playlists/%s' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s -o /dev/null", pl.id, token, shell_quote(json.encode({name=nn}))))
                if r and r:match("2..") then pl.name = nn; disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists"); rofi_message("Renamed") else rofi_message("Failed") end
                goto pl_act
            elseif asel == "Delete Playlist" then
                local c = rofi_dmenu({"Yes, delete","Cancel"}, {prompt="Delete", mesg="Delete '" .. (pl.name or "") .. "'?", custom=false, by_index=true, use_menu=true})
                if c == 1 then
                    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X DELETE 'https://api.spotify.com/v1/playlists/%s/followers' -H 'Authorization: Bearer %s' -o /dev/null", pl.id, token))
                    if r and r:match("2..") then
                        disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists")
                        disk_bust(CACHE .. "/playlist_tracks_" .. pl.id .. ".json"); mem_bust("playlist_tracks_" .. pl.id)
                        rofi_message("Deleted")
                        table.remove(entries, idx); table.remove(pls, idx - 1); break
                    else rofi_message("Failed to delete") end
                end
                goto pl_act
            end
        end
        ::pl_loop::
    end
end

--===================================================================
-- VIEW: SEARCH
--===================================================================

local function view_search(category)
    while true do
        local key = category == "all" and "all" or category .. "s"
        local query = rofi_dmenu({}, {prompt="Search " .. category:sub(1,1):upper() .. category:sub(2), mesg="Search " .. key, use_menu=true})
        if not query or query == "" then return end
        local stype = category == "all" and "track,album,artist,playlist" or category
        local results = api_search(query, stype)
        if not results then rofi_message("No results"); return end

        session_push({view="search-results", category=category, query=query})

        if category == "all" then
            local items = {}
            for _, rk in ipairs({"tracks","albums","artists","playlists"}) do
                local ci = results[rk]
                if ci and type(ci) == "table" then
                    for i = 1, math.min(#ci, 5) do ci[i]._stype = rk; items[#items+1] = ci[i] end
                end
            end
            if #items == 0 then session_pop(); goto sr_loop end
            local n = math.min(#items, MAX_RESULTS); local entries = {}
            for i = 1, n do
                local pfx, st = "", items[i]._stype
                if st == "tracks" then pfx = "\u{F0387} " elseif st == "albums" then pfx = "\u{F0025} " elseif st == "artists" then pfx = "\u{F415} " elseif st == "playlists" then pfx = "\u{F0411} " end
                entries[#entries+1] = string.format("%2d. %s", i, pfx .. (items[i].name or "Unknown"))
            end
            view_browse(entries, items, n .. " results for " .. query, "all", nil, nil)
        else
            local items = results[key]
            if not items or type(items) ~= "table" or #items == 0 then session_pop(); goto sr_loop end
            local n = math.min(#items, MAX_RESULTS); local entries = {}
            for i = 1, n do entries[#entries+1] = string.format("%2d. %s", i, (items[i].name or "Unknown")) end
            local sctx = (category == "album" or category == "playlist") and "search-" .. category or category
            view_browse(entries, items, n .. " " .. key .. " for " .. query, sctx,
                        (category == "album" and "album" or category == "playlist" and "playlist" or nil), nil)
        end
        ::sr_loop::
    end
end

--===================================================================
-- VIEW: CATEGORIES
--===================================================================

local function view_categories()
    local cats = api_get_categories()
    if not cats then if not rofi_message("Failed") then os.exit(0) end; return end
    session_push({view="categories"})
    local ce = {}
    for _, c in ipairs(cats) do ce[#ce+1] = c.name end

    while true do
        local idx = rofi_dmenu(ce, {prompt="Categories", mesg="Categories - " .. #cats, custom=false, by_index=true, use_menu=true})
        if not idx then return end
        if idx < 1 or idx > #cats then goto cat_loop end
        local cat = cats[idx]
        local pls = api_get_category_playlists(cat.id)
        if not pls then rofi_message("No playlists"); goto cat_loop end
        session_push({view="category-playlists", category_id=cat.id, category_name=cat.name})
        local pe = {}
        for _, pl in ipairs(pls) do pe[#pe+1] = display_playlist(pl) end
        view_browse(pe, pls, cat.name .. " - " .. #pls .. " playlists", "playlist", "playlist", nil)
        ::cat_loop::
    end
end

--===================================================================
-- VIEW: TOP TRACKS / LIKED / SAVED / FOLLOWED / CURATED / QUEUE
--===================================================================

local function view_top_tracks()
    local tracks = api_get_top_tracks()
    if not tracks then if not rofi_message("No top tracks") then os.exit(0) end; return end
    session_push({view="top-tracks"})
    local entries = {}
    for i, t in ipairs(tracks) do entries[i] = string.format("%2d. %s", i, display_track(t)) end
    return view_browse(entries, tracks, "Top Tracks - " .. #tracks .. " tracks", "top-tracks", nil, nil)
end

local function view_liked_tracks()
    local tracks = load_liked_tracks()
    for _, t in ipairs(tracks) do if t.id then liked[t.id] = true end end
    if #tracks == 0 then if not rofi_message("No liked tracks") then os.exit(0) end; return end
    session_push({view="liked"})
    local entries = {}
    for i, t in ipairs(tracks) do entries[i] = string.format("%2d. %s", i, display_track(t)) end
    return view_browse(entries, tracks, "Liked Tracks - " .. #tracks .. " tracks", "liked", nil, nil)
end

local function view_saved_albums()
    local al = load_saved_albums()
    if #al == 0 then if not rofi_message("No saved albums") then os.exit(0) end; return end
    session_push({view="saved-albums"})
    local entries = {}
    for i, a in ipairs(al) do entries[i] = display_album(a) end
    view_browse(entries, al, "Saved Albums - " .. #al .. " albums", "album-list", "album", nil)
end

local function view_followed_artists()
    local ar = load_followed_artists()
    if #ar == 0 then if not rofi_message("No followed artists") then os.exit(0) end; return end
    session_push({view="followed-artists"})
    local entries = {}
    for i, a in ipairs(ar) do entries[i] = display_artist(a) end
    view_browse(entries, ar, "Followed Artists - " .. #ar .. " artists", "artist-list", nil, nil)
end

local function view_weekly()
    local tracks = api_get_playlist_tracks("37i9dQZEVXcQHbTJZxVQMH")
    if not tracks or #tracks == 0 then if not rofi_message("No tracks") then os.exit(0) end; return end
    session_push({view="discover-weekly"})
    local entries = {}
    for i, t in ipairs(tracks) do entries[i] = string.format("%2d. %s", i, display_track(t)) end
    return view_browse(entries, tracks, "Discover Weekly - " .. #tracks .. " tracks", "discover-weekly", nil, nil)
end

local function view_release_radar()
    local tracks = api_get_playlist_tracks("37i9dQZEVXbxxd7f2YoHEu")
    if not tracks or #tracks == 0 then if not rofi_message("No tracks") then os.exit(0) end; return end
    session_push({view="release-radar"})
    local entries = {}
    for i, t in ipairs(tracks) do entries[i] = string.format("%2d. %s", i, display_track(t)) end
    return view_browse(entries, tracks, "Release Radar - " .. #tracks .. " tracks", "release-radar", nil, nil)
end

local function view_new_music_friday()
    local tracks = api_get_playlist_tracks("37i9dQZF1DWXJfnUiYjUKT")
    if not tracks or #tracks == 0 then if not rofi_message("No tracks") then os.exit(0) end; return end
    session_push({view="new-music-friday"})
    local entries = {}
    for i, t in ipairs(tracks) do entries[i] = string.format("%2d. %s", i, display_track(t)) end
    return view_browse(entries, tracks, "New Music Friday - " .. #tracks .. " tracks", "new-music-friday", nil, nil)
end

local function view_new_releases()
    local albums = api_get_new_releases() or {}
    if #albums == 0 then if not rofi_message("No new releases") then os.exit(0) end; return end
    session_push({view="new-releases"})
    local entries = {}
    for i, a in ipairs(albums) do entries[i] = display_album(a) end
    while true do
        local idx = rofi_dmenu(entries, {prompt="New Releases", mesg="New Releases - " .. #albums .. " albums", custom=false, by_index=true, use_menu=true})
        if not idx then break end
        if idx >= 1 and idx <= #albums then
            local ad = api_get_album(albums[idx].id)
            if ad and ad.tracks and #ad.tracks > 0 then
                session_push({view="album", album_id=albums[idx].id})
                local te = {}
                for i, t in ipairs(ad.tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t, true)) end
                view_browse(te, ad.tracks, albums[idx].name .. " - " .. artist_names(albums[idx]), "album", "album", albums[idx].id)
            end
        end
    end
end

local function view_made_for_you()
    local playlists = api_get_made_for_you() or {}
    if #playlists == 0 then if not rofi_message("No Spotify-curated playlists") then os.exit(0) end; return end
    session_push({view="made-for-you"})
    local entries = {}
    for i, pl in ipairs(playlists) do entries[i] = display_playlist(pl) end
    while true do
        local idx = rofi_dmenu(entries, {prompt="Made For You", mesg="Made For You - " .. #playlists .. " playlists", custom=false, by_index=true, use_menu=true})
        if not idx then break end
        if idx >= 1 and idx <= #playlists then
            local tracks = api_get_playlist_tracks(playlists[idx].id)
            if tracks and #tracks > 0 then
                session_push({view="playlist", playlist_id=playlists[idx].id})
                local te = {}
                for i, t in ipairs(tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t)) end
                view_browse(te, tracks, playlists[idx].name .. " - " .. #tracks .. " tracks", "playlist", "playlist", playlists[idx].id)
            end
        end
    end
end

local function view_your_queue()
    local d = api_get("me/player/queue")
    if not d then if not rofi_message("Queue is empty") then os.exit(0) end; return end
    local tracks = {}
    if d.currently_playing and type(d.currently_playing) == "table" and d.currently_playing.id then tracks[#tracks+1] = d.currently_playing end
    if d.queue then for _, t in ipairs(d.queue) do if type(t) == "table" and t.id then tracks[#tracks+1] = t end end end
    if #tracks == 0 then if not rofi_message("Queue is empty") then os.exit(0) end; return end
    session_push({view="your-queue"})
    local entries = {}
    for i, t in ipairs(tracks) do entries[i] = string.format("%2d. %s", i, display_track(t)) end
    return view_browse(entries, tracks, "Your Queue - " .. #tracks .. " tracks", "your-queue", nil, nil)
end

--===================================================================
-- VIEW: SYSTEM
--===================================================================

local function view_system()
    local items = {"Keybinds", '<span foreground="#e0d8a4">Refresh Library</span>',
                   '<span foreground="#fab387">Restart Daemons</span>',
                   '<span foreground="#e78284">Kill Daemons</span>'}
    while true do
        local sel = rofi_dmenu(items, {prompt="System", mesg="System", custom=false, use_menu=true, theme=THEME_SUB, markup=true})
        if not sel then break end
        local clean = sel:gsub("<[^>]+>", "")
        if clean == "Keybinds" then
            rofi_message("Alt+Return  →  Current track actions\nAlt+Backspace  →  Go back\nAlt+Space  →  Main menu\nAlt+/  →  Search all")
        elseif clean == "Refresh Library" then
            os.execute("notify-send -t 10000 --app-name=spotirofi 'Spotirofi' 'Refreshing library...' &")
            os.remove(LIKED_CACHE); os.remove(ALBUM_CACHE); os.remove(ARTIST_CACHE); os.remove(LIKED_IDS)
            load_liked_tracks(); load_saved_albums(); load_followed_artists(); populate_liked_ids()
            os.execute("notify-send -t 3000 --app-name=spotirofi 'Spotirofi' 'Library refreshed' &")
        elseif clean == "Restart Daemons" then
            os.execute("pkill -x spotifyd 2>/dev/null"); os.execute("pkill -f 'spotirofi.*--daemon' 2>/dev/null"); os.execute("sleep 1")
            inv_playback()
            os.execute("spotifyd --no-daemon --device-name spotirofi --backend pulseaudio --use-mpris --initial-volume 100 > /dev/null 2>&1 &")
            os.execute("sleep 3")
            os.execute(HOME .. "/.config/rofi/scripts/spotirofi/spotirofi.lua --daemon &")
        elseif clean == "Kill Daemons" then
            os.execute("pkill -x spotifyd 2>/dev/null")
            os.execute("pkill -f 'spotirofi.*--daemon' 2>/dev/null")
            os.execute("pkill -x rofi 2>/dev/null")
            os.exit(0)
        end
    end
end

--===================================================================
-- SESSION REPLAY
--===================================================================

local function replay_session()
    local function pop_file()
        local raw = read_file(SESSION_FILE)
        if not raw then return end
        local ok, d = pcall(json.decode, raw)
        if not ok or type(d) ~= "table" then return end
        local s = d.stack
        if type(s) ~= "table" or #s == 0 then return end
        table.remove(s)
        if #s == 0 then os.remove(SESSION_FILE)
        else write_file(SESSION_FILE, json.encode({stack=s})) end
    end

    local s = session_peek()
    if not s then return end

    while s do
        pop_file()
        get_playback()
        local v = s.view

        if v == "action" and s.track_id then
            if current_track and s.track_id == current_track.id then
                view_actions(current_track, "track")
            else
                view_actions({id=s.track_id, name=s.track_name or "", artists=s.track_artists or {},
                    album=s.track_album or {}, duration_ms=s.track_duration_ms or 0, duration={secs=0,nanos=0}}, "track")
            end
        elseif v == "lyrics" and s.track_id then
            view_lyrics({id=s.track_id, name=s.track_name or "", artists=s.track_artists or {}})
        elseif v == "album" and s.album_id then
            local ad = api_get_album(s.album_id)
            if ad and ad.tracks and #ad.tracks > 0 then
                local te = {}
                for i, t in ipairs(ad.tracks) do te[i] = string.format("%2d. %s", i, display_track(t, true)) end
                view_browse(te, ad.tracks, "", "album", "album", s.album_id)
            end
        elseif v == "playlist" and s.playlist_id then
            local tracks = api_get_playlist_tracks(s.playlist_id)
            if tracks and #tracks > 0 then
                local te = {}
                for i, t in ipairs(tracks) do te[i] = string.format("%2d. %s", i, display_track(t)) end
                view_browse(te, tracks, "", "playlist", "playlist", s.playlist_id)
            end
        elseif v == "liked"              then view_liked_tracks()
        elseif v == "top-tracks"         then view_top_tracks()
        elseif v == "discover-weekly"    then view_weekly()
        elseif v == "release-radar"      then view_release_radar()
        elseif v == "new-music-friday"   then view_new_music_friday()
        elseif v == "your-queue"         then view_your_queue()

        elseif v == "new-releases"      then view_new_releases()
        elseif v == "made-for-you"      then view_made_for_you()
        elseif v == "artist-actions" and s.artist_id then
            view_artist({id=s.artist_id, name=s.artist_name or ""})
        elseif v == "artist-albums" and s.artist_id then
            local d = api_get_artist_albums(s.artist_id)
            if d and d.items then
                local ae = {}
                for i, a in ipairs(d.items) do ae[i] = display_album(a) end
                while true do
                    local aidx = rofi_dmenu(ae, {prompt=s.artist_name or "", mesg=(s.artist_name or "") .. " - " .. #d.items .. " albums", custom=false, by_index=true, use_menu=true})
                    if not aidx then break end
                    if aidx >= 1 and aidx <= #d.items then
                        local ad = api_get_album(d.items[aidx].id)
                        if ad and ad.tracks and #ad.tracks > 0 then
                            local te = {}
                            for i, t in ipairs(ad.tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t, true)) end
                            view_browse(te, ad.tracks, d.items[aidx].name .. " - " .. artist_names(d.items[aidx]), "album", "album", d.items[aidx].id)
                        end
                    end
                end
            end
        elseif v == "liked-by-artist" and s.artist_id then
            local all_tracks = load_liked_tracks()
            local tracks = {}
            for _, t in ipairs(all_tracks) do
                for _, a in ipairs(t.artists or {}) do
                    if a.id == s.artist_id or (a.name or ""):lower() == (s.artist_name or ""):lower() then
                        tracks[#tracks+1] = t; break
                    end
                end
            end
            if #tracks > 0 then
                table.sort(tracks, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
                local te = {}
                for i, t in ipairs(tracks) do te[i] = string.format("%2d. %s", i, display_track(t, true)) end
                view_browse(te, tracks, (s.artist_name or "") .. " - " .. #tracks .. " liked tracks", "liked-by-artist", nil, nil)
            end
        elseif v == "top-by-artist" and s.artist_id then
            local d = api_get_artist_top_tracks(s.artist_id)
            if d and d.tracks and #d.tracks > 0 then
                local te = {}
                for i, t in ipairs(d.tracks) do te[i] = string.format("%2d. %s", i, display_track(t, true)) end
                view_browse(te, d.tracks, (s.artist_name or "") .. " - " .. #d.tracks .. " top tracks", "top-by-artist", nil, nil)
            end
        elseif v == "related" and s.artist_id then
            local d = api_get_artist_related(s.artist_id)
            if d and d.artists and #d.artists > 0 then
                local ae = {}
                for i, a in ipairs(d.artists) do ae[i] = display_artist(a) end
                while true do
                    local ridx = rofi_dmenu(ae, {prompt="Related to " .. (s.artist_name or ""), mesg=(s.artist_name or "") .. " - " .. #d.artists .. " related", custom=false, by_index=true, use_menu=true})
                    if not ridx then break end
                    if ridx >= 1 and ridx <= #d.artists then view_artist(d.artists[ridx]) end
                end
            end
        elseif v == "categories"          then view_categories()
        elseif v == "playlists"           then view_playlists()
        elseif v == "saved-albums"        then view_saved_albums()
        elseif v == "followed-artists"    then view_followed_artists()
        elseif v == "search"              then view_search(s.query or "all")
        elseif v == "search-results" and s.query then
            local stype = (s.category or "all") == "all" and "track,album,artist,playlist" or (s.category or "track")
            local results = api_search(s.query, stype)
            if results then
                local cat = s.category or "all"
                if cat == "all" then
                    local items = {}
                    for _, rk in ipairs({"tracks","albums","artists","playlists"}) do
                        local ci = results[rk]
                        if ci and type(ci) == "table" then
                            for i = 1, math.min(#ci, 5) do ci[i]._stype = rk; items[#items+1] = ci[i] end
                        end
                    end
                    if #items > 0 then
                        local n = math.min(#items, MAX_RESULTS); local entries = {}
                        for i = 1, n do
                            local pfx, st = "", items[i]._stype
                            if st == "tracks" then pfx = "\u{F0387} " elseif st == "albums" then pfx = "\u{F0025} " elseif st == "artists" then pfx = "\u{F415} " elseif st == "playlists" then pfx = "\u{F0411} " end
                            entries[#entries+1] = string.format("%2d. %s", i, pfx .. (items[i].name or "Unknown"))
                        end
                        view_browse(entries, items, n .. " results for " .. s.query, "all", nil, nil)
                    end
                else
                    local key = cat .. "s"; local items = results[key]
                    if items and type(items) == "table" and #items > 0 then
                        local n = math.min(#items, MAX_RESULTS); local entries = {}
                        for i = 1, n do entries[#entries+1] = string.format("%2d. %s", i, (items[i].name or "Unknown")) end
                        local sctx2 = (cat == "album" or cat == "playlist") and "search-" .. cat or cat
                        view_browse(entries, items, n .. " " .. key .. " for " .. s.query, sctx2, (cat == "album" and "album" or cat == "playlist" and "playlist" or nil), nil)
                    end
                end
            end
        elseif v == "category-playlists" and s.category_id then
            local pls = api_get_category_playlists(s.category_id)
            if pls then
                local pe = {}
                for _, pl in ipairs(pls) do pe[#pe+1] = display_playlist(pl) end
                view_browse(pe, pls, (s.category_name or "") .. " - " .. #pls .. " playlists", "playlist", "playlist", nil)
            end
        elseif v == "playlist-actions" and s.playlist_id then
            local token = get_token()
            if not token then s = session_peek(); goto rnext end
            local pl = {id=s.playlist_id, name=s.playlist_name or "Playlist"}
            local acts = {"Open Playlist", "Rename Playlist", "Delete Playlist"}
            ::rp_act::
            local asel = rofi_dmenu(acts, {prompt=pl.name, mesg=display_playlist(pl), sel=0, custom=false, use_menu=true})
            if not asel or asel == "" then break end
            if asel == "Open Playlist" then
                local tracks = api_get_playlist_tracks(pl.id)
                if tracks then
                    local te = {}
                    for i, t in ipairs(tracks) do te[#te+1] = string.format("%2d. %s", i, display_track(t)) end
                    view_browse(te, tracks, pl.name .. " - " .. #tracks .. " tracks", "playlist", "playlist", pl.id)
                end
                goto rp_act
            elseif asel == "Rename Playlist" then
                local nn = rofi_input("New Name", pl.name or "")
                if nn == "" or nn == (pl.name or "") then goto rp_act end
                local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/playlists/%s' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s -o /dev/null", pl.id, token, shell_quote(json.encode({name=nn}))))
                if r and r:match("2..") then pl.name = nn; disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists"); rofi_message("Renamed") else rofi_message("Failed") end
                goto rp_act
            elseif asel == "Delete Playlist" then
                local c = rofi_dmenu({"Yes, delete","Cancel"}, {prompt="Delete", mesg="Delete '" .. (pl.name or "") .. "'?", custom=false, by_index=true, use_menu=true})
                if c == 1 then
                    local r = shell(string.format("curl -s --max-time 5 -w '%%{http_code}' -X DELETE 'https://api.spotify.com/v1/playlists/%s/followers' -H 'Authorization: Bearer %s' -o /dev/null", pl.id, token))
                    if r and r:match("2..") then disk_bust(CACHE .. "/my_playlists.json"); mem_bust("my_playlists"); disk_bust(CACHE .. "/playlist_tracks_" .. pl.id .. ".json"); mem_bust("playlist_tracks_" .. pl.id); rofi_message("Deleted"); break
                    else rofi_message("Failed to delete") end
                end
                goto rp_act
            end
        elseif v == "add-to-playlist" and s.track_id then
            view_add_pl(s.track_id)
        end

        inv_playback()
        ::rnext::
        s = session_peek()
    end
end

--===================================================================
-- MAIN
--===================================================================

local function main()
    local lock = "/tmp/spotirofi_instance.pid"
    local prev = read_file(lock)
    local prev_pid = prev and tonumber(prev:match("(%d+)"))
    if prev_pid and prev_pid > 0 then os.execute("kill " .. prev_pid .. " 2>/dev/null; sleep 0.05") end
    os.execute("echo $PPID > " .. shell_quote(lock))

    -- start background daemon if not already running
    local daemon_pid = trim(read_file("/tmp/spotirofi_daemon.pid") or "")
    local daemon_alive = false
    if daemon_pid ~= "" then
        daemon_alive = shell("kill -0 " .. daemon_pid .. " 2>/dev/null && echo alive") == "alive"
    end
    if not daemon_alive then
        os.execute(HOME .. "/.config/rofi/scripts/spotirofi/spotirofi.lua --daemon &")
    end

    local rate_cool = read_file("/tmp/spotirofi_rate_cooldown")
    if rate_cool then
        local until_t = tonumber(trim(rate_cool))
        if until_t and os.time() < until_t then
            local secs = until_t - os.time()
            rofi_message("Spotify API rate limit active.\nRetry after " .. secs .. "s.")
            os.exit(0)
        end
        os.remove("/tmp/spotirofi_rate_cooldown")
    end

    ensure_spotifyd_auth()
    ensure_auth()
    ensure_spotifyd()
    load_queue()
    populate_liked_ids()
    if not (read_file(LIKED_CACHE) and read_file(ALBUM_CACHE) and read_file(ARTIST_CACHE)) then
        os.execute("notify-send -t 10000 --app-name=spotirofi 'Spotirofi' 'First run: building library...' &")
        load_liked_tracks()
        load_saved_albums()
        load_followed_artists()
        populate_liked_ids()
        os.execute("notify-send -t 3000 --app-name=spotirofi 'Spotirofi' 'Library ready' &")
    end
    replay_session()
    last_playback = 0

    while true do
        get_playback()
        local has_track = current_track ~= nil
        local mesg = has_track and track_mesg(current_track) or nil

        local entries = {}
        local function add(v) if v then entries[#entries+1] = v end end
        add("Track Options")
        add("Your Queue"); add("Liked Tracks"); add("Top Tracks"); add("Saved Albums")
        add("Followed Artists"); add("Playlists"); add("New Releases")
        add("Made For You"); add("Categories"); add("Search")
        add(current_track and (is_playing and "Pause" or "Resume") or "No track playing")
        add("Next Track"); add("Previous Track")
        add(is_shuffle and "Shuffle: On" or "Shuffle: Off")
        add(repeat_state=="off" and "Repeat: Off" or (repeat_state=="track" and "Repeat: Track" or "Repeat: Context"))
        add("Volume")
        add("System")

        local sel = rofi_dmenu(entries, {prompt="Spotify", mesg=mesg, sel=0, custom=false, markup=true})
        if sel then sel = sel:gsub("<[^>]+>", "") end

        if main_pending   then main_pending   = false; goto m1 end
        if search_pending then search_pending = false; session_push({view="search", query="all"}); view_search("all"); goto m1 end
        if not sel or sel == "" then goto m1 end

        if      sel == "Search" then
            local tp = {"All","Tracks","Albums","Artists","Playlists"}
            local p  = {"all","track","album","artist","playlist"}
            local si = rofi_dmenu(tp, {prompt="Search", mesg=mesg, custom=false, by_index=true, use_menu=true, theme=THEME_SUB})
            if si and si >= 1 and si <= #tp then
                local cat = p[si]:lower()
                session_push({view="search", query=cat})
                view_search(cat)
            end
        elseif  sel == "Track Options" then if current_track then view_actions(current_track, "track") end
        elseif  sel == "Liked Tracks"     then view_liked_tracks()
        elseif  sel == "Saved Albums"     then view_saved_albums()
        elseif  sel == "Followed Artists" then view_followed_artists()
        elseif  sel == "Playlists"        then view_playlists()
        elseif  sel == "Categories"       then view_categories()
        elseif  sel == "Your Queue"       then view_your_queue()
        elseif  sel == "Top Tracks"       then view_top_tracks()
        elseif  sel == "New Releases"     then view_new_releases()
        elseif  sel == "Made For You"     then view_made_for_you()
        elseif  sel == "Pause" then
            local r = os.execute("playerctl pause 2>/dev/null")
            if r then is_playing = false else rofi_message("Failed to pause") end
        elseif  sel == "Resume" then
            local r = os.execute("playerctl play 2>/dev/null")
            if r then is_playing = true else rofi_message("Failed to resume") end
        elseif  sel == "No track playing" then -- nothing
        elseif  sel == "Next Track" then
            local r = do_playback_cmd("next")
            if r and r:match("2..") then inv_playback() else rofi_message("Failed to skip") end
        elseif  sel == "Previous Track" then
            local r = do_playback_cmd("previous")
            if r and r:match("2..") then inv_playback() else rofi_message("Failed to go back") end
        elseif  sel:find("^Shuffle") then
            local token = get_token()
            if token then
                local r = shell("curl -s --max-time 3 -o /dev/null -w '%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/shuffle?state=" .. (is_shuffle and "false" or "true") .. "' -H 'Authorization: Bearer " .. token .. "' -H 'Content-Length: 0'")
                if r and r:match("2..") then inv_playback() else rofi_message("Failed to toggle shuffle") end
            end
        elseif  sel:find("^Repeat") then
            local token = get_token()
            local new_state = repeat_state == "off" and "context" or (repeat_state == "context" and "track" or "off")
            if token then
                local r = shell("curl -s --max-time 3 -o /dev/null -w '%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/repeat?state=" .. new_state .. "' -H 'Authorization: Bearer " .. token .. "' -H 'Content-Length: 0'")
                if r and r:match("2..") then inv_playback() else rofi_message("Failed to toggle repeat") end
            end
        elseif  sel == "System"        then view_system()
        elseif  sel == "Volume" then
            local supports_vol = mem_get("spotifyd_device_vol")
            if supports_vol == false then
                rofi_message("Device doesn't support volume control")
            else
                local vm = current_track and track_mesg(current_track) or "Volume"
                local vi = rofi_dmenu({"25%","50%","75%","100%"}, {prompt="Volume", mesg=vm, custom=false, by_index=true, use_menu=true, theme=THEME_SUB})
                if vi and vi >= 1 and vi <= 4 then
                    local token = get_token()
                    if token then
                        local r = shell("curl -s --max-time 3 -o /dev/null -w '%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/volume?volume_percent=" .. (vi*25) .. "' -H 'Authorization: Bearer " .. token .. "' -H 'Content-Length: 0'")
                        if not r or not r:match("2..") then rofi_message("Failed to set volume") end
                    end
                end
            end
        end
        ::m1::
    end
end

--===================================================================
-- DAEMON MODE — MPRIS listener for zero-API-call notifications
--===================================================================

local function daemon_mode()
    local lock = "/tmp/spotirofi_daemon.pid"
    local prev = read_file(lock)
    local prev_pid = prev and tonumber(prev:match("(%d+)"))
    if prev_pid and prev_pid > 0 then
        os.execute("kill " .. prev_pid .. " 2>/dev/null; sleep 0.1")
    end
    local f = io.open("/proc/self/stat")
    local mypid = f and tonumber(f:read("*a"):match("^(%d+)"))
    if f then f:close() end
    if mypid then write_file(lock, tostring(mypid)) end

    local NOTIFY_FILE = "/tmp/spotirofi_last_notify"
    local last_title = nil

    local function daemon_notify(title, artist, art_url, track_id)
        if not title then return end
        if track_id and #track_id > 0 then
            local prev_id = read_file(NOTIFY_FILE)
            if prev_id and trim(prev_id) == track_id then return end
            write_file(NOTIFY_FILE, track_id)
        end
        local art_path = ""
        if art_url and #art_url > 0 then
            local hash = art_url:match("/image/([%w]+)") or art_url:match("/([%w_%-]+)$")
            if hash then
                art_path = ART_DIR .. "/" .. hash .. ".jpg"
                os.execute("mkdir -p " .. shell_quote(ART_DIR))
                local fh = io.open(art_path, "r")
                if not fh then
                    os.execute("curl -s --max-time 3 -o " .. shell_quote(art_path) .. " " .. shell_quote(art_url))
                else
                    fh:close()
                end
            end
        end
        local icon = #art_path > 0 and ("--icon=" .. shell_quote(art_path)) or ""
        os.execute("notify-send --app-name=spotirofi " .. icon
            .. " " .. shell_quote(title)
            .. " " .. shell_quote(artist or "") .. " &")
    end

    local function process_snap(snap)
        if not snap then return end
        snap = trim(snap)
        local title, artist, art_url, track_id, album, duration_raw = snap:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if track_id then track_id = track_id:gsub("^'", ""):gsub("'$", ""):match("^/spotify/track/(.+)") or track_id:match("^spotify:track:(.+)") or track_id end
        local duration = tonumber(duration_raw) and tonumber(duration_raw) / 1000000 or nil
        if title and title ~= "" and title ~= last_title then
            daemon_notify(title, artist, art_url, track_id)
            last_title = title
            if track_id and title and title ~= "" then
                os.execute("nohup lua " .. shell_quote(DIR .. "/spotirofi.lua")
                    .. " --prefetch-lyrics " .. shell_quote(track_id)
                    .. " " .. shell_quote(title)
                    .. " " .. shell_quote(artist or "")
                    .. " " .. shell_quote(album or "")
                    .. " " .. shell_quote(duration and tostring(math.floor(duration)) or "")
                    .. " > /dev/null 2>&1 &")
            end
        end
    end

    local function daemon_loop()
        process_snap(shell("playerctl metadata -f '{{title}}|{{artist}}|{{mpris:artUrl}}|{{mpris:trackid}}|{{album}}|{{mpris:length}}' 2>/dev/null"))
        local p = io.popen("playerctl --follow metadata 2>/dev/null", "r")
        if not p then return nil end
        for _ in p:lines() do
            process_snap(shell("playerctl metadata -f '{{title}}|{{artist}}|{{mpris:artUrl}}|{{mpris:trackid}}|{{album}}|{{mpris:length}}' 2>/dev/null"))
        end
        p:close()
        return nil
    end

    while true do
        daemon_loop()
        os.execute("sleep 2")
    end
end

if arg and arg[1] == "--daemon" then
    daemon_mode()
elseif arg and arg[1] == "--prefetch-lyrics" and arg[2] and arg[3] and arg[4] then
    ensure_cache()
    local id = arg[2]
    local key = "lyrics_" .. id
    if mem_get(key) then os.exit(0) end
    local disk = LYRICS_DIR .. "/lyrics_" .. id .. ".json"
    local existing = disk_get(disk)
    if existing then mem_set(key, existing); os.exit(0) end
    local album = arg[5] ~= "" and arg[5] or nil
    local duration = arg[6] and tonumber(arg[6]) or nil
    local lines = api_get_lyrics(arg[3], arg[4], album, duration)
    if lines and #lines > 0 then
        mem_set(key, lines)
        disk_set(disk, lines)
    end
    os.exit(0)
else
    main()
end
