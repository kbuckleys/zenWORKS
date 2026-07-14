#!/bin/bash
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set -uo pipefail

ENTRIES=(
  "lockscreen|Lock|hyprlock|no"
  "kill|Kill|$HOME/.config/rofi/scripts/PKILL.sh|no"
  "suspend|Suspend|systemctl suspend|no"
  "logout|Logout|hyprshutdown -p 'loginctl terminate-session ${XDG_SESSION_ID-}'|yes"
  "reboot|Reboot|hyprshutdown -p 'systemctl reboot'|yes"
  "shutdown|Shutdown|hyprshutdown -p 'systemctl poweroff'|yes"
)

DRYRUN=false
[ "${1-}" = "--dry-run" ] && { DRYRUN=true; shift; }

CANCEL='<span font_size="medium">CANCEL</span>'
row() { printf '<span font_size="medium">%s</span>' "$1"; }
confirm_row() { printf '<span font_size="medium">Confirm %s</span>' "$1"; }

execute() {
  if $DRYRUN; then echo "Selected: $1" >&2; return; fi
  if [ "$1" = "kill" ]; then setsid "$2" >/dev/null 2>&1 &
  else bash -c "$2" >/dev/null 2>&1 & fi
}

echo -e "\0no-custom\x1ftrue"
echo -e "\0markup-rows\x1ftrue"

selection="$*"

if [ -z "$selection" ]; then
  echo -e "\0prompt\x1fPower Menu"
  for e in "${ENTRIES[@]}"; do
    IFS='|' read -r _ label _ _ <<<"$e"
    row "$label"; echo
  done
  exit 0
fi

for e in "${ENTRIES[@]}"; do
  IFS='|' read -r id label cmd confirm <<<"$e"

  if [ "$selection" = "$(row "$label")" ]; then
    if [ "$id" = "lockscreen" ] || [ "$confirm" = "no" ]; then
      execute "$id" "$cmd"
    else
      echo -e "\0prompt\x1fAre you sure?"
      confirm_row "$label"; echo
      echo "$CANCEL"
    fi
    exit 0
  fi

  if [ "$confirm" = "yes" ] && [ "$selection" = "$(confirm_row "$label")" ]; then
    execute "$id" "$cmd"
    exit 0
  fi
done

[ "$selection" = "$CANCEL" ] && exit 0
echo "Invalid selection: $selection" >&2
exit 1
