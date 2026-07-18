#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local TRAY_TIMEOUT = os.getenv("TRAY_TIMEOUT") or "2"

local handle = io.popen(
  'busctl --user --timeout=' .. TRAY_TIMEOUT .. ' call org.kde.StatusNotifierWatcher '
  .. '/StatusNotifierWatcher org.freedesktop.DBus.Properties Get '
  .. 'ss org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null'
)

if not handle then
  print('{"text":"N/A", "class":"error"}')
  return
end

local result = handle:read("*a")
local ok = handle:close()

if not ok then
  print('{"text":"N/A", "class":"error"}')
  return
end

local count = result and result:match('^v%s+as%s+(%d+)')

if count and tonumber(count) > 0 then
  print('{"text":"   ", "class":"visible"}')
else
  print('{"text":"", "class":"hidden"}')
end
