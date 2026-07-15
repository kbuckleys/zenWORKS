#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┘
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local GPU_INDEX = tonumber(os.getenv("NVIDIA_GPU_INDEX")) or 0
local WARN_TEMP = tonumber(os.getenv("NVIDIA_WARN_TEMP")) or 70
local WARN_UTIL = tonumber(os.getenv("NVIDIA_WARN_UTIL")) or 80
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

local function output_json(text, tooltip, percentage)
    local obj = {
        text = text,
        tooltip = tooltip,
        class = "nvidia-gpu",
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
        output_json("N/A", "nvidia-smi not found", 0)
        return
    end

    local result = trim(handle:read("*a"))
    handle:close()

    if not result or result == "" then
        output_json("N/A", "No GPU data", 0)
        return
    end

    local gpus = {}
    for line in result:gmatch("[^\n]+") do
        gpus[#gpus + 1] = line
    end

    if #gpus == 0 then
        output_json("N/A", "No GPU data", 0)
        return
    end

    local gpu_line = gpus[GPU_INDEX + 1] or gpus[1]

    local fields = {}
    for field in gpu_line:gmatch("[^,]+") do
        fields[#fields + 1] = trim(field)
    end

    if #fields < 3 then
        output_json("ERR", "Unexpected nvidia-smi output", 0)
        return
    end

    local gpu_name = fields[1] or "GPU"
    local gpu_util = tonumber(fields[2]) or 0
    local gpu_temp = tonumber(fields[3]) or 0
    local gpu_vram = tonumber(fields[4]) or 0
    local gpu_power = tonumber(fields[5]) or 0
    local gpu_clock = tonumber(fields[6]) or 0

    local vram_gb = string.format("%.1f", gpu_vram / 1024)

    local gpu_text = colorize(gpu_util, MID_UTIL, WARN_UTIL)
    local temp_text = colorize(gpu_temp, MID_TEMP, WARN_TEMP)

    local text = " GPU " .. gpu_text .. "%  VRAM " .. vram_gb .. "G  " .. temp_text .. "°"
    local tooltip = string.format(
        "<b>%s</b>\n\nUtilization: %d%%\nTemperature: %d°C\nVRAM: %s GB\nPower: %gw\nClock: %d MHz",
        gpu_name, gpu_util, gpu_temp, vram_gb, gpu_power, gpu_clock
    )

    output_json(text, tooltip, gpu_util)
end

main()
