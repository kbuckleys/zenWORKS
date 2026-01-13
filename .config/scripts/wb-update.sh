# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

# Cooldown check: skip if updated in last minute
if [ -f /tmp/paru-updated ] && find /tmp/paru-updated -mmin -1 | grep -q .; then
  rm -f /tmp/paru-updated
  exit 0
fi

# Touch cooldown file
touch /tmp/paru-updated

# Get all updates
updates=$(paru -Qu 2>/dev/null)
count=$(echo "$updates" | grep -v '^$' | wc -l)

if [ "$count" -eq 0 ]; then
  echo '{"text": "󰏖 0", "class": "updated", "tooltip": "System up to date"}'
  exit 0
fi

# Count repo vs AUR
repo_count=$(paru -Qu --repo 2>/dev/null | grep -v '^$' | wc -l)
aur_count=$(paru -Qu --aur 2>/dev/null | grep -v '^$' | wc -l)

# Package list for tooltip (first 10)
packages=$(echo "$updates" | grep -v '^$' | awk '{print $1}' | head -10)
if [ "$count" -gt 10 ]; then
  packages="$packages\n..."
fi

# Escape newlines and build tooltip
tooltip="$packages\n\n󰣇 $repo_count    $aur_count"
tooltip="${tooltip//$'\n'/\\n}"

# Output consistent JSON keys matching class-names
echo "{\"text\": \" $count\", \"tooltip\": \"${tooltip}\", \"class\": \"has-updates\"}"
