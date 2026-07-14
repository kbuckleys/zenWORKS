#!/bin/bash
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set -uo pipefail

THEME="$HOME/.config/rofi/PKILL.rasi"
CONFIRM_THEME="$HOME/.config/rofi/PKILLOK.rasi"

while true; do
  selection=$(
    ps -eo pid=,user=,args= --sort=pid |
      awk '{pid=$1;user=$2;$1=$2="";sub(/^  */,"");printf "%-6s %-8s %s\n",pid,user,$0}' |
      rofi -dmenu -i -p "Kill Process" -theme "$THEME"
  )

  [ -z "$selection" ] && exit 0

  pid=$(awk '{print $1}' <<< "$selection")
  [[ "$pid" =~ ^[0-9]+$ ]] || exit 1

  confirm=$(
    printf "Kill Process\nAbort" |
      rofi -dmenu -p "Confirm" -mesg "$selection" -selected-row 0 -theme "$CONFIRM_THEME"
  )

  [ "$confirm" = "Kill Process" ] || continue

  if kill "$pid" 2>/dev/null; then
    exit 0
  fi
  rofi -e "Failed to kill PID $pid (permission denied?)" -theme "$CONFIRM_THEME"
  exit 1
done
