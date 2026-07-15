#!/usr/bin/lua

-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local handle = io.popen(
  'busctl --user call org.kde.StatusNotifierWatcher '
  .. '/StatusNotifierWatcher org.freedesktop.DBus.Properties Get '
  .. 'ss org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null'
)

if handle then
  local result = handle:read("*a")
  handle:close()

  local count = result and result:match('^v%s+as%s+(%d+)')

  if count and tonumber(count) > 0 then
    print('{"text":"   ", "class":"visible"}')
  else
    print('{"text":"", "class":"hidden"}')
  end
else
  print('{"text":"", "class":"hidden"}')
end
