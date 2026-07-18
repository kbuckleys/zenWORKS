#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┘
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local HOME = os.getenv("HOME")
local DIR = HOME .. "/.config/rofi/scripts/spotify"
local THEME = DIR .. "/spotify.rasi"
local THEME_MENU = DIR .. "/spotify-menus.rasi"
local THEME_LYRICS = DIR .. "/lyrics.rasi"
local THEME_MESSAGE = DIR .. "/message.rasi"
local CACHE_FILE = HOME .. "/.cache/spotify_rofi/user_data.json"
local LIKED_ORDER_CACHE = HOME .. "/.cache/spotify_rofi/liked_order.json"
local TOKEN_FILE = HOME .. "/.cache/spotify-player/user_client_token.json"
local CACHE_MAX_AGE = 300
local LIKED_ORDER_MAX_AGE = 86400
local MAX_RESULTS = 20
local ICON_LIKED = "\u{f05d}"
local ICON_EXPLICIT = "󰯹"

local json = require("cjson")

local liked_tracks = {}
local saved_albums = {}
local user_playlists = {}
local followed_artists = {}
local current_track_id = nil
local current_track_item = nil
local current_is_playing = false
local current_shuffle = false
local current_repeat = "off"

local QUEUE_FILE = HOME .. "/.cache/spotify_rofi/playback_queue.json"
local SESSION_FILE = HOME .. "/.cache/spotify_rofi/session.json"
local queue_tracks = nil
local queue_idx = 0

local function shell(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function write_file(path, data)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(data)
    f:close()
    return true
end

local function file_age(path)
    local f = io.open(path, "r")
    if not f then return math.huge end
    f:close()
    local attr = io.popen("stat -c %Y " .. shell_quote(path)):read("*n")
    if not attr then return math.huge end
    return os.time() - attr
end

local function get_spotify_token()
    local raw = read_file(TOKEN_FILE)
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return nil end

    if data.expires_at then
        local exp = data.expires_at
        if type(exp) == "string" then
            local y, m, d, h, min, s = exp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if y then
                local ts = os.time({year=tonumber(y), month=tonumber(m), day=tonumber(d),
                    hour=tonumber(h), min=tonumber(min), sec=tonumber(s)})
                if os.time() > ts + 60 then
                    local refreshed = false
                    if data.refresh_token then
                        local cmd = string.format(
                            "curl -s -X POST https://accounts.spotify.com/api/token -d grant_type=refresh_token --data-urlencode %s -d client_id=%s",
                            shell_quote("refresh_token=" .. data.refresh_token),
                            "d420a117a32841c2b3474932e49fb54b"
                        )
                        local h = io.popen(cmd, "r")
                        if h then
                            local resp = h:read("*a")
                            h:close()
                            local rok, rdata = pcall(json.decode, resp)
                            if rok and rdata and rdata.access_token then
                                data.access_token = rdata.access_token
                                if rdata.refresh_token then
                                    data.refresh_token = rdata.refresh_token
                                end
                                if rdata.expires_in then
                                    data.expires_at = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + tonumber(rdata.expires_in))
                                end
                                write_file(TOKEN_FILE, json.encode(data))
                                refreshed = true
                            end
                        end
                    end
                    if not refreshed then return nil end
                end
            end
        end
    end
    return data.access_token
end

local function fetch_liked_order()
    local cached = read_file(LIKED_ORDER_CACHE)
    if cached and file_age(LIKED_ORDER_CACHE) < LIKED_ORDER_MAX_AGE then
        local ok, data = pcall(json.decode, cached)
        if ok and type(data) == "table" and #data > 0 then return data end
    end

    local token = get_spotify_token()
    if not token then return nil end

    local all = {}
    local offset = 0
    local limit = 50
    while true do
        local cmd = string.format(
            "curl -s -H 'Authorization: Bearer %s' 'https://api.spotify.com/v1/me/tracks?limit=%d&offset=%d&fields=items(track(id,name,duration_ms),added_at)'",
            token, limit, offset
        )
        local handle = io.popen(cmd, "r")
        if not handle then break end
        local raw = handle:read("*a")
        handle:close()
        local ok, data = pcall(json.decode, raw)
        if not ok or type(data) ~= "table" then break end
        local items = data.items
        if not items or #items == 0 then break end
        for _, item in ipairs(items) do
            local track = item.track
            if track and track.id then
                all[#all + 1] = {
                    id = track.id,
                    name = track.name or "",
                    duration_ms = track.duration_ms or 0,
                    added_at = item.added_at or ""
                }
            end
        end
        offset = offset + limit
        if #items < limit then break end
    end

    if #all > 0 then
        write_file(LIKED_ORDER_CACHE, json.encode(all))
        return all
    end
    return nil
end

local function liked_order_add(item)
    -- Update liked_order.json
    local raw = read_file(LIKED_ORDER_CACHE)
    if raw then
        local ok, order = pcall(json.decode, raw)
        if ok and type(order) == "table" then
            local entry = {
                id = item.id,
                name = item.name or "Unknown",
                duration_ms = item.duration_ms or ((item.duration and item.duration.secs or 0) * 1000),
                added_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            for i = #order, 1, -1 do
                if order[i].id == entry.id then table.remove(order, i); break end
            end
            table.insert(order, 1, entry)
            write_file(LIKED_ORDER_CACHE, json.encode(order))
        end
    end
    -- Update SavedTracks_cache.json
    local cache_file = HOME .. "/.cache/spotify-player/SavedTracks_cache.json"
    local craw = read_file(cache_file)
    if not craw then return end
    local ok, cache = pcall(json.decode, craw)
    if not ok or type(cache) ~= "table" then return end
    local dur = item.duration
    if not dur and item.duration_ms then
        local ms = item.duration_ms
        dur = { secs = math.floor(ms / 1000), nanos = (ms % 1000) * 1000000 }
    end
    local key = "spotify:track:" .. item.id
    cache[key] = {
        id = item.id,
        name = item.name or "Unknown",
        duration = dur or { secs = 0, nanos = 0 },
        artists = item.artists or {},
        album = item.album or {},
    }
    write_file(cache_file, json.encode(cache))
end

local function liked_order_remove(id)
    local raw = read_file(LIKED_ORDER_CACHE)
    if raw then
        local ok, order = pcall(json.decode, raw)
        if ok and type(order) == "table" then
            for i = #order, 1, -1 do
                if order[i].id == id then
                    table.remove(order, i)
                    write_file(LIKED_ORDER_CACHE, json.encode(order))
                    break
                end
            end
        end
    end
    local cache_file = HOME .. "/.cache/spotify-player/SavedTracks_cache.json"
    local craw = read_file(cache_file)
    if not craw then return end
    local ok, cache = pcall(json.decode, craw)
    if not ok or type(cache) ~= "table" then return end
    cache["spotify:track:" .. id] = nil
    write_file(cache_file, json.encode(cache))
end

local function add_to_queue(track_id)
    local token = get_spotify_token()
    if not token then return false end
    local cmd = string.format(
        "curl -s -w '%%{http_code}' -X POST 'https://api.spotify.com/v1/me/player/queue?uri=spotify:track:%s' -H 'Authorization: Bearer %s' -o /dev/null",
        track_id, token
    )
    local result = shell(cmd)
    return result and result:match("2..") ~= nil
end

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function safe_json_decode(s)
    if not s or trim(s) == "" then return nil end
    local ok, data = pcall(json.decode, trim(s))
    if not ok then return nil end
    if data == nil or type(data) ~= "table" then return nil end
    return data
end

local function val(t, key, default)
    if type(t) == "table" then
        local v = t[key]
        if v == nil or type(v) == "userdata" then return default end
        return v
    end
    return default
end

local function ensure_cache_dir()
    os.execute("mkdir -p " .. shell_quote(HOME .. "/.cache/spotify_rofi"))
end

local function load_cached_user_data()
    local raw = read_file(CACHE_FILE)
    if not raw or raw == "" then return false end
    local data = safe_json_decode(raw)
    if not data then return false end
    local age = (os.time() - (data.ts or 0))
    if age > CACHE_MAX_AGE then return false end
    liked_tracks = data.liked_tracks or {}
    saved_albums = data.saved_albums or {}
    user_playlists = data.user_playlists or {}
    followed_artists = data.followed_artists or {}
    return true
end

local function save_cached_user_data()
    ensure_cache_dir()
    local data = {
        ts = os.time(),
        liked_tracks = liked_tracks,
        saved_albums = saved_albums,
        user_playlists = user_playlists,
        followed_artists = followed_artists,
    }
    write_file(CACHE_FILE, json.encode(data))
end

local function load_user_data()
    if load_cached_user_data() then return end

    for attempt = 1, 3 do
        local h_liked = io.popen("timeout 3 spotify_player get key user-liked-tracks 2>/dev/null", "r")
        local h_albums = io.popen("timeout 3 spotify_player get key user-saved-albums 2>/dev/null", "r")
        local h_playlists = io.popen("timeout 3 spotify_player get key user-playlists 2>/dev/null", "r")
        local h_artists = io.popen("timeout 3 spotify_player get key user-followed-artists 2>/dev/null", "r")

        local raw_liked = h_liked and h_liked:read("*a") or ""
        local raw_albums = h_albums and h_albums:read("*a") or ""
        local raw_playlists = h_playlists and h_playlists:read("*a") or ""
        local raw_artists = h_artists and h_artists:read("*a") or ""

        if h_liked then h_liked:close() end
        if h_albums then h_albums:close() end
        if h_playlists then h_playlists:close() end
        if h_artists then h_artists:close() end

        if not next(liked_tracks) and #raw_liked > 100 then
            for id in raw_liked:gmatch('"id":"([A-Za-z0-9]+)"') do
                liked_tracks[id] = true
            end
        end

        if not next(saved_albums) then
            local data = safe_json_decode(raw_albums)
            if data then
                local items = data.items or data
                if type(items) == "table" then
                    for _, item in ipairs(items) do
                        if type(item) == "table" and item.id then
                            saved_albums[item.id] = true
                        end
                    end
                end
            end
        end

        if not next(user_playlists) then
            local data = safe_json_decode(raw_playlists)
            if data then
                local items = data.items or data
                if type(items) == "table" then
                    for _, item in ipairs(items) do
                        if type(item) == "table" and item.id then
                            user_playlists[item.id] = true
                        end
                    end
                end
            end
        end

        if not next(followed_artists) and #raw_artists > 10 then
            local artist_data = safe_json_decode(raw_artists)
            if artist_data then
                for _, item in ipairs(artist_data) do
                    if type(item) == "table" and item.id then
                        followed_artists[item.id] = true
                    end
                end
            end
        end

        if next(liked_tracks) and next(saved_albums) and next(user_playlists) and next(followed_artists) then break end
        os.execute("sleep 0.5")
    end

    save_cached_user_data()
end

local playback_cache = nil
local playback_cache_ts = 0
local PLAYBACK_CACHE_TTL = 5

local function get_playback_status()
    local now = os.time()
    if playback_cache ~= nil and (now - playback_cache_ts) < PLAYBACK_CACHE_TTL then
        if playback_cache == false then return nil end
        return playback_cache
    end
    local out = shell("timeout 0.5 spotify_player get key playback 2>/dev/null")
    local data = safe_json_decode(out)
    if not data then
        current_track_id = nil; current_track_item = nil; current_is_playing = false
        playback_cache = false; playback_cache_ts = now
        return nil
    end
    local track = data.item
    if not track or type(track) ~= "table" then
        current_track_id = nil; current_track_item = nil; current_is_playing = false
        playback_cache = false; playback_cache_ts = now
        return nil
    end
    current_track_id = track.id
    current_track_item = track
    current_is_playing = data.is_playing == true
    current_shuffle = data.shuffle_state == true
    current_repeat = val(data, "repeat_state", "off")
    local artists = {}
    for _, a in ipairs(track.artists or {}) do
        if type(a) == "table" and a.name then
            artists[#artists + 1] = a.name
        end
    end
    local artist = #artists > 0 and table.concat(artists, ", ") or "Unknown"
    local name = track.name or "Unknown"
    local status = string.format("%s \u{f01d9} %s", name, artist)
    playback_cache = status
    playback_cache_ts = now
    return status
end

local function invalidate_playback_cache()
    playback_cache = nil
    playback_cache_ts = 0
end

local function load_queue()
    local raw = read_file(QUEUE_FILE)
    if not raw then return false end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return false end
    if not data.tracks or type(data.tracks) ~= "table" or #data.tracks == 0 then return false end
    if not data.idx or type(data.idx) ~= "number" then return false end
    if data.idx < 1 or data.idx > #data.tracks then return false end
    queue_tracks = data.tracks
    queue_idx = data.idx
    return true
end

local function save_queue(all_items, idx)
    if not all_items then return end
    local tids = {}
    for i, t in ipairs(all_items) do
        if t.id then tids[i] = t.id end
    end
    if #tids == 0 then return end
    queue_tracks = tids
    queue_idx = idx
    local data = { tracks = tids, idx = idx }
    write_file(QUEUE_FILE, json.encode(data))
end

local function flush_queue()
    if not queue_tracks then return end
    local data = { tracks = queue_tracks, idx = queue_idx }
    write_file(QUEUE_FILE, json.encode(data))
end

local function push_session(data)
    local raw = read_file(SESSION_FILE)
    local stack = {}
    if raw then
        local ok, s = pcall(json.decode, raw)
        if ok and type(s) == "table" and type(s.stack) == "table" then stack = s.stack end
    end
    stack[#stack + 1] = data
    write_file(SESSION_FILE, json.encode({ stack = stack }))
end

local function peek_session()
    local raw = read_file(SESSION_FILE)
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return nil end
    local stack = data.stack
    if type(stack) ~= "table" or #stack == 0 then return nil end
    return stack[#stack]
end

local function pop_session()
    local raw = read_file(SESSION_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then return end
    local stack = data.stack
    if type(stack) ~= "table" or #stack == 0 then return end
    table.remove(stack)
    if #stack == 0 then os.remove(SESSION_FILE)
    else write_file(SESSION_FILE, json.encode({ stack = stack })) end
end

local function clear_session()
    os.remove(SESSION_FILE)
end

local function rofi_dmenu(opts)
    local entries = opts.entries or {}
    local prompt = opts.prompt or ""
    local mesg = opts.mesg
    local markup = opts.markup or false
    local eh = opts.eh
    local sel = opts.sel
    local custom = opts.custom ~= false
    local use_menu = opts.use_menu ~= false
    local by_index = opts.by_index or false
    local override_theme = opts.theme

    local theme = override_theme or (use_menu and THEME_MENU or THEME)
    local args = { "rofi", "-dmenu", "-theme", theme, "-p", prompt, "-i", "-kb-custom-1", "Alt+BackSpace" }
    if not custom then args[#args + 1] = "-no-custom" end
    if markup then
        args[#args + 1] = "-markup-rows"
        args[#args + 1] = "-markup"
    end
    if by_index then args[#args + 1] = "-format"; args[#args + 1] = "i" end
    if eh then args[#args + 1] = "-eh"; args[#args + 1] = tostring(eh) end
    if sel then args[#args + 1] = "-selected-row"; args[#args + 1] = tostring(sel) end

    local entries_file = os.tmpname()
    local f = io.open(entries_file, "w")
    if not f then return nil end
    for _, e in ipairs(entries) do
        f:write(e .. "\n")
    end
    f:close()

    if mesg then
        args[#args + 1] = "-mesg"
        args[#args + 1] = mesg
    end

    local quoted_args = {}
    for _, a in ipairs(args) do
        quoted_args[#quoted_args + 1] = shell_quote(a)
    end
    local cmd = table.concat(quoted_args, " ") .. " < " .. shell_quote(entries_file) .. " 2>/dev/null; printf '\\n__EXIT__%d__' $?"
    local raw = shell(cmd)
    os.remove(entries_file)

    local exit_code = tonumber((raw or ""):match("__EXIT__(%d+)__")) or 0
    local result = (raw or ""):match("^(.-)\n__EXIT__%d+__") or ""

    if exit_code == 10 then pop_session(); return nil end
    if exit_code ~= 0 then os.exit(0) end

    result = trim(result)
    if by_index then
        if result == "" then return nil end
        local n = tonumber(result)
        if not n or n < 0 then return nil end
        return n + 1
    end
    return result
end


local function rofi_message(msg)
    os.execute("rofi -e " .. shell_quote(msg) .. " -theme " .. shell_quote(THEME_MESSAGE) .. " -markup 2>/dev/null")
end

local function artist_names(item)
    local artists = {}
    for _, a in ipairs(item.artists or {}) do
        if type(a) == "table" then artists[#artists + 1] = a.name or "Unknown" end
    end
    return table.concat(artists, ", ")
end

local function display_track(item, hide_artist)
    local artists = hide_artist and "" or artist_names(item)
    local playing = item.id == current_track_id and (current_is_playing and "\u{f04b} " or "\u{f04c} ") or ""
    local liked = liked_tracks[item.id] and (ICON_LIKED .. " ") or ""
    local explicit = val(item, "explicit", false) and (ICON_EXPLICIT .. " ") or ""
    local icons = playing .. explicit .. liked
    if #icons > 0 then icons = icons .. " " end
    local text
    if hide_artist then
        text = string.format("%s%s", icons, item.name or "Unknown")
    else
        text = string.format("%s%s  %s", icons, item.name or "Unknown", artists)
    end
    if item.id == current_track_id then
        text = "<span foreground=\"#b6e0a4\">" .. text .. "</span>"
    end
    return text
end

local function display_album(item)
    local typ = val(item, "typ", "")
    local suffix = ""
    if typ ~= "" then suffix = "  " .. typ end
    local liked = saved_albums[item.id] and (ICON_LIKED .. " ") or ""
    if #liked > 0 then liked = liked .. " " end
    return string.format("%s%s%s", liked, item.name or "Unknown", suffix)
end

local function display_artist(item)
    local followers = val(item, "followers", {})
    local total = val(followers, "total", 0) or 0
    local sub = ""
    if total >= 1000000 then
        sub = string.format(" (%.1fM followers)", total / 1000000)
    elseif total >= 1000 then
        sub = string.format(" (%.0fK followers)", total / 1000)
    elseif total > 0 then
        sub = string.format(" (%d followers)", total)
    end
    local liked = followed_artists[item.id] and (ICON_LIKED .. " ") or ""
    if #liked > 0 then liked = liked .. " " end
    return string.format("%s%s%s", liked, item.name or "Unknown", sub)
end

local function display_playlist(item)
    local owner = val(item, "owner", {})
    local owner_name
    if type(owner) == "table" then
        owner_name = val(owner, "display_name", "Unknown")
    else
        owner_name = tostring(owner)
    end
    local liked = user_playlists[item.id] and (ICON_LIKED .. " ") or ""
    return string.format("%s%s  by %s", liked, item.name or "Unknown", owner_name)
end

local function build_track_mesg(item)
    local play_icon = item.id == current_track_id and (current_is_playing and "\u{f04b}" or "\u{f04c}") or ""
    local liked = liked_tracks[item.id] and (ICON_LIKED .. "  ") or ""
    local explicit = val(item, "explicit", false) and (ICON_EXPLICIT .. "  ") or ""
    return play_icon .. (play_icon ~= "" and "  " or "") .. item.name .. "  " .. artist_names(item) .. "  " .. liked .. explicit
end

local function get_playback_message()
    if not current_track_item then return nil end
    return build_track_mesg(current_track_item)
end

local function do_action(action, item, category, context, context_type, context_id, all_items, current_idx)
    local id = item.id
    if not id then return end
    if action == "Play" then
        if all_items and current_idx then
            save_queue(all_items, current_idx)
        end
        local context_uri
        if context_type and context_id then
            context_uri = "spotify:" .. context_type .. ":" .. context_id
        elseif context == "discover-weekly" then
            context_uri = "spotify:playlist:37i9dQZEVXcQHbTJZxVQMH"
        end
        local token = get_spotify_token()
        if context_uri and token then
            local offset = current_idx and (current_idx - 1) or 0
            local body = json.encode({
                context_uri = context_uri,
                offset = { position = offset }
            })
            local result = shell(string.format(
                "curl -s --max-time 3 -o /dev/null -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/play' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s",
                token, shell_quote(body)
            ))
            if not (result and result:match("^2")) then
                os.execute("spotify_player playback start track --id " .. shell_quote(id))
            end
        elseif all_items and current_idx and token then
            local uris = {}
            local max_idx = math.min(#all_items, current_idx + 49)
            for i = current_idx, max_idx do
                local t = all_items[i]
                if t and t.id then
                    uris[#uris + 1] = "spotify:track:" .. t.id
                end
            end
            if #uris > 0 then
                local body = json.encode({ uris = uris, offset = { position = 0 } })
                local result = shell(string.format(
                    "curl -s --max-time 3 -o /dev/null -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/play' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s",
                    token, shell_quote(body)
                ))
                if not (result and result:match("^2")) then
                    os.execute("spotify_player playback start track --id " .. shell_quote(id))
                end
            else
                os.execute("spotify_player playback start track --id " .. shell_quote(id))
            end
        else
            os.execute("spotify_player playback start track --id " .. shell_quote(id))
        end
    elseif action == "Like" then
        local token = get_spotify_token()
        if token then
            os.execute(string.format("curl -s -o /dev/null -X PUT 'https://api.spotify.com/v1/me/tracks?ids=%s' -H 'Authorization: Bearer %s' &", id, token))
        end
        liked_tracks[id] = true
        liked_order_add(item)
        save_cached_user_data()
    elseif action == "Unlike" then
        local token = get_spotify_token()
        if token then
            os.execute(string.format("curl -s -o /dev/null -X DELETE 'https://api.spotify.com/v1/me/tracks?ids=%s' -H 'Authorization: Bearer %s' &", id, token))
        end
        liked_tracks[id] = nil
        liked_order_remove(id)
        save_cached_user_data()
    elseif action == "Open in Spotify" then
        os.execute("xdg-open " .. shell_quote("spotify:" .. category .. ":" .. id) .. " &")
    end
end

local show_actions
local browse_loop

local function liked_tracks_by_artist_flow(artist)
    push_session({ view = "liked_by_artist", artist_id = artist.id, artist_name = artist.name })
    local raw = read_file(HOME .. "/.cache/spotify-player/SavedTracks_cache.json")
    local data = safe_json_decode(raw)
    if not data then rofi_message("No saved tracks cache") return end
    local tracks = {}
    for _, v in pairs(data) do
        if type(v) == "table" and v.id then
            local song_artists = v.artists or {}
            for _, a in ipairs(song_artists) do
                if a.id == artist.id or (a.name or ""):lower() == (artist.name or ""):lower() then
                    tracks[#tracks + 1] = v
                    break
                end
            end
        end
    end
    if #tracks == 0 then rofi_message("No liked tracks by this artist") return end
    table.sort(tracks, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    local entries = {}
    for i, t in ipairs(tracks) do
        entries[i] = string.format("%2d. %s", i, display_track(t))
    end
    browse_loop(entries, tracks, string.format('%s - %d liked track%s', artist.name, #tracks, #tracks ~= 1 and "s" or ""), "track", "liked-by-artist")
end

local function artist_top_tracks_flow(artist)
    push_session({ view = "top_tracks_by_artist", artist_id = artist.id, artist_name = artist.name })
    local token = get_spotify_token()
    if not token then rofi_message("No Spotify token") return end
    local raw = shell(string.format(
        "curl -s -H 'Authorization: Bearer %s' 'https://api.spotify.com/v1/artists/%s/top-tracks?market=US'",
        token, artist.id
    ))
    local data = safe_json_decode(raw)
    if not data or not data.tracks or #data.tracks == 0 then
        rofi_message("No top tracks found")
        return
    end
    local tracks = data.tracks
    local entries = {}
    for i, t in ipairs(tracks) do
        entries[i] = string.format("%2d. %s", i, display_track(t))
    end
    browse_loop(entries, tracks, string.format('%s - Top Tracks - %d track%s', artist.name, #tracks, #tracks ~= 1 and "s" or ""), "track", "top-tracks-by-artist")
end

local function artist_browse_flow(artist)
    push_session({ view = "artist_albums", artist_id = artist.id, artist_name = artist.name })
    local token = get_spotify_token()
    local data
    if token then
        local raw = shell(string.format(
            "curl -s --max-time 3 -H 'Authorization: Bearer %s' 'https://api.spotify.com/v1/artists/%s/albums?limit=50&include_groups=album,single,compilation'",
            token, artist.id
        ))
        local api_data = safe_json_decode(raw)
        if api_data and api_data.items then
            data = { albums = api_data.items }
        end
    end
    if not data or not data.albums or #data.albums == 0 then
        rofi_message("No albums found")
        return nil
    end
    local albums = data.albums
    local album_entries = {}
    for i, a in ipairs(albums) do
        album_entries[#album_entries + 1] = display_album(a)
    end
    while true do
        local aidx = rofi_dmenu({
            entries = album_entries,
            prompt = artist.name,
            mesg = string.format('%s - %d album%s', artist.name, #albums, #albums ~= 1 and "s" or ""),
            custom = false,
            by_index = true,
        })
        if not aidx then return nil end
        if aidx < 1 or aidx > #albums then goto continue end
        local album = albums[aidx]
        local adata = safe_json_decode(shell("timeout 2 spotify_player get item album --id " .. shell_quote(album.id) .. " 2>/dev/null"))
        if not adata or not adata.tracks or #adata.tracks == 0 then
            rofi_message("No tracks found")
            goto continue
        end
        local tracks = adata.tracks
        local track_entries = {}
        for i, t in ipairs(tracks) do
            track_entries[#track_entries + 1] = string.format("%2d. %s", i, display_track(t, true))
        end
        browse_loop(track_entries, tracks, string.format('%s - %s', album.name, artist_names(album)), "track", "album", "album", album.id)
        ::continue::
    end
end

local function show_artist_actions(artist)
    push_session({ view = "artist_actions", artist_id = artist.id, artist_name = artist.name })
    local is_followed = followed_artists[artist.id]
    local actions = {
        "View All Albums",
        "View Liked Tracks",
        "View Top Tracks",
        is_followed and "Unfollow Artist" or "Follow Artist",
    }
    while true do
        local sel = rofi_dmenu({
            entries = actions,
            prompt = artist.name,
            mesg = string.format('%s - Artist Options', artist.name),
            sel = 0,
            custom = false,
        })
        if not sel or sel == "" then return false end
        if sel == "View All Albums" then
            artist_browse_flow(artist)
        elseif sel == "View Liked Tracks" then
            liked_tracks_by_artist_flow(artist)
        elseif sel == "View Top Tracks" then
            artist_top_tracks_flow(artist)
        elseif sel == "Follow Artist" or sel == "Unfollow Artist" then
            local token = get_spotify_token()
            if token then
                if is_followed then
                    os.execute(string.format(
                        "curl -s -o /dev/null -X DELETE 'https://api.spotify.com/v1/me/following?type=artist&ids=%s' -H 'Authorization: Bearer %s' &",
                        artist.id, token
                    ))
                    followed_artists[artist.id] = nil
                else
                    os.execute(string.format(
                        "curl -s -o /dev/null -X PUT 'https://api.spotify.com/v1/me/following?type=artist&ids=%s' -H 'Authorization: Bearer %s' &",
                        artist.id, token
                    ))
                    followed_artists[artist.id] = true
                end
                save_cached_user_data()
                is_followed = not is_followed
                actions[4] = is_followed and "Unfollow Artist" or "Follow Artist"
            end
        end
    end
end

local function show_lyrics(item)
    push_session({ view = "lyrics", track_id = item.id })
    local out = shell("timeout 2 spotify_player lyrics --id " .. shell_quote(item.id) .. " 2>/dev/null")
    out = out and trim(out) or ""
    if out == "" then
        rofi_message("No lyrics found")
        return
    end
    local lines = {}
    local skip_first = true
    for raw_line in out:gmatch("[^\n]+") do
        if skip_first then
            skip_first = false
        else
            local line = raw_line
            if #line > 80 then
                while #line > 80 do
                    local bp = line:sub(1, 80):match(".*()%s")
                    if bp and bp >= 20 then
                        lines[#lines + 1] = line:sub(1, bp - 1)
                        line = line:sub(bp + 1):match("^%s*(.*)") or line:sub(bp + 1)
                    else
                        lines[#lines + 1] = line:sub(1, 80)
                        line = line:sub(81)
                    end
                end
                if #line > 0 then lines[#lines + 1] = line end
            else
                lines[#lines + 1] = line
            end
        end
    end
    rofi_dmenu({
        entries = lines,
        prompt = "Lyrics",
        mesg = build_track_mesg(item),
        custom = false,
        use_menu = true,
        theme = THEME_LYRICS,
    })
end

show_actions = function(item, category, context, context_type, context_id, all_items, current_idx)
    push_session({ view = "action", track_id = item.id })

    local is_liked = liked_tracks[item.id]

    local actions = {
        "Play / Pause",
        "Add to Queue",
        is_liked and "Unlike" or "Like",
        "Go to Album",
        "Go to Artist",
        "Lyrics",
        "Open in Spotify",
    }

    local mesg = build_track_mesg(item)

    while true do
        local sel = rofi_dmenu({
            entries = actions,
            prompt = "Action",
            mesg = mesg,
            sel = 0,
            custom = false,
        })
        if not sel or sel == "" then return false end
        if sel == "Play / Pause" then
            if item.id == current_track_id then
                os.execute("spotify_player playback play-pause")
            else
                do_action("Play", item, category, context, context_type, context_id, all_items, current_idx)
            end
        elseif sel == "Add to Queue" then
            add_to_queue(item.id)
        elseif sel == "Like" or sel == "Unlike" then
            do_action(sel, item, category, context, context_type, context_id)
            is_liked = not is_liked
            actions[3] = is_liked and "Unlike" or "Like"
            mesg = build_track_mesg(item)
        elseif sel == "Go to Album" then
            local album = item.album
            if album and album.id then
                local adata = safe_json_decode(shell("timeout 2 spotify_player get item album --id " .. shell_quote(album.id) .. " 2>/dev/null"))
                if adata and adata.tracks and #adata.tracks > 0 then
                    local tracks = adata.tracks
                    local track_entries = {}
                    for i, t in ipairs(tracks) do
                        track_entries[i] = string.format("%2d. %s", i, display_track(t, true))
                    end
                    browse_loop(track_entries, tracks, string.format('%s - %s', album.name or "Album", artist_names(album)), "track", "album", "album", album.id)
                else
                    rofi_message("No tracks found")
                end
            end
        elseif sel == "Go to Artist" then
            local artists = item.artists or {}
            if #artists > 0 then
                local artist
                if #artists == 1 then
                    artist = artists[1]
                else
                    local artist_entries = {}
                    for i, a in ipairs(artists) do
                        artist_entries[i] = a.name or "Unknown"
                    end
                    local artist_idx = rofi_dmenu({
                        entries = artist_entries,
                        prompt = "Select Artist",
                        custom = false,
                        by_index = true,
                    })
                    if artist_idx and artist_idx >= 1 and artist_idx <= #artists then
                        artist = artists[artist_idx]
                    end
                end
                if artist then
                    show_artist_actions(artist)
                end
            end
        elseif sel == "Lyrics" then
            show_lyrics(item)
        elseif sel == "Open in Spotify" then
            os.execute("xdg-open " .. shell_quote("spotify:" .. category .. ":" .. item.id) .. " &")
        end
    end
end

local function save_browse_session(ctx, ctx_type, ctx_id, msg)
    if ctx_type == "album" and ctx_id then
        push_session({ view = "album", album_id = ctx_id, album_name = msg:match("^(.-)%s+%-") or "" })
    elseif ctx_type == "playlist" and ctx_id then
        push_session({ view = "playlist", playlist_id = ctx_id, playlist_name = msg or "" })
    elseif ctx == "liked" then
        push_session({ view = "tracks", context = "liked" })
    elseif ctx == "top-tracks" then
        push_session({ view = "top_tracks" })
    elseif ctx == "discover-weekly" then
        push_session({ view = "discover_weekly" })
    end
end

browse_loop = function(entries, items, mesg, category, context, context_type, context_id)
    if category == "track" then
        save_browse_session(context, context_type, context_id, mesg)
    end
    while true do
        local idx = rofi_dmenu({
            entries = entries,
            prompt = context or "Browse",
            mesg = mesg,
            custom = false,
            by_index = true,
            markup = (category == "track"),
        })
        if not idx then return nil end
        if idx < 1 or idx > #items then goto continue end
        local item = items[idx]

        if category == "artist" then
            show_artist_actions(item)
        elseif category == "album" then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item album --id " .. shell_quote(item.id) .. " 2>/dev/null"))
            if not data or not data.tracks or #data.tracks == 0 then
                rofi_message("No tracks found")
                goto continue
            end
            local tracks = data.tracks
            local track_entries = {}
            for i, t in ipairs(tracks) do
                track_entries[#track_entries + 1] = string.format("%2d. %s", i, display_track(t, true))
            end
            browse_loop(track_entries, tracks, string.format('%s - %s', item.name, artist_names(item)), "track", "album", "album", item.id)
        elseif category == "playlist" then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item playlist --id " .. shell_quote(item.id) .. " 2>/dev/null"))
            if not data or not data.tracks or #data.tracks == 0 then
                rofi_message("No tracks found")
                goto continue
            end
            local tracks = data.tracks
            local track_entries = {}
            for i, t in ipairs(tracks) do
                track_entries[#track_entries + 1] = string.format("%2d. %s", i, display_track(t))
            end
            browse_loop(track_entries, tracks, string.format('%s - %d track%s', item.name, #tracks, #tracks ~= 1 and "s" or ""), "track", "playlist", "playlist", item.id)
        elseif category == "track" then
            show_actions(item, "track", context, context_type, context_id, items, idx)
            entries[idx] = string.format("%2d. %s", idx, display_track(item))
        end

        ::continue::
    end
end

local function search_flow(category)
    while true do
        local key = category .. "s"
        local query = rofi_dmenu({
            entries = {},
            prompt = "Search " .. category:sub(1, 1):upper() .. category:sub(2),
            mesg = "Search " .. key,
            use_menu = true,
        })
        if not query or query == "" then return end

        local raw = shell("spotify_player search " .. shell_quote(query) .. " 2>/dev/null")
        local results = safe_json_decode(raw)
        if not results then
            rofi_message("No results or spotify_player unavailable")
            return
        end

        local items = results[key]
        if not items or type(items) ~= "table" or #items == 0 then
            rofi_message("No " .. key .. " found")
            return
        end

        local n = math.min(#items, MAX_RESULTS)
        local entries = {}
        for i = 1, n do
            local display
            if category == "track" then
                display = string.format("%2d. %s", i, display_track(items[i]))
            elseif category == "album" then
                display = display_album(items[i])
            elseif category == "artist" then
                display = display_artist(items[i])
            elseif category == "playlist" then
                display = display_playlist(items[i])
            end
            entries[#entries + 1] = display
        end

        browse_loop(entries, items, string.format('%d %s for %s', n, key, query), category, category)
    end
end

local function categories_flow()
    local token = get_spotify_token()
    if not token then rofi_message("No Spotify token") return end

    local cmd = string.format(
        "curl -s -H 'Authorization: Bearer %s' 'https://api.spotify.com/v1/browse/categories?limit=50&locale=en_US'",
        token
    )
    local raw = shell(cmd)
    local data = safe_json_decode(raw)
    if not data or not data.categories or not data.categories.items then
        rofi_message("Failed to load categories")
        return
    end

    local cats = data.categories.items
    local cat_entries = {}
    for _, c in ipairs(cats) do
        cat_entries[#cat_entries + 1] = c.name
    end

    push_session({ view = "browse_categories" })
    while true do
        local idx = rofi_dmenu({
            entries = cat_entries,
            prompt = "Categories",
            mesg = string.format('Categories - %d categories', #cats),
            custom = false,
            by_index = true,
        })
        if not idx then return end
        if idx < 1 or idx > #cats then goto continue end

        local cat = cats[idx]
        local pcmd = string.format(
            "curl -s -H 'Authorization: Bearer %s' 'https://api.spotify.com/v1/browse/categories/%s/playlists?limit=20'",
            token, cat.id
        )
        local praw = shell(pcmd)
        local pdata = safe_json_decode(praw)
        if not pdata or not pdata.playlists or not pdata.playlists.items then
            rofi_message("No playlists found")
            goto continue
        end

        local playlists = pdata.playlists.items
        local pl_entries = {}
        for _, pl in ipairs(playlists) do
            pl_entries[#pl_entries + 1] = display_playlist(pl)
        end

        browse_loop(pl_entries, playlists, string.format('%s - %d playlist%s', cat.name, #playlists, #playlists ~= 1 and "s" or ""), "playlist", "playlist")

        ::continue::
    end
end

local function top_tracks_flow()
    local token = get_spotify_token()
    if not token then rofi_message("No Spotify token") return end

    local tracks
    for _, range in ipairs({ "short_term", "medium_term", "long_term" }) do
        local cmd = string.format(
            "curl -s -H 'Authorization: Bearer %s' 'https://api.spotify.com/v1/me/top/tracks?limit=50&time_range=%s'",
            token, range
        )
        local raw = shell(cmd)
        local data = safe_json_decode(raw)
        if data and data.items and #data.items > 0 then
            tracks = data.items
            break
        end
    end

    if not tracks then
        rofi_message("No top tracks found")
        return
    end

    local entries = {}
    for i, t in ipairs(tracks) do
        entries[i] = string.format("%2d. %s", i, display_track(t))
    end

    return browse_loop(entries, tracks, string.format('Top Tracks - %d track%s', #tracks, #tracks ~= 1 and "s" or ""), "track", "top-tracks")
end

local function weekly_flow()
    local data = safe_json_decode(shell("timeout 2 spotify_player get item playlist --id 37i9dQZEVXcQHbTJZxVQMH 2>/dev/null"))
    if not data or not data.tracks or #data.tracks == 0 then
        rofi_message("No tracks found")
        return
    end

    local tracks = data.tracks
    local track_entries = {}
    for i, t in ipairs(tracks) do
        track_entries[i] = string.format("%2d. %s", i, display_track(t))
    end

    return browse_loop(track_entries, tracks, string.format('Discover Weekly - %d track%s', #tracks, #tracks ~= 1 and "s" or ""), "track", "discover-weekly")
end

local function ensure_daemon()
    local pid = trim(shell("pgrep -x spotify_player 2>/dev/null") or "")
    if pid == "" then
        if not get_spotify_token() then
            os.execute("rofi -e " .. shell_quote("Authenticate spotify-player in order to use this interface") .. " -theme " .. shell_quote(THEME_MESSAGE) .. " -markup 2>/dev/null")
            os.exit(0)
        end
        os.execute("nohup spotify_player -d </dev/null &")
    end
end

local function load_user_data_from_sp_cache()
    local raw = read_file(HOME .. "/.cache/spotify-player/SavedTracks_cache.json")
    if raw then
        local data = safe_json_decode(raw)
        if data then
            for _, v in pairs(data) do
                if type(v) == "table" and v.id then
                    liked_tracks[v.id] = true
                end
            end
        end
    end

    raw = read_file(HOME .. "/.cache/spotify-player/SavedAlbums_cache.json")
    if raw then
        local data = safe_json_decode(raw)
        if data then
            for _, v in ipairs(data) do
                if type(v) == "table" and v.id then
                    saved_albums[v.id] = true
                end
            end
        end
    end

    raw = read_file(HOME .. "/.cache/spotify-player/Playlists_cache.json")
    if raw then
        local data = safe_json_decode(raw)
        if data then
            for _, v in ipairs(data) do
                local p = v and v.Playlist
                if type(p) == "table" and p.id then
                    user_playlists[p.id] = true
                end
            end
        end
    end

    raw = read_file(HOME .. "/.cache/spotify-player/FollowedArtists_cache.json")
    if raw then
        local data = safe_json_decode(raw)
        if data then
            for _, v in ipairs(data) do
                if type(v) == "table" and v.id then
                    followed_artists[v.id] = true
                end
            end
        end
    end
end

local function load_liked_tracks_from_cache()
    local tracks = {}
    local raw = read_file(HOME .. "/.cache/spotify-player/SavedTracks_cache.json")
    if not raw then return tracks end
    local data = safe_json_decode(raw)
    if not data then return tracks end
    for _, v in pairs(data) do
        if type(v) == "table" and v.id and v.name then
            tracks[#tracks + 1] = v
            liked_tracks[v.id] = true
        end
    end

    local order = fetch_liked_order()
    if order and #order > 0 then
        local order_map = {}
        for i, entry in ipairs(order) do
            order_map[entry.id] = i
        end
        table.sort(tracks, function(a, b)
            return (order_map[a.id] or 999999) < (order_map[b.id] or 999999)
        end)
    else
        table.sort(tracks, function(a, b)
            return (a.name or ""):lower() < (b.name or ""):lower()
        end)
    end
    return tracks
end

local function track_browse_flow(items, name, context)
    if not items or #items == 0 then
        rofi_message("No tracks found")
        return nil
    end
    local n = #items
    local entries = {}
    for i = 1, n do
        entries[#entries + 1] = string.format("%2d. %s", i, display_track(items[i]))
    end
    return browse_loop(entries, items, string.format('%s - %d track%s', name, n, n ~= 1 and "s" or ""), "track", context)
end

local function liked_tracks_flow()
    local tracks = load_liked_tracks_from_cache()
    return track_browse_flow(tracks, "Liked Tracks", "liked")
end

local function saved_albums_flow()
    local raw = read_file(HOME .. "/.cache/spotify-player/SavedAlbums_cache.json")
    local data = safe_json_decode(raw)
    if not data then rofi_message("No saved albums") return end
    local albums = {}
    for _, a in ipairs(data) do
        if type(a) == "table" and a.id then albums[#albums + 1] = a end
    end
    if #albums == 0 then rofi_message("No saved albums") return end
    table.sort(albums, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    local entries = {}
    for i, a in ipairs(albums) do entries[i] = display_album(a) end
    browse_loop(entries, albums, string.format('Saved Albums - %d album%s', #albums, #albums ~= 1 and "s" or ""), "album", "album")
end

local function followed_artists_flow()
    local raw = read_file(HOME .. "/.cache/spotify-player/FollowedArtists_cache.json")
    local data = safe_json_decode(raw)
    if not data then rofi_message("No followed artists") return end
    local artists = {}
    for _, a in ipairs(data) do
        if type(a) == "table" and a.id then artists[#artists + 1] = a end
    end
    if #artists == 0 then rofi_message("No followed artists") return end
    table.sort(artists, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    local entries = {}
    for i, a in ipairs(artists) do entries[i] = display_artist(a) end
    browse_loop(entries, artists, string.format('Followed Artists - %d artist%s', #artists, #artists ~= 1 and "s" or ""), "artist", "artist")
end

local function main()
    ensure_daemon()
    load_user_data_from_sp_cache()
    if not (next(liked_tracks) and next(saved_albums) and next(user_playlists) and next(followed_artists)) then
        load_user_data()
    end
    load_queue()

    local session = peek_session()
    while session do
        pop_session()
        get_playback_status()
        local handled = true
        if session.view == "action" and current_track_item and session.track_id == current_track_item.id then
            show_actions(current_track_item, "track", nil)
        elseif session.view == "lyrics" and current_track_item and session.track_id == current_track_item.id then
            show_lyrics(current_track_item)
            local s2 = peek_session()
            if s2 and s2.view == "action" and current_track_item and s2.track_id == current_track_item.id then
                pop_session()
                show_actions(current_track_item, "track", nil)
            end
        elseif session.view == "album" and session.album_id then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item album --id " .. shell_quote(session.album_id) .. " 2>/dev/null"))
            if data and data.tracks and #data.tracks > 0 then
                local tracks = data.tracks
                local track_entries = {}
                for i, t in ipairs(tracks) do
                    track_entries[i] = string.format("%2d. %s", i, display_track(t, true))
                end
                browse_loop(track_entries, tracks, string.format('%s - %s', session.album_name or "Album", artist_names(data.album or data)), "track", "album", "album", session.album_id)
            end
        elseif session.view == "playlist" and session.playlist_id then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item playlist --id " .. shell_quote(session.playlist_id) .. " 2>/dev/null"))
            if data and data.tracks and #data.tracks > 0 then
                local tracks = data.tracks
                local track_entries = {}
                for i, t in ipairs(tracks) do
                    track_entries[i] = string.format("%2d. %s", i, display_track(t))
                end
                browse_loop(track_entries, tracks, string.format('%s - %d track%s', session.playlist_name or "Playlist", #tracks, #tracks ~= 1 and "s" or ""), "track", "playlist", "playlist", session.playlist_id)
            end
        elseif session.view == "tracks" and session.context then
            if session.context == "liked" then liked_tracks_flow() end
        elseif session.view == "top_tracks" then
            top_tracks_flow()
        elseif session.view == "discover_weekly" then
            weekly_flow()
        elseif session.view == "artist_albums" and session.artist_id then
            artist_browse_flow({ id = session.artist_id, name = session.artist_name or "" })
        elseif session.view == "artist_actions" and session.artist_id then
            show_artist_actions({ id = session.artist_id, name = session.artist_name or "" })
        elseif session.view == "liked_by_artist" and session.artist_id then
            liked_tracks_by_artist_flow({ id = session.artist_id, name = session.artist_name or "" })
        elseif session.view == "top_tracks_by_artist" and session.artist_id then
            artist_top_tracks_flow({ id = session.artist_id, name = session.artist_name or "" })
        elseif session.view == "browse_categories" then
            categories_flow()
        else
            handled = false
        end
        if handled then invalidate_playback_cache() end
        if not handled then clear_session(); break end
        session = peek_session()
    end

    while true do
        get_playback_status()

        local options = {
            "Track Options",
            "Liked Tracks",
            "Top Tracks",
            "Saved Albums",
            "Followed Artists",
            "Discover Weekly",
            "Categories",
            "Search",
            "Play / Pause",
            "Next Track",
            "Previous Track",
            current_shuffle and "Shuffle: On" or "Shuffle: Off",
            current_repeat == "off" and "Repeat: Off" or (current_repeat == "track" and "Repeat: Track" or "Repeat: Context"),
            "Volume",
        }

        local mesg = get_playback_message()

        local selection = rofi_dmenu({
            entries = options,
            prompt = "Spotify",
            mesg = mesg,
            sel = 0,
            custom = false,
            use_menu = false,
        })
        if not selection or selection == "" then return end

        if selection == "Search" then
            local types = { "Tracks", "Albums", "Artists", "Playlists" }
            local prompts = { "Track", "Album", "Artist", "Playlist" }
            local search_idx = rofi_dmenu({
                entries = types,
                prompt = "Search",
                mesg = mesg,
                custom = false,
                by_index = true,
                use_menu = false,
            })
            if search_idx and search_idx >= 1 and search_idx <= #types then
                search_flow(prompts[search_idx]:lower())
            end
        elseif selection == "Liked Tracks" then
            liked_tracks_flow()
        elseif selection == "Saved Albums" then
            saved_albums_flow()
        elseif selection == "Followed Artists" then
            followed_artists_flow()
        elseif selection == "Categories" then
            categories_flow()
        elseif selection == "Top Tracks" then
            top_tracks_flow()
        elseif selection == "Discover Weekly" then
            weekly_flow()
        elseif selection == "Play / Pause" then
            os.execute("spotify_player playback play-pause")
            invalidate_playback_cache()
        elseif selection == "Next Track" then
            if queue_tracks then
                local pos = queue_idx
                if current_track_id then
                    for i, tid in ipairs(queue_tracks) do
                        if tid == current_track_id then pos = i; break end
                    end
                end
                if pos < #queue_tracks then
                    queue_idx = pos + 1
                    os.execute("spotify_player playback start track --id " .. shell_quote(queue_tracks[queue_idx]))
                    flush_queue()
                else
                    os.execute("spotify_player playback next")
                end
            else
                os.execute("spotify_player playback next")
            end
            invalidate_playback_cache()
        elseif selection == "Previous Track" then
            if queue_tracks then
                local pos = queue_idx
                if current_track_id then
                    for i, tid in ipairs(queue_tracks) do
                        if tid == current_track_id then pos = i; break end
                    end
                end
                if pos > 1 then
                    queue_idx = pos - 1
                    os.execute("spotify_player playback start track --id " .. shell_quote(queue_tracks[queue_idx]))
                    flush_queue()
                else
                    os.execute("spotify_player playback previous")
                end
            else
                os.execute("spotify_player playback previous")
            end
            invalidate_playback_cache()
        elseif selection:find("^Shuffle") then
            os.execute("spotify_player playback shuffle")
            invalidate_playback_cache()
        elseif selection:find("^Repeat") then
            os.execute("spotify_player playback repeat")
            invalidate_playback_cache()
        elseif selection == "Volume" then
            local vol_entries = { "25%", "50%", "75%", "100%" }
            local vol_idx = rofi_dmenu({
                entries = vol_entries,
                prompt = "Volume",
                custom = false,
                by_index = true,
            })
            if vol_idx and vol_idx >= 1 and vol_idx <= #vol_entries then
                local vol = vol_idx * 25
                os.execute("spotify_player playback volume " .. vol)
            end
        elseif selection == "Track Options" then
            if not current_track_item then
                rofi_message("No track playing")
            else
                show_actions(current_track_item, "track", nil)
                invalidate_playback_cache()
            end
        end
    end
end

-- ── CLI TRANSPORT MODE ─────────────────────────────────────────────────────
-- Handles keyboard keybind requests (next, prev, play-pause) by reading
-- the self-managed playback queue written by the rofi browse interface.
--
-- Keybinds should use a fallback chain in their Hyprland/desktop config:
--   lua ~/.config/rofi/scripts/spotify/spotify.lua next || playerctl next
--
-- When there is no active queue file, this exits non-zero so playerctl
-- handles it.  When a queue exists, the correct track from the album /
-- playlist / liked-tracks list is played directly via `spotify_player
-- playback start track --id`, bypassing the daemon's broken context queue.
--
-- Accepted arguments:  next, prev, play-pause

if arg and arg[1] then
    local action = arg[1]
    if action == "play-pause" then
        os.execute("spotify_player playback play-pause")
        os.exit(0)
    end
    if action == "next" or action == "prev" then
        if not load_queue() then os.exit(1) end
        local pos = queue_idx
        local raw = shell("timeout 1 spotify_player get key playback 2>/dev/null")
        local data = safe_json_decode(raw)
        local current_id = data and data.item and data.item.id
        if current_id then
            for i, tid in ipairs(queue_tracks) do
                if tid == current_id then pos = i; break end
            end
        end
        if action == "next" then
            if pos >= #queue_tracks then os.exit(1) end
            queue_idx = pos + 1
        else
            if pos <= 1 then os.exit(1) end
            queue_idx = pos - 1
        end
        flush_queue()
        os.execute("spotify_player playback start track --id " .. shell_quote(queue_tracks[queue_idx]))
        os.exit(0)
    end
end

main()
