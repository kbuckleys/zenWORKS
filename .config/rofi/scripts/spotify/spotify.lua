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
                            "curl -s -X POST https://accounts.spotify.com/api/token -d grant_type=refresh_token --data-urlencode %s -d client_id=%s",
                            shell_quote("refresh_token=" .. data.refresh_token),
                            "d8a5ed958d274c2e8ee717e6a4b0971d"
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

local function start_context_at_uri(context_uri, track_id)
    local token = get_spotify_token()
    if not token then return false end
    local payload = string.format(
        '{"context_uri":"%s","offset":{"uri":"spotify:track:%s"}}',
        context_uri, track_id
    )
    local tmpfile = os.tmpname()
    write_file(tmpfile, payload)
    local cmd = string.format(
        "curl -s -w '%%{http_code}' -X PUT 'https://api.spotify.com/v1/me/player/play' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d @%s -o /dev/null",
        token, tmpfile
    )
    local result = shell(cmd)
    os.remove(tmpfile)
    return result and result:match("204") ~= nil
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
        local h_liked = io.popen("timeout 10 spotify_player get key user-liked-tracks 2>/dev/null", "r")
        local h_albums = io.popen("timeout 10 spotify_player get key user-saved-albums 2>/dev/null", "r")
        local h_playlists = io.popen("timeout 10 spotify_player get key user-playlists 2>/dev/null", "r")
        local h_artists = io.popen("timeout 10 spotify_player get key user-followed-artists 2>/dev/null", "r")

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
    local out = shell("timeout 1 spotify_player get key playback 2>/dev/null")
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
    local args = { "rofi", "-dmenu", "-theme", theme, "-p", prompt, "-i" }
    if not custom then args[#args + 1] = "-no-custom" end
    if markup then
        args[#args + 1] = "-markup-rows"
        args[#args + 1] = "-markup"
    end
    if by_index then args[#args + 1] = "-format"; args[#args + 1] = "i" end
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
        args[#args + 1] = mesg
    end

    local quoted_args = {}
    for _, a in ipairs(args) do
        quoted_args[#quoted_args + 1] = shell_quote(a)
    end
    local cmd = table.concat(quoted_args, " ") .. " < " .. shell_quote(tmpfile)
    local result = shell(cmd)
    os.remove(tmpfile)
    if not result then return nil end
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
    os.execute("rofi -e " .. shell_quote(msg) .. " -theme " .. shell_quote(THEME) .. " 2>/dev/null")
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
    local playing = item.id == current_track_id and (current_is_playing and "\u{f04b}  " or "\u{f04c}  ") or ""
    local liked = liked_tracks[item.id] and (ICON_LIKED .. " ") or ""
    local explicit = val(item, "explicit", false) and (ICON_EXPLICIT .. " ") or ""
    local icons = playing .. explicit .. liked
    if #icons > 0 then icons = icons .. " " end
    if hide_artist then
        return string.format("%s%s", icons, item.name or "Unknown")
    end
    return string.format("%s%s  %s", icons, item.name or "Unknown", artists)
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
        local played = false
        if context_type and context_id then
            local uri = "spotify:" .. context_type .. ":" .. context_id
            played = start_context_at_uri(uri, id)
            if not played then
                os.execute(string.format("spotify_player playback start context %s --id %s &", context_type, context_id))
            end
        elseif context == "liked" then
            played = start_context_at_uri("spotify:collection:tracks", id)
            if not played then
                os.execute("spotify_player playback start track --id " .. shell_quote(id) .. " &")
            end
        elseif context == "discover-weekly" then
            played = start_context_at_uri("spotify:playlist:37i9dQZEVXcQHbTJZxVQMH", id)
            if not played then
                os.execute("spotify_player playback start track --id " .. shell_quote(id) .. " &")
            end
        elseif context == "top-tracks" then
            os.execute("spotify_player playback start track --id " .. shell_quote(id) .. " &")
            if all_items and current_idx then
                local token = get_spotify_token()
                if token then
                    local lines = {"#!/bin/sh"}
                    for i = current_idx + 1, math.min(current_idx + 49, #all_items) do
                        lines[#lines + 1] = string.format(
                            "curl -s -o /dev/null -X POST 'https://api.spotify.com/v1/me/player/queue?uri=spotify:track:%s' -H 'Authorization: Bearer %s' && sleep 0.2",
                            all_items[i].id, token
                        )
                    end
                    local tmpfile = os.tmpname()
                    write_file(tmpfile, table.concat(lines, "\n"))
                    os.execute("sh " .. shell_quote(tmpfile) .. " &")
                    os.execute("sleep 5 && rm -f " .. shell_quote(tmpfile) .. " &")
                end
            end
        elseif context == "artist" then
            os.execute("spotify_player playback start context artist --id " .. shell_quote(id) .. " &")
        else
            os.execute("spotify_player playback start track --id " .. shell_quote(id) .. " &")
        end
    elseif action == "Add to Queue" then
        add_to_queue(id)
    elseif action == "Like" then
        local token = get_spotify_token()
        if token then
            os.execute(string.format("curl -s -o /dev/null -X PUT 'https://api.spotify.com/v1/me/tracks?ids=%s' -H 'Authorization: Bearer %s' &", id, token))
        end
        liked_tracks[id] = true
        save_cached_user_data()
    elseif action == "Unlike" then
        local token = get_spotify_token()
        if token then
            os.execute(string.format("curl -s -o /dev/null -X DELETE 'https://api.spotify.com/v1/me/tracks?ids=%s' -H 'Authorization: Bearer %s' &", id, token))
        end
        liked_tracks[id] = nil
        save_cached_user_data()
    elseif action == "Open in Spotify" then
        os.execute("xdg-open " .. shell_quote("spotify:" .. category .. ":" .. id) .. " &")
    end
end

local show_actions
local browse_loop

local function artist_browse_flow(artist)
    local data = safe_json_decode(shell("timeout 2 spotify_player get item artist --id " .. shell_quote(artist.id) .. " 2>/dev/null"))
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
        while true do
            local tidx = rofi_dmenu({
                entries = track_entries,
                prompt = album.name,
                mesg = string.format('%s - %s', album.name, artist_names(album)),
                custom = false,
                by_index = true,
            })
            if not tidx then break end
            if tidx >= 1 and tidx <= #tracks then
                local result = show_actions(tracks[tidx], "track", "album", "album", album.id)
                if result == "played" then return "played" end
                if result then
                    table.remove(tracks, tidx)
                    table.remove(track_entries, tidx)
                else
                    track_entries[tidx] = string.format("%2d. %s", tidx, display_track(tracks[tidx], true))
                end
            end
        end
        ::continue::
    end
end

show_actions = function(item, category, context, context_type, context_id, all_items, current_idx)
    if category ~= "track" then
        do_action("Play", item, category, context, context_type, context_id)
        return "played"
    end

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
            return "played"
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
                    if browse_loop(track_entries, tracks, string.format('%s - %s', album.name or "Album", artist_names(album)), "track", "album", "album", album.id) == "played" then return "played" end
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
                    if artist_browse_flow(artist) == "played" then return "played" end
                end
            end
        elseif sel == "Lyrics" then
            local out = shell("timeout 2 spotify_player lyrics --id " .. shell_quote(item.id) .. " 2>/dev/null")
            out = out and trim(out) or ""
            if out == "" then
                rofi_message("No lyrics found")
            else
                local lines = {}
                local skip_first = true
                for raw_line in out:gmatch("[^\n]+") do
                    if skip_first then
                        skip_first = false
                    else
                        local line = raw_line
                        if #line > 80 then
                            while #line > 80 do
                                local break_at = line:sub(1, 80):match(".*()%s")
                                if not break_at or break_at < 20 then break_at = 80 end
                                lines[#lines + 1] = line:sub(1, break_at)
                                line = line:sub(break_at + 1):match("^%s*(.*)") or line:sub(break_at + 1)
                            end
                            if #line > 0 then lines[#lines + 1] = line end
                        else
                            lines[#lines + 1] = line
                        end
                    end
                end
                local lyrics_mesg = build_track_mesg(item)
                rofi_dmenu({
                    entries = lines,
                    prompt = "Lyrics",
                    mesg = lyrics_mesg,
                    custom = false,
                    use_menu = true,
                    theme = THEME_LYRICS,
                })
            end
        elseif sel == "Open in Spotify" then
            os.execute("xdg-open " .. shell_quote("spotify:" .. category .. ":" .. item.id) .. " &")
        end
    end
end

browse_loop = function(entries, items, mesg, category, context, context_type, context_id)
    local played = false
    while not played do
        local idx = rofi_dmenu({
            entries = entries,
            prompt = context or "Browse",
            mesg = mesg,
            custom = false,
            by_index = true,
        })
        if not idx then return nil end
        if idx < 1 or idx > #items then goto continue end
        local item = items[idx]

        if category == "artist" then
            local result = artist_browse_flow(item)
            if result == "played" then played = true end
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
            if browse_loop(track_entries, tracks, string.format('%s - %s', item.name, artist_names(item)), "track", "album", "album", item.id) == "played" then return "played" end
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
            if browse_loop(track_entries, tracks, string.format('%s - %d track%s', item.name, #tracks, #tracks ~= 1 and "s" or ""), "track", "playlist", "playlist", item.id) == "played" then return "played" end
        elseif category == "track" then
            local result = show_actions(item, "track", context, context_type, context_id, items, idx)
            if result == "played" then
                played = true
            elseif result then
                table.remove(items, idx)
                table.remove(entries, idx)
                if #items == 0 then
                    rofi_message("No tracks left")
                    return nil
                end
            else
                entries[idx] = string.format("%2d. %s", idx, display_track(item))
            end
        end

        ::continue::
    end
    if played then return "played" end
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

        if browse_loop(entries, items, string.format('%d %s for %s', n, key, query), category, category) == "played" then return "played" end
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

        if browse_loop(pl_entries, playlists, string.format('%s - %d playlist%s', cat.name, #playlists, #playlists ~= 1 and "s" or ""), "playlist", "playlist") == "played" then return "played" end

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
        if data then
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
        if data then
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

local function main()
    ensure_daemon()
    load_user_data_from_sp_cache()
    if not (next(liked_tracks) and next(saved_albums) and next(user_playlists) and next(followed_artists)) then
        load_user_data()
    end

    while true do
        get_playback_status()

        local options = {
            "Track Options",
            "Liked Tracks",
            "Top Tracks",
            "Discover Weekly",
            "Categories",
            "Search",
            "Play / Pause",
            "Next Track",
            "Previous Track",
            "Shuffle",
            "Repeat",
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
            if liked_tracks_flow() == "played" then return end
        elseif selection == "Categories" then
            if categories_flow() == "played" then return end
        elseif selection == "Top Tracks" then
            if top_tracks_flow() == "played" then return end
        elseif selection == "Discover Weekly" then
            if weekly_flow() == "played" then return end
        elseif selection == "Play / Pause" then
            os.execute("spotify_player playback play-pause")
            return
        elseif selection == "Next Track" then
            os.execute("spotify_player playback next")
            invalidate_playback_cache()
        elseif selection == "Previous Track" then
            os.execute("spotify_player playback previous")
            invalidate_playback_cache()
        elseif selection == "Shuffle" then
            os.execute("spotify_player playback shuffle")
            invalidate_playback_cache()
        elseif selection == "Repeat" then
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
                local result = show_actions(current_track_item, "track", nil)
                if result == "played" then
                    invalidate_playback_cache()
                end
            end
        end
    end
end

main()
