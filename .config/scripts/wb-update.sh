# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

STATE_FILE="/tmp/paru-state.json"

updates=$(paru -Qu 2>/dev/null)
count=$(echo "$updates" | grep -v '^$' | wc -l)

if [ "$count" -eq 0 ]; then
  RESULT='{"text": "", "tooltip": "Up to date", "class": ""}'
else
  repo_count=$(paru -Qu --repo 2>/dev/null | grep -v '^$' | wc -l)
  aur_count=$(paru -Qu --aur 2>/dev/null | grep -v '^$' | wc -l)
  packages=$(echo "$updates" | grep -v '^$' | awk '{print $1}' | head -10)

  [ "$count" -gt 10 ] && packages="$packages\n..."
  tooltip="$packages\n\n󰣇 $repo_count   $aur_count"
  RESULT="{\"text\": \" $count\", \"tooltip\": \"${tooltip//$'\n'/\\n}\", \"class\": \"has-updates\"}"
fi

echo "$RESULT" >"$STATE_FILE"
echo "$RESULT"
