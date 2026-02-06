# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# Original script by https://github.com/jluttine
# Modified by https://github.com/kbuckleys/

#!/bin/bash

set -e
set -u

all=(lockscreen logout suspend reboot shutdown)

show=("${all[@]}")

declare -A texts
texts[lockscreen]="Lock"
texts[logout]="logout"
texts[suspend]="Suspend"
texts[reboot]="Reboot"
texts[shutdown]="Shutdown"

declare -A actions
actions[lockscreen]="loginctl lock-session ${XDG_SESSION_ID-}"
actions[logout]="loginctl terminate-session ${XDG_SESSION_ID-}"
actions[suspend]="systemctl suspend"
actions[reboot]="systemctl reboot"
actions[shutdown]="systemctl poweroff"

confirmations=(reboot shutdown logout)

dryrun=false
showsymbols=false
showtext=true

function check_valid {
  option="$1"
  shift 1
  for entry in "${@}"; do
    if [ -z "${actions[$entry]+x}" ]; then
      echo "Invalid choice in $1: $entry" >&2
      exit 1
    fi
  done
}

if [ "$showsymbols" = "false" -a "$showtext" = "false" ]; then
  echo "Invalid options: cannot have --no-symbols and --no-text enabled at the same time." >&2
  exit 1
fi

function write_message {
  text="<span font_size=\"medium\">$2</span>"
  echo -n "$text"
}

function print_selection {
  echo -e "$1" | $(
    read -r -d '' entry
    echo "echo $entry"
  )
}

declare -A messages
declare -A confirmationMessages
for entry in "${all[@]}"; do
  messages[$entry]=$(write_message "" "${texts[$entry]^}") # Pass empty string for icon
done
for entry in "${all[@]}"; do
  confirmationMessages[$entry]=$(write_message "" "Confirm ${texts[$entry]}") # No icon
done
confirmationMessages[cancel]=$(write_message "" "CANCEL") # No icon

if [ $# -gt 0 ]; then
  selection="${@}"
else
  if [ -n "${selectionID+x}" ]; then
    selection="${messages[$selectionID]}"
  fi
fi

echo -e "\0no-custom\x1ftrue"
echo -e "\0markup-rows\x1ftrue"

if [ -z "${selection+x}" ]; then
  echo -e "\0prompt\x1fPower Menu"
  for entry in "${show[@]}"; do
    echo -e "${messages[$entry]}"
  done
else
  for entry in "${show[@]}"; do
    if [ "$selection" = "$(print_selection "${messages[$entry]}")" ]; then
      for confirmation in "${confirmations[@]}"; do
        if [ "$entry" = "$confirmation" ]; then
          echo -e "\0prompt\x1fAre you sure?"
          echo -e "${confirmationMessages[$entry]}"
          echo -e "${confirmationMessages[cancel]}"
        fi
      done
      selection=$(print_selection "${confirmationMessages[$entry]}")
    fi
    if [ "$selection" = "$(print_selection "${confirmationMessages[$entry]}")" ]; then
      if [ $dryrun = true ]; then
        echo "Selected: $entry" >&2
      else
        ${actions[$entry]}
      fi
      exit 0
    fi
    if [ "$selection" = "$(print_selection "${confirmationMessages[cancel]}")" ]; then
      exit 0
    fi
  done
  echo "Invalid selection: $selection" >&2
  exit 1
fi
