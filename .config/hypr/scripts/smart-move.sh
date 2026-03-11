# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash
dir=$1

# Get active window address and check floating state directly
active_addr=$(hyprctl activewindow | grep "floating:" | awk '{print $2}')
if [[ "$active_addr" == "1" ]]; then
  # Floating window
  case $dir in
  r) hyprctl dispatch moveactive 50 0 ;;
  l) hyprctl dispatch moveactive -50 0 ;;
  d) hyprctl dispatch moveactive 0 50 ;;
  u) hyprctl dispatch moveactive 0 -50 ;;
  esac
else
  # Tiled window
  case $dir in
  r) hyprctl dispatch movewindow r ;;
  l) hyprctl dispatch movewindow l ;;
  d) hyprctl dispatch movewindow d ;;
  u) hyprctl dispatch movewindow u ;;
  esac
fi
