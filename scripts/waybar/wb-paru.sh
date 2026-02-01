# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

STATE_FILE="/tmp/paru-state.json"
SYNC_FILE="/tmp/paru-last-sync"
NOTIFY_FILE="/tmp/paru-last-notified"

# Hourly refresh
NOW=$(date +%s)
if [ -f "$SYNC_FILE" ]; then
  LAST_SYNC=$(cat "$SYNC_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - LAST_SYNC)) -ge 3600 ]; then
    paru -Syuq 2>/dev/null || true
    echo "$NOW" >"$SYNC_FILE"
  fi
else
  paru -Syuq 2>/dev/null || true
  echo "$NOW" >"$SYNC_FILE"
fi

# 60s result cache
if [ -f "$STATE_FILE" ]; then
  LAST_UPDATE=$(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - LAST_UPDATE)) -lt 10 ]; then
    cat "$STATE_FILE"
    exit 0
  fi
fi

# Fresh update check
updates=$(paru -Qu 2>/dev/null)
count=$(echo "$updates" | grep -v '^$' | wc -l)

if [ "$count" -eq 0 ]; then
  RESULT='{"text": "", "tooltip": "Up to date", "class": ""}'
  echo 0 >"$NOTIFY_FILE"
else
  repo_count=$(paru -Qu --repo 2>/dev/null | grep -v '^$' | wc -l)
  aur_count=$(paru -Qu --aur 2>/dev/null | grep -v '^$' | wc -l)
  packages=$(echo "$updates" | grep -v '^$' | awk '{print $1}' | head -10)
  [ "$count" -gt 10 ] && packages="$packages\n..."
  tooltip="$packages\n\n󰣇 $repo_count   $aur_count"
  RESULT="{\"text\": \" $count\", \"tooltip\": \"${tooltip//$'\n'/\\n}\", \"class\": \"has-updates\"}"

  # Smart notifications
  if [ -f "$NOTIFY_FILE" ]; then
    LAST_COUNT=$(cat "$NOTIFY_FILE" 2>/dev/null || echo 0)
    if [ "$count" -gt "$LAST_COUNT" ]; then
      notify-send "System Update" " $count packages ready\n󰣇 $repo_count   $aur_count" -u normal -t 10000
    fi
  fi
  echo "$count" >"$NOTIFY_FILE"
fi

echo "$RESULT" >"$STATE_FILE"
echo "$RESULT"
