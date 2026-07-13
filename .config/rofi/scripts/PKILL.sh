# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/usr/bin/env bash

THEME="$HOME/.config/rofi/PKILL.rasi"

selection=$(
    ps -eo pid=,user=,args= --sort=pid |
    awk '{
        pid=$1
        user=$2
        $1=$2=""
        sub(/^  */, "")
        printf "%6s  %-10s  %s\n", pid, user, $0
    }' |
    rofi \
        -dmenu \
        -i \
        -p "Kill Process" \
        -theme "$THEME"
)

[[ -z "$selection" ]] && exit 0

pid=$(awk '{print $1}' <<< "$selection")

[[ "$pid" =~ ^[0-9]+$ ]] || exit 1

CONFIRM_THEME="$HOME/.config/rofi/PKILLOK.rasi"

confirm=$(
    printf "Kill Process\nAbort" |
    rofi \
        -dmenu \
        -markup-rows \
        -p "Confirm" \
        -mesg "<span background='#e78284' foreground='#000000'>$selection</span>" \
        -selected-row 0 \
        -theme "$CONFIRM_THEME"
)

[[ "$confirm" == "Kill Process" ]] || exec "$0"

kill "$pid"
