# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

updates=$(paru -Qu 2>/dev/null)
count=$(echo "$updates" | grep -v '^$' | wc -l)

if [ "$count" -eq 0 ]; then
  echo "{\"text\": \"\", \"tooltip\": \"Up to date\", \"class\": \"\"}"
  exit 0
fi

repo_count=$(paru -Qu --repo 2>/dev/null | grep -v '^$' | wc -l)
aur_count=$(paru -Qu --aur 2>/dev/null | grep -v '^$' | wc -l)

packages=$(echo "$updates" | grep -v '^$' | awk '{print $1}' | head -10)

if [ "$count" -gt 10 ]; then
  packages="$packages\n..."
fi

tooltip="$packages\n\n󰣇 $repo_count   $aur_count"

echo "{\"text\": \" $count\", \"tooltip\": \"${tooltip//$'\n'/\\n}\", \"class\": \"has-updates\"}"
