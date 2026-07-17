#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local HOME = os.getenv("HOME")
local ROFI_THEME_INPUT = HOME .. "/.config/rofi/scripts/dictionary/dictionary.rasi"
local ROFI_THEME_RESULTS = HOME .. "/.config/rofi/scripts/dictionary/dictionary-output.rasi"
local MAX_LINE_LENGTH = 80
local MAX_DEFS_PER_POS = 2
local MAX_LINES = 20

local COLOR_HEAD = "#9bbfbf"
local COLOR_PHON = "#9bbfbf"
local COLOR_POS = "#6a707f"
local COLOR_EX = "#eebebe"
local COLOR_SYN = "#9bbfbf"
local COLOR_ERROR = "#e78284"

-- JSON parsing
local json = require("cjson")

-- URL encode
local function urlencode(str)
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = str:gsub(" ", "+")
    return str
end

-- Shell command with output
local function shell(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- Read file contents
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local content = f:read("*a")
    f:close()
    return content
end

-- Write string to file
local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- Safely remove a file
local function remove_file(path)
    os.remove(path)
end

-- Shell-escape a string (single-quote it)
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- HTML entity decoding
local function decode_html(s)
    s = s:gsub("&nbsp;", " ")
    s = s:gsub("&amp;", "&")
    s = s:gsub("&lt;", "<")
    s = s:gsub("&gt;", ">")
    s = s:gsub("&quot;", '"')
    s = s:gsub("&#39;", "'")
    s = s:gsub("&apos;", "'")
    return s
end

-- Escape for rofi markup
local function escape_markup(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

-- Strip HTML tags and decode entities
local function strip_html(s)
    s = s:gsub("<[^>]*>", "")
    s = decode_html(s)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

-- Check if string has alphanumeric content
local function has_content(s)
    return s:match("[%w]") ~= nil
end

-- Simple word wrap
local function wrap(text, width)
    local lines = {}
    for raw_line in text:gmatch("[^\n]+") do
        local line = raw_line
        while #line > width do
            local break_at = width
            local space = line:sub(1, width):match(".*()%s")
            if space and space > 1 then
                break_at = space
            end
            lines[#lines + 1] = line:sub(1, break_at - 1)
            line = line:sub(break_at + 1)
        end
        lines[#lines + 1] = line
    end
    return lines
end

-- Lookup word on Wiktionary
local function lookup(word)
    local encoded = urlencode(word)
    return shell(string.format(
        'curl -s --max-time 5 "https://en.wiktionary.org/api/rest_v1/page/definition/%s"',
        encoded
    ))
end

-- Check if response has entries
local function has_entries(response)
    if not response or response == "" then return false end
    local ok, data = pcall(json.decode, response)
    if not ok then return false end
    local en = data and data.en
    if type(en) ~= "table" then return false end
    return #en > 0
end

-- Parse definitions into tab-separated rows
local function parse_rows(word, def_response, max_defs)
    local ok, data = pcall(json.decode, def_response)
    if not ok or not data then
        return { "error\tNo definitions found for \"" .. word .. "\". Check spelling?" }
    end

    local en = data.en
    if type(en) ~= "table" or #en == 0 then
        return { "error\tNo definitions found for \"" .. word .. "\". Check spelling?" }
    end

    local rows = {}
    rows[#rows + 1] = "head\t" .. escape_markup(word)

    local grouped = {}
    local pos_order = {}
    for _, entry in ipairs(en) do
        local pos = entry.partOfSpeech or ""
        if not grouped[pos] then
            grouped[pos] = {}
            pos_order[#pos_order + 1] = pos
        end
        local definitions = entry.definitions or {}
        for i = 1, math.min(#definitions, max_defs) do
            local def_text = strip_html(definitions[i].definition or "")
            local ex_text = ""
            local examples = definitions[i].examples or {}
            if #examples > 0 then
                ex_text = strip_html(examples[1])
            end
            if has_content(def_text) then
                grouped[pos][#grouped[pos] + 1] = { def = def_text, ex = ex_text }
            end
        end
    end

    for _, pos in ipairs(pos_order) do
        local defs = grouped[pos]
        if #defs > 0 then
            rows[#rows + 1] = "pos\t" .. escape_markup(pos)
            for _, d in ipairs(defs) do
                rows[#rows + 1] = "def\t" .. escape_markup(d.def)
                if has_content(d.ex) then
                    rows[#rows + 1] = "ex\t" .. escape_markup(d.ex)
                end
            end
        end
    end

    if #rows == 1 then
        return { "error\tNo definitions found for \"" .. word .. "\". Check spelling?" }
    end

    return rows
end

-- Parse phonetic from raw API response
local function parse_phonetic(response)
    if not response or response == "" then return "" end

    local ok, data = pcall(json.decode, response)
    if not ok or type(data) ~= "table" or #data == 0 then return "" end

    local entry = data[1]
    local phonetic = entry.phonetic
    if not phonetic or phonetic == "" then
        local phonetics = entry.phonetics or {}
        for _, p in ipairs(phonetics) do
            if p.text and p.text ~= "" then
                phonetic = p.text
                break
            end
        end
    end

    return phonetic and escape_markup(phonetic) or ""
end

-- Parse synonyms from raw API response
local function parse_synonyms(response)
    if not response or response == "" then return "" end

    local ok, data = pcall(json.decode, response)
    if not ok or type(data) ~= "table" then return "" end

    local words = {}
    for _, entry in ipairs(data) do
        if entry.word then
            words[#words + 1] = entry.word
        end
    end

    return table.concat(words, ", ")
end

-- Format output lines from parsed rows
-- Returns: message, lines
local function format_output(rows, phonetic, synonyms)
    local message = ""
    local lines = {}
    local pending_pos_idx = -1

    local function add_blank()
        if #lines > 0 and lines[#lines] ~= "" then
            lines[#lines + 1] = ""
        end
    end

    local function drop_empty_pos()
        if pending_pos_idx >= 0 then
            table.remove(lines, pending_pos_idx)
            if pending_pos_idx > 0 and lines[pending_pos_idx - 1] == "" then
                table.remove(lines, pending_pos_idx - 1)
            end
            pending_pos_idx = -1
        end
    end

    for _, row in ipairs(rows) do
        local tab_pos = row:find("\t")
        if tab_pos then
            local typ = row:sub(1, tab_pos - 1)
            local content = row:sub(tab_pos + 1)

            if typ == "head" then
                message = "<b><span foreground=\"" .. COLOR_HEAD .. "\">" .. content .. "</span></b>"
                if phonetic ~= "" then
                    message = message .. "  <span foreground=\"" .. COLOR_PHON .. "\">" .. phonetic .. "</span>"
                end

            elseif typ == "pos" then
                drop_empty_pos()
                add_blank()
                lines[#lines + 1] = "<span foreground=\"" .. COLOR_POS .. "\"><i>" .. content .. "</i></span>"
                pending_pos_idx = #lines

            elseif typ == "def" then
                if content:match("[%w]") then
                    pending_pos_idx = -1
                    for _, wline in ipairs(wrap(content, MAX_LINE_LENGTH)) do
                        lines[#lines + 1] = "  " .. wline
                    end
                end

            elseif typ == "ex" then
                if content:match("[%w]") then
                    pending_pos_idx = -1
                    for _, wline in ipairs(wrap(content, MAX_LINE_LENGTH)) do
                        lines[#lines + 1] = "  <span foreground=\"" .. COLOR_EX .. "\"><i>" .. wline .. "</i></span>"
                    end
                    lines[#lines + 1] = ""
                end

            elseif typ == "error" then
                lines[#lines + 1] = "<span foreground=\"" .. COLOR_ERROR .. "\">" .. content .. "</span>"
            end
        end
    end
    drop_empty_pos()

    if synonyms ~= "" then
        add_blank()
        lines[#lines + 1] = "<span foreground=\"" .. COLOR_SYN .. "\"><b>Synonyms:</b> " .. synonyms .. "</span>"
    end

    while #lines > 0 and lines[#lines] == "" do
        lines[#lines] = nil
    end

    return message, lines
end

-- Debug mode
if arg[1] == "--debug" then
    local word = arg[2]
    if not word then
        io.stderr:write("usage: dict.lua --debug <word>\n")
        os.exit(1)
    end

    print("### Wiktionary: " .. word .. " ###")
    local def_response = lookup(word)
    print(def_response)

    if not has_entries(def_response) then
        local hyphenated = word:gsub(" ", "-")
        if hyphenated ~= word then
            print("### not found as typed — trying: " .. hyphenated .. " ###")
            local alt = lookup(hyphenated)
            print(alt)
            if has_entries(alt) then
                def_response = alt
            end
        end
    end

    local phonetic = parse_phonetic(shell(string.format(
        'curl -s --max-time 5 "https://api.dictionaryapi.dev/api/v2/entries/en/%s"',
        urlencode(word)
    )))
    print("### computed phonetic: " .. phonetic .. " ###")

    print("### computed rows ###")
    local rows = parse_rows(word, def_response, MAX_DEFS_PER_POS)
    for _, row in ipairs(rows) do
        print(row)
    end

    os.exit(0)
end

-- Main loop
while true do
    local word = shell(string.format(
        'rofi -dmenu -wayland-layer top -theme %s -p "Define"',
        shell_quote(ROFI_THEME_INPUT)
    ))
    if not word or word == "" then break end
    word = word:gsub("%s+$", ""):gsub("^%s+", "")
    if word == "" then break end

    local encoded = urlencode(word)
    local tmp_def = os.tmpname()
    local tmp_syn = os.tmpname()
    local tmp_phon = os.tmpname()

    -- Fetch definitions, synonyms, and pronunciation concurrently
    shell(string.format(
        "curl -s --max-time 5 %s > %s & " ..
        "curl -s --max-time 5 %s > %s & " ..
        "curl -s --max-time 5 %s > %s & " ..
        "wait",
        shell_quote("https://en.wiktionary.org/api/rest_v1/page/definition/" .. encoded), tmp_def,
        shell_quote("https://api.datamuse.com/words?rel_syn=" .. encoded .. "&max=6"), tmp_syn,
        shell_quote("https://api.dictionaryapi.dev/api/v2/entries/en/" .. encoded), tmp_phon
    ))

    local def_response = read_file(tmp_def)
    local syn_response = read_file(tmp_syn)
    local phon_response = read_file(tmp_phon)
    remove_file(tmp_def)
    remove_file(tmp_syn)
    remove_file(tmp_phon)

    if not def_response or def_response == "" then
        local error_msg = '<span foreground="' .. COLOR_ERROR .. '">Network error — couldn\'t reach the dictionary API</span>'
        local err_file = os.tmpname()
        write_file(err_file, error_msg .. "\n")
        shell(string.format(
            'cat %s | rofi -dmenu -wayland-layer top -theme %s -no-sort -lines 1 -p "Definition" -markup-rows',
            err_file, shell_quote(ROFI_THEME_RESULTS)
        ))
        remove_file(err_file)
    else
        if not has_entries(def_response) then
            local hyphenated = word:gsub(" ", "-")
            if hyphenated ~= word then
                local alt = lookup(hyphenated)
                if has_entries(alt) then
                    def_response = alt
                end
            end
        end

        local phonetic = parse_phonetic(phon_response)
        local synonyms = parse_synonyms(syn_response)
        local rows = parse_rows(word, def_response, MAX_DEFS_PER_POS)
        local message, lines = format_output(rows, phonetic, synonyms)

        local n_lines = #lines
        if n_lines > MAX_LINES then n_lines = MAX_LINES end
        if n_lines < 1 then n_lines = 1 end

        local mesg_flag = ""
        if message ~= "" then
            mesg_flag = " -mesg " .. shell_quote(message)
        end

        local tmpfile = os.tmpname()
        local f = io.open(tmpfile, "w")
        for _, line in ipairs(lines) do
            f:write(line .. "\n")
        end
        f:close()
        shell(string.format(
            'cat %s | rofi -dmenu -wayland-layer top -theme %s -no-sort -lines %d -p "Definition" -markup-rows%s',
            tmpfile, shell_quote(ROFI_THEME_RESULTS), n_lines, mesg_flag
        ))
        remove_file(tmpfile)
    end
end
