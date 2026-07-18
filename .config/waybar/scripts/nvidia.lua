#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local GPU_INDEX = tonumber(os.getenv("NVIDIA_GPU_INDEX")) or 0
local WARN_TEMP = tonumber(os.getenv("NVIDIA_WARN_TEMP")) or 70
local WARN_UTIL = tonumber(os.getenv("NVIDIA_WARN_UTIL")) or 80
local CRIT_TEMP = tonumber(os.getenv("NVIDIA_CRIT_TEMP")) or 85
local CRIT_UTIL = tonumber(os.getenv("NVIDIA_CRIT_UTIL")) or 95
local MID_TEMP = tonumber(os.getenv("NVIDIA_MID_TEMP")) or 50
local MID_UTIL = tonumber(os.getenv("NVIDIA_MID_UTIL")) or 50

local COLOR_WARN = "#e78284"
local COLOR_MID = "#e0d8a4"

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function json_escape(s)
    return s:gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
            :gsub('\t', '\\t')
end

local function pango_escape(s)
    return s:gsub('&', '&amp;')
            :gsub('<', '&lt;')
            :gsub('>', '&gt;')
end

local function colorize(value, mid, warn)
    if value >= warn then
        return "<span foreground='" .. COLOR_WARN .. "'>" .. pango_escape(tostring(value)) .. "</span>"
    elseif value >= mid then
        return "<span foreground='" .. COLOR_MID .. "'>" .. pango_escape(tostring(value)) .. "</span>"
    end
    return pango_escape(tostring(value))
end

local function parse_csv_fields(line)
    local fields = {}
    local i = 1
    while i <= #line do
        if line:sub(i, i) == '"' then
            i = i + 1
            local field = ""
            while i <= #line do
                local c = line:sub(i, i)
                if c == '"' then
                    if line:sub(i + 1, i + 1) == '"' then
                        field = field .. '"'
                        i = i + 2
                    else
                        i = i + 1
                        if line:sub(i, i) == ',' then
                            i = i + 1
                        end
                        break
                    end
                else
                    field = field .. c
                    i = i + 1
                end
            end
            fields[#fields + 1] = field
        else
            local comma = line:find(',', i)
            if comma then
                fields[#fields + 1] = trim(line:sub(i, comma - 1))
                i = comma + 1
            else
                fields[#fields + 1] = trim(line:sub(i))
                break
            end
        end
    end
    return fields
end

local function state_class(util, temp)
    if util >= CRIT_UTIL or temp >= CRIT_TEMP then
        return " critical"
    elseif util >= WARN_UTIL or temp >= WARN_TEMP then
        return " warning"
    elseif util >= MID_UTIL or temp >= MID_TEMP then
        return " mid"
    end
    return ""
end

local function output_json(text, tooltip, percentage, state)
    local obj = {
        text = text,
        tooltip = tooltip,
        class = "nvidia-gpu" .. state,
        percentage = percentage
    }
    local parts = {}
    for k, v in pairs(obj) do
        local val
        if type(v) == "number" then
            val = tostring(v)
        else
            val = '"' .. json_escape(tostring(v)) .. '"'
        end
        parts[#parts + 1] = '"' .. k .. '": ' .. val
    end
    io.stdout:write('{' .. table.concat(parts, ', ') .. '}\n')
    io.stdout:flush()
end

local function main()
    local handle = io.popen("nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,power.draw,clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null")
    if not handle then
        output_json("N/A", "nvidia-smi not found", 0, "")
        return
    end

    local result = trim(handle:read("*a"))
    local ok, _, exitcode = handle:close()

    if not ok then
        output_json("N/A", "nvidia-smi failed (exit " .. (exitcode or "?") .. ")", 0, "")
        return
    end

    if not result or result == "" then
        output_json("N/A", "No GPU data", 0, "")
        return
    end

    local gpu_line
    do
        local idx = 0
        for line in result:gmatch("[^\n]+") do
            if idx == GPU_INDEX then
                gpu_line = line
                break
            end
            idx = idx + 1
        end
        if not gpu_line then
            output_json("N/A", "No GPU data", 0, "")
            return
        end
    end

    local fields = parse_csv_fields(gpu_line)

    if #fields < 3 then
        output_json("ERR", "Unexpected nvidia-smi output", 0, "")
        return
    end

    local gpu_name = fields[1] or "GPU"
    local gpu_util = tonumber(fields[2]) or 0
    local gpu_temp = tonumber(fields[3]) or 0
    local gpu_vram = tonumber(fields[4]) or 0
    local gpu_power = tonumber(fields[5]) or 0
    local gpu_clock = tonumber(fields[6]) or 0

    local has_power = fields[5] and tonumber(fields[5]) ~= nil
    local has_clock = fields[6] and tonumber(fields[6]) ~= nil

    local vram_str
    if gpu_vram < 1024 then
        vram_str = string.format("%dM", gpu_vram)
    else
        vram_str = string.format("%.1fG", gpu_vram / 1024)
    end

    local gpu_text = colorize(gpu_util, MID_UTIL, WARN_UTIL)
    local temp_text = colorize(gpu_temp, MID_TEMP, WARN_TEMP)

    local text = " GPU " .. gpu_text .. "%  VRAM " .. vram_str .. "  " .. temp_text .. "°"
    local tooltip = string.format("<b>%s</b>\n\nUtilization: %d%%\nTemperature: %d°C\nVRAM: %s\nPower: ",
        gpu_name, gpu_util, gpu_temp, vram_str)
    if has_power then
        tooltip = tooltip .. string.format("%.1fW", gpu_power)
    else
        tooltip = tooltip .. "N/A"
    end
    tooltip = tooltip .. "\nClock: "
    if has_clock then
        tooltip = tooltip .. string.format("%d MHz", gpu_clock)
    else
        tooltip = tooltip .. "N/A"
    end

    output_json(text, tooltip, gpu_util, state_class(gpu_util, gpu_temp))
end

main()
