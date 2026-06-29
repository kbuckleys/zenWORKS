# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

set -e

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nerdfont-cheatsheet.txt"
URL="https://raw.githubusercontent.com/J-HaleOf76/NerdFont-Cheat-Sheet_file/main/nerdfont.txt"
MAX_AGE=86400

selected=$(rofi -dmenu -i -p "Nerd Icons" \
     -theme ~/.config/rofi/nerd-icons.rasi \
     < <(grep -v '^#' "$CACHE" 2>/dev/null | grep -v '^$') \
  | awk '{print $1}' \
  | tr -d '[:space:]')

if [ -n "$selected" ]; then
  echo -n "$selected" | wl-copy --type text/plain
fi

if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -c %Y "$CACHE"))) -gt $MAX_AGE ]; then
  (
    curl -fsSL "$URL" -o "$CACHE.tmp" && \
    mv "$CACHE.tmp" "$CACHE"
  ) &
fi
