# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

set -e
set -u

# Configuration
all=(lockscreen logout suspend reboot shutdown)
show=("${all[@]}")
confirmations=(reboot shutdown logout)

# Text Labels
declare -A texts
texts[lockscreen]="Lock"
texts[logout]="Logout"
texts[suspend]="Suspend"
texts[reboot]="Reboot"
texts[shutdown]="Shutdown"

# Actions
declare -A actions
actions[lockscreen]="hyprlock"
actions[logout]="loginctl terminate-session ${XDG_SESSION_ID-}"
actions[suspend]="systemctl suspend"
actions[reboot]="systemctl reboot"
actions[shutdown]="systemctl poweroff"

# Options
dryrun=false
showsymbols=false
showtext=true

# Validation
if [ "$showsymbols" = "false" -a "$showtext" = "false" ]; then
  echo "Invalid options: cannot have --no-symbols and --no-text enabled at the same time." >&2
  exit 1
fi

# Helper Functions
write_message() {
  # Generates Pango markup
  echo -n "<span font_size=\"medium\">$2</span>"
}

print_selection() {
  # Safely extracts the raw string from rofi's input
  echo -e "$1" | {
    read -r -d '' entry
    echo "$entry"
  }
}

# Pre-calculate Messages
declare -A messages
declare -A confirmationMessages

for entry in "${all[@]}"; do
  messages[$entry]=$(write_message "" "${texts[$entry]^}")
done

for entry in "${all[@]}"; do
  confirmationMessages[$entry]=$(write_message "" "Confirm ${texts[$entry]}")
done
confirmationMessages[cancel]=$(write_message "" "CANCEL")

# Determine Input Source
if [ $# -gt 0 ]; then
  selection="$*"
else
  if [ -n "${selectionID+x}" ]; then
    selection="${messages[$selectionID]}"
  fi
fi

# Rofi Header
echo -e "\0no-custom\x1ftrue"
echo -e "\0markup-rows\x1ftrue"

# Main Logic
if [ -z "${selection+x}" ]; then
  # MODE 1: Show the main menu
  echo -e "\0prompt\x1fPower Menu"
  for entry in "${show[@]}"; do
    echo -e "${messages[$entry]}"
  done
else
  # MODE 2: Process Selection
  
  matched=false
  
  # 1. Check against Main Menu Options
  for entry in "${show[@]}"; do
    if [ "$selection" = "$(print_selection "${messages[$entry]}")" ]; then
      matched=true
      
      # SPECIAL CASE: Lockscreen (No confirmation, immediate background exec)
      if [ "$entry" = "lockscreen" ]; then
        if [ "$dryrun" = true ]; then
          echo "Selected: $entry" >&2
        else
          # Critical: Run in background, silence ALL output, detach from shell
          ( ${actions[$entry]} >/dev/null 2>&1 & )
        fi
        exit 0
      fi

      # SPECIAL CASE: Actions requiring confirmation
      needs_confirm=false
      for conf in "${confirmations[@]}"; do
        if [ "$entry" = "$conf" ]; then
          needs_confirm=true
          break
        fi
      done

      if [ "$needs_confirm" = true ]; then
        # Show confirmation screen
        echo -e "\0prompt\x1fAre you sure?"
        echo -e "${confirmationMessages[$entry]}"
        echo -e "${confirmationMessages[cancel]}"
        exit 0
      else
        # Execute immediate actions (Suspend)
        if [ "$dryrun" = true ]; then
          echo "Selected: $entry" >&2
        else
          ${actions[$entry]}
        fi
        exit 0
      fi
    fi
  done

  # 2. Check against Confirmation Screen Options (if main match wasn't found)
  if [ "$matched" = false ]; then
    for entry in "${confirmations[@]}"; do
      if [ "$selection" = "$(print_selection "${confirmationMessages[$entry]}")" ]; then
        if [ "$dryrun" = true ]; then
          echo "Selected: $entry" >&2
        else
          ${actions[$entry]}
        fi
        exit 0
      fi
    done

    if [ "$selection" = "$(print_selection "${confirmationMessages[cancel]}")" ]; then
      exit 0
    fi
  fi

  # Fallback
  echo "Invalid selection: $selection" >&2
  exit 1
fi   
