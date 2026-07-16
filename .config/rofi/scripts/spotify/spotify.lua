#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local HOME = os.getenv("HOME")
local DIR = HOME .. "/.config/rofi/scripts/spotify"
local THEME = DIR .. "/spotify.rasi"
local THEME_MENU = DIR .. "/spotify-menus.rasi"
local CACHE_FILE = HOME .. "/.cache/spotify_rofi/user_data.json"
local LIKED_ORDER_CACHE = HOME .. "/.cache/spotify_rofi/liked_order.json"
local TOKEN_FILE = HOME .. "/.cache/spotify-player/user_client_token.json"
local CACHE_MAX_AGE = 300
local MAX_RESULTS = 20
local ICON_LIKED = "\u{f05d}"
local ICON_EXPLICIT = "󰯹"

local json = require("cjson")

local liked_tracks = {}
local saved_albums = {}
local user_playlists = {}
local followed_artists = {}
local current_track_id = nil

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
                    if data.refresh_token then
                        local cmd = string.format(
                            "curl -s -X POST https://accounts.spotify.com/api/token -d grant_type=refresh_token -d refresh_token=%s -d client_id=%s",
                            data.refresh_token, "d8a5ed958d274c2e8ee717e6a4b0971d"
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
                                write_file(TOKEN_FILE, json.encode(data))
                            end
                        end
                    end
                end
            end
        end
    end
    return data.access_token
end

local function fetch_liked_order()
    local cached = read_file(LIKED_ORDER_CACHE)
    if cached and file_age(LIKED_ORDER_CACHE) < CACHE_MAX_AGE then
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

local function escape_markup(s)
    s = tostring(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
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

local function duration_ms(track)
    local d = track.duration
    if type(d) == "table" then
        return (val(d, "secs", 0) or 0) * 1000 + math.floor((val(d, "nanos", 0) or 0) / 1000000)
    end
    return val(track, "duration_ms", 0) or 0
end

local function ensure_cache_dir()
    os.execute("mkdir -p " .. shell_quote(HOME .. "/.cache/spotify_rofi"))
end

local function load_cached_user_data()
    local f = io.open(CACHE_FILE, "r")
    if not f then return false end
    local raw = f:read("*a")
    f:close()
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
    local f = io.open(CACHE_FILE, "w")
    if not f then return end
    f:write(json.encode(data))
    f:close()
end

local function load_user_data()
    if load_cached_user_data() then return end

    for attempt = 1, 3 do
        local raw_liked = shell("timeout 10 spotify_player get key user-liked-tracks 2>/dev/null")
        if raw_liked and #raw_liked > 100 then
            for id in raw_liked:gmatch('"id":"([A-Za-z0-9]+)"') do
                liked_tracks[id] = true
            end
            if next(liked_tracks) then break end
        end
        os.execute("sleep 0.5")
    end

    for attempt = 1, 3 do
        local raw = shell("timeout 10 spotify_player get key user-saved-albums 2>/dev/null")
        local data = safe_json_decode(raw)
        if data and type(data) == "table" then
            local items = data.items or data
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.id then
                        saved_albums[item.id] = true
                    end
                end
            end
            if next(saved_albums) then break end
        end
        os.execute("sleep 0.5")
    end

    for attempt = 1, 3 do
        local raw = shell("timeout 10 spotify_player get key user-playlists 2>/dev/null")
        local data = safe_json_decode(raw)
        if data and type(data) == "table" then
            local items = data.items or data
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.id then
                        user_playlists[item.id] = true
                    end
                end
            end
            if next(user_playlists) then break end
        end
        os.execute("sleep 0.5")
    end

    for attempt = 1, 3 do
        local raw_artists = shell("timeout 10 spotify_player get key user-followed-artists 2>/dev/null")
        if raw_artists and #raw_artists > 10 then
            local artist_data = safe_json_decode(raw_artists)
            if artist_data and type(artist_data) == "table" then
                for _, item in ipairs(artist_data) do
                    if type(item) == "table" and item.id then
                        followed_artists[item.id] = true
                    end
                end
            end
            if next(followed_artists) then break end
        end
        os.execute("sleep 0.5")
    end

    save_cached_user_data()
end

local function get_playback_status()
    local out = shell("timeout 1 spotify_player get key playback 2>/dev/null")
    local data = safe_json_decode(out)
    if not data then return nil end
    local track = data.item
    if not track or type(track) ~= "table" then return nil end
    current_track_id = track.id
    local artists = {}
    for _, a in ipairs(track.artists or {}) do
        if type(a) == "table" and a.name then
            artists[#artists + 1] = a.name
        end
    end
    local artist = #artists > 0 and table.concat(artists, ", ") or "Unknown"
    local name = track.name or "Unknown"
    local duration = duration_ms(track)
    local position = val(data, "progress_ms", 0) or 0
    local state = data.is_playing and "Playing" or "Paused"
    local min_d = math.floor(duration / 60000)
    local sec_d = math.floor((duration % 60000) / 1000)
    local min_p = math.floor(position / 60000)
    local sec_p = math.floor((position % 60000) / 1000)
    return string.format("%s | %s - %s | %d:%02d/%d:%02d", state, name, artist, min_p, sec_p, min_d, sec_d)
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

    local theme = use_menu and THEME_MENU or THEME
    local args = { "rofi", "-dmenu", "-theme", theme, "-p", prompt }
    if not custom then args[#args + 1] = "-no-custom" end
    if markup then
        args[#args + 1] = "-markup-rows"
        args[#args + 1] = "-markup"
    end
    if eh then args[#args + 1] = "-eh"; args[#args + 1] = tostring(eh) end
    if sel then args[#args + 1] = "-selected-row"; args[#args + 1] = tostring(sel) end

    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, "w")
    if not f then return nil end
    for _, e in ipairs(entries) do
        f:write(e .. "\n")
    end
    f:close()

    if mesg then
        args[#args + 1] = "-mesg"
        args[#args + 1] = shell_quote(mesg)
    end

    local quoted_args = {}
    for _, a in ipairs(args) do
        quoted_args[#quoted_args + 1] = shell_quote(a)
    end
    local cmd = table.concat(quoted_args, " ") .. " < " .. shell_quote(tmpfile)
    local result = shell(cmd)
    os.remove(tmpfile)
    if not result then return nil end
    return trim(result)
end

local function rofi_message(msg)
    os.execute("rofi -e " .. shell_quote(msg) .. " -theme " .. shell_quote(THEME) .. " 2>/dev/null &")
end

local function artist_names(item)
    local artists = {}
    for _, a in ipairs(item.artists or {}) do
        if type(a) == "table" then artists[#artists + 1] = a.name or "Unknown" end
    end
    return table.concat(artists, ", ")
end

local function display_track(item)
    local artists = artist_names(item)
    local liked = liked_tracks[item.id] and (ICON_LIKED .. " ") or ""
    local explicit = val(item, "explicit", false) and (ICON_EXPLICIT .. " ") or ""
    local icons = explicit .. liked
    if #icons > 0 then icons = icons .. " " end
    return string.format("%s%s  %s", icons, item.name or "Unknown", artists)
end

local function display_album(item)
    local artists = artist_names(item)
    local typ = val(item, "typ", "")
    local suffix = ""
    if typ ~= "" then suffix = "  " .. typ end
    local liked = saved_albums[item.id] and (ICON_LIKED .. " ") or ""
    if #liked > 0 then liked = liked .. " " end
    return string.format("%s%s  %s%s", liked, item.name or "Unknown", artists, suffix)
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

local function do_action(action, item, category, context, context_type, context_id, seek_ms)
    local id = item.id
    if not id then return end
    if action == "Play" then
        if context_type and context_id then
            local cmd
            if seek_ms and seek_ms > 0 then
                cmd = string.format(
                    "sh -c 'spotify_player playback start context %s --id %s && sleep 0.5 && spotify_player playback seek %d' &",
                    context_type, context_id, seek_ms
                )
            else
                cmd = string.format(
                    "spotify_player playback start context %s --id %s &",
                    context_type, context_id
                )
            end
            os.execute(cmd)
        elseif context == "liked" then
            local cmd
            if seek_ms and seek_ms > 0 then
                cmd = string.format(
                    "sh -c 'spotify_player playback start liked --limit 1000 && sleep 0.5 && spotify_player playback seek %d' &",
                    seek_ms
                )
            else
                cmd = "spotify_player playback start liked --limit 1000 &"
            end
            os.execute(cmd)
        elseif category == "track" then
            os.execute("spotify_player playback start track --id " .. shell_quote(id) .. " &")
        elseif context == "artist" then
            os.execute("spotify_player playback start context artist --id " .. shell_quote(id) .. " &")
        else
            os.execute("spotify_player playback start track --id " .. shell_quote(id) .. " &")
        end
    elseif action == "Play Next" then
        os.execute("spotify_player playback add next --id " .. shell_quote(id) .. " &")
    elseif action == "Add to Queue" then
        os.execute("spotify_player playback add queue --id " .. shell_quote(id) .. " &")
    elseif action == "Like" then
        os.execute("spotify_player like &")
        liked_tracks[id] = true
        save_cached_user_data()
    elseif action == "Unlike" then
        os.execute("spotify_player like --unlike &")
        liked_tracks[id] = nil
        save_cached_user_data()
    elseif action == "Open in Spotify" then
        os.execute("xdg-open spotify:" .. category .. ":" .. id .. " &")
    end
end

local function show_actions(item, category, context, context_type, context_id, seek_ms)
    local is_liked = category == "track" and liked_tracks[item.id]

    local actions
    if category == "track" then
        actions = { "Play", "Play Next", "Add to Queue", is_liked and "Unlike" or "Like", "Open in Spotify" }
    else
        actions = { "Play", "Open in Spotify" }
    end

    local name = item.name or "Unknown"
    local cat_label = category:sub(1, 1):upper() .. category:sub(2)
    if context then cat_label = cat_label .. " (" .. context .. ")" end

    while true do
        local sel = rofi_dmenu({
            entries = actions,
            prompt = "Action",
            mesg = cat_label .. "  " .. name,
            sel = 0,
            custom = false,
        })
        if not sel or sel == "" then return end
        do_action(sel, item, category, context, context_type, context_id, seek_ms)
        if sel == "Like" or sel == "Unlike" then
            is_liked = not is_liked
            actions[4] = is_liked and "Unlike" or "Like"
        else
            return
        end
    end
end

local function browse_loop(entries, items, mesg, category, context)
    while true do
        local sel = rofi_dmenu({
            entries = entries,
            prompt = context or "Browse",
            mesg = mesg,
            custom = false,
        })
        if not sel or sel == "" then return end

        local idx = tonumber(sel:match("^(%d+)"))
        if not idx or idx < 1 or idx > #items then goto continue end
        local item = items[idx]

        if category == "artist" then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item artist --id " .. shell_quote(item.id) .. " 2>/dev/null"))
            if not data or not data.albums or #data.albums == 0 then
                rofi_message("No albums found")
                goto continue
            end
            local albums = data.albums
            local album_entries = {}
            for i, a in ipairs(albums) do
                album_entries[#album_entries + 1] = string.format("%d %s", i, display_album(a))
            end
            while true do
                local asel = rofi_dmenu({
                    entries = album_entries,
                    prompt = escape_markup(item.name),
                    mesg = string.format('%d album%s', #albums, #albums ~= 1 and "s" or ""),
                    custom = false,
                })
                if not asel or asel == "" then break end
                local aidx = tonumber(asel:match("^(%d+)"))
                if not aidx or aidx < 1 or aidx > #albums then goto continue end
                local album = albums[aidx]
                local adata = safe_json_decode(shell("timeout 2 spotify_player get item album --id " .. shell_quote(album.id) .. " 2>/dev/null"))
                if not adata or not adata.tracks or #adata.tracks == 0 then
                    rofi_message("No tracks found")
                    goto continue
                end
                local tracks = adata.tracks
                local track_entries = {}
                for i, t in ipairs(tracks) do
                    track_entries[#track_entries + 1] = string.format("%d %s", i, display_track(t))
                end
                while true do
                    local tsel = rofi_dmenu({
                        entries = track_entries,
                        prompt = escape_markup(album.name),
                        mesg = string.format('%d track%s', #tracks, #tracks ~= 1 and "s" or ""),
                        custom = false,
                    })
                    if not tsel or tsel == "" then break end
                    local tidx = tonumber(tsel:match("^(%d+)"))
                    if tidx and tidx >= 1 and tidx <= #tracks then
                        local seek_ms = 0
                        for j = 1, tidx - 1 do
                            seek_ms = seek_ms + (duration_ms(tracks[j]))
                        end
                        show_actions(tracks[tidx], "track", "album", "album", album.id, seek_ms)
                    end
                end
            end
        elseif category == "album" then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item album --id " .. shell_quote(item.id) .. " 2>/dev/null"))
            if not data or not data.tracks or #data.tracks == 0 then
                rofi_message("No tracks found")
                goto continue
            end
            local tracks = data.tracks
            local track_entries = {}
            for i, t in ipairs(tracks) do
                track_entries[#track_entries + 1] = string.format("%d %s", i, display_track(t))
            end
            while true do
                local tsel = rofi_dmenu({
                    entries = track_entries,
                    prompt = escape_markup(item.name),
                    mesg = string.format('%d track%s', #tracks, #tracks ~= 1 and "s" or ""),
                    custom = false,
                })
                if not tsel or tsel == "" then break end
                local tidx = tonumber(tsel:match("^(%d+)"))
                if tidx and tidx >= 1 and tidx <= #tracks then
                    local seek_ms = 0
                    for j = 1, tidx - 1 do
                        seek_ms = seek_ms + (duration_ms(tracks[j]))
                    end
                    show_actions(tracks[tidx], "track", "album", "album", item.id, seek_ms)
                end
            end
        elseif category == "playlist" then
            local data = safe_json_decode(shell("timeout 2 spotify_player get item playlist --id " .. shell_quote(item.id) .. " 2>/dev/null"))
            if not data or not data.tracks or #data.tracks == 0 then
                rofi_message("No tracks found")
                goto continue
            end
            local tracks = data.tracks
            local track_entries = {}
            for i, t in ipairs(tracks) do
                track_entries[#track_entries + 1] = string.format("%d %s", i, display_track(t))
            end
            while true do
                local tsel = rofi_dmenu({
                    entries = track_entries,
                    prompt = escape_markup(item.name),
                    mesg = string.format('%d track%s', #tracks, #tracks ~= 1 and "s" or ""),
                    custom = false,
                })
                if not tsel or tsel == "" then break end
                local tidx = tonumber(tsel:match("^(%d+)"))
                if tidx and tidx >= 1 and tidx <= #tracks then
                    local seek_ms = 0
                    for j = 1, tidx - 1 do
                        seek_ms = seek_ms + (duration_ms(tracks[j]))
                    end
                    show_actions(tracks[tidx], "track", "playlist", "playlist", item.id, seek_ms)
                end
            end
        elseif category == "track" then
            local seek_ms = nil
            if context == "liked" then
                seek_ms = 0
                for j = 1, idx - 1 do
                    seek_ms = seek_ms + duration_ms(items[j])
                end
            end
            show_actions(item, "track", context, nil, nil, seek_ms)
        end

        ::continue::
    end
end

local function search_flow(category)
    while true do
        local query = rofi_dmenu({
            entries = {},
            prompt = "Search " .. category:sub(1, 1):upper() .. category:sub(2),
            mesg = "Type your query and press Enter",
            use_menu = true,
        })
        if not query or query == "" then return end

        local raw = shell("spotify_player search " .. shell_quote(query) .. " 2>/dev/null")
        local results = safe_json_decode(raw)
        if not results then
            rofi_message("No results or spotify_player unavailable")
            goto continue
        end

        local key = category .. "s"
        local items = results[key]
        if not items or type(items) ~= "table" or #items == 0 then
            rofi_message("No " .. key .. " found")
            goto continue
        end

        local n = math.min(#items, MAX_RESULTS)
        local entries = {}
        for i = 1, n do
            local display
            if category == "track" then
                display = display_track(items[i])
            elseif category == "album" then
                display = display_album(items[i])
            elseif category == "artist" then
                display = display_artist(items[i])
            elseif category == "playlist" then
                display = display_playlist(items[i])
            end
            entries[#entries + 1] = string.format("%d %s", i, display)
        end

        browse_loop(entries, items, string.format('%d %s%s', n, key, n ~= 1 and "s" or ""), category, category)

        ::continue::
    end
end

local function ensure_daemon()
    local pid = trim(shell("pgrep -x spotify_player 2>/dev/null") or "")
    if pid == "" then
        os.execute("spotify_player -d &")
        os.execute("sleep 1")
    end
end

local function load_user_data_from_sp_cache()
    local f = io.open(HOME .. "/.cache/spotify-player/SavedTracks_cache.json", "r")
    if f then
        local raw = f:read("*a")
        f:close()
        local data = safe_json_decode(raw)
        if data then
            for _, v in pairs(data) do
                if type(v) == "table" and v.id then
                    liked_tracks[v.id] = true
                end
            end
        end
    end

    f = io.open(HOME .. "/.cache/spotify-player/SavedAlbums_cache.json", "r")
    if f then
        local raw = f:read("*a")
        f:close()
        local data = safe_json_decode(raw)
        if data and type(data) == "table" then
            for _, v in ipairs(data) do
                if type(v) == "table" and v.id then
                    saved_albums[v.id] = true
                end
            end
        end
    end

    f = io.open(HOME .. "/.cache/spotify-player/Playlists_cache.json", "r")
    if f then
        local raw = f:read("*a")
        f:close()
        local data = safe_json_decode(raw)
        if data and type(data) == "table" then
            for _, v in ipairs(data) do
                local p = v and v.Playlist
                if type(p) == "table" and p.id then
                    user_playlists[p.id] = true
                end
            end
        end
    end

    f = io.open(HOME .. "/.cache/spotify-player/FollowedArtists_cache.json", "r")
    if f then
        local raw = f:read("*a")
        f:close()
        local data = safe_json_decode(raw)
        if data and type(data) == "table" then
            for _, v in ipairs(data) do
                if type(v) == "table" and v.id then
                    followed_artists[v.id] = true
                end
            end
        end
    end
end

local liked_order = nil

local function load_liked_tracks_from_cache()
    local tracks = {}
    local f = io.open(HOME .. "/.cache/spotify-player/SavedTracks_cache.json", "r")
    if not f then return tracks end
    local raw = f:read("*a")
    f:close()
    local data = safe_json_decode(raw)
    if not data then return tracks end
    for _, v in pairs(data) do
        if type(v) == "table" and v.id and v.name then
            tracks[#tracks + 1] = v
            liked_tracks[v.id] = true
        end
    end

    liked_order = fetch_liked_order()
    if liked_order and #liked_order > 0 then
        local order_map = {}
        for i, entry in ipairs(liked_order) do
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

local function track_browse_flow(items, mesg, context)
    if not items or #items == 0 then
        rofi_message("No tracks found")
        return
    end
    local n = #items
    local entries = {}
    for i = 1, n do
        entries[#entries + 1] = string.format("%d %s", i, display_track(items[i]))
    end
    browse_loop(entries, items, string.format('%d track%s', n, n ~= 1 and "s" or ""), "track", context)
end

local function liked_tracks_flow()
    local tracks = load_liked_tracks_from_cache()
    track_browse_flow(tracks, nil, "liked")
end

local function main()
    get_playback_status()
    local is_liked = current_track_id and liked_tracks[current_track_id]
    local like_label = is_liked and "Unlike Current Track" or "Like Current Track"

    local options = {
        "Search Tracks",
        "Search Albums",
        "Search Artists",
        "Search Playlists",
        "Liked Tracks",
        "Play / Pause",
        "Next Track",
        "Previous Track",
        "Shuffle",
        "Repeat",
        "Volume",
        like_label,
    }

    local mesg = nil
    local playback = get_playback_status()
    if playback then
        local like_icon = ""
        if current_track_id and liked_tracks[current_track_id] then
            like_icon = ICON_LIKED .. " "
        end
        mesg = like_icon .. playback
    end

    local selection = rofi_dmenu({
        entries = options,
        prompt = "Spotify",
        mesg = mesg,
        sel = 0,
        custom = false,
        use_menu = false,
    })
    if not selection or selection == "" then return false end

    if selection == "Search Tracks" then
        search_flow("track")
    elseif selection == "Search Albums" then
        search_flow("album")
    elseif selection == "Search Artists" then
        search_flow("artist")
    elseif selection == "Search Playlists" then
        search_flow("playlist")
    elseif selection == "Liked Tracks" then
        liked_tracks_flow()
    elseif selection == "Play / Pause" then
        os.execute("spotify_player playback play-pause &")
    elseif selection == "Next Track" then
        os.execute("spotify_player playback next &")
    elseif selection == "Previous Track" then
        os.execute("spotify_player playback previous &")
    elseif selection == "Shuffle" then
        os.execute("spotify_player playback shuffle &")
    elseif selection == "Repeat" then
        os.execute("spotify_player playback repeat &")
    elseif selection == "Volume" then
        local input = rofi_dmenu({
            entries = {},
            prompt = "Volume (0-100)",
            use_menu = true,
        })
        if input and input ~= "" then
            local vol = tonumber(trim(input))
            if vol then
                vol = math.max(0, math.min(100, vol))
                os.execute("spotify_player playback volume " .. vol .. " &")
            end
        end
    elseif selection == "Like Current Track" then
        os.execute("spotify_player like &")
        if current_track_id then
            liked_tracks[current_track_id] = true
            save_cached_user_data()
        end
    elseif selection == "Unlike Current Track" then
        os.execute("spotify_player like --unlike &")
        if current_track_id then
            liked_tracks[current_track_id] = nil
            save_cached_user_data()
        end
    end
    return true
end

ensure_daemon()
load_user_data_from_sp_cache()
load_user_data()
while main() do end
