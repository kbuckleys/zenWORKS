# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

result=$(busctl --user call org.kde.StatusNotifierWatcher \
  /StatusNotifierWatcher org.freedesktop.DBus.Properties Get \
  ss org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null)

count=$(echo "$result" | awk '{print $3}')

if [ -n "$count" ] && [ "$count" -gt 0 ]; then
  echo '{"text":"  ", "class":"visible"}'
else
  echo '{"text":"", "class":"hidden"}'
fi
