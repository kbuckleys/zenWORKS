# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

output_dir="$HOME/Videos/Captures"
mkdir -p "$output_dir"

if pgrep -x "wf-recorder" >/dev/null; then
  notify-send "Recording Stopped" "wf-recorder"
  pkill -SIGINT -f wf-recorder
  exit 0
fi

windows=$(hyprctl clients -j | jq -r '.[] | select(.hidden == false) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | sort -n)

notify-send "Select a window to capture" "wf-recorder"
geometry=$(echo "$windows" | slurp)

[ -z "$geometry" ] && {
  notify-send "Aborted: No window selected" "wf-recorder"
  exit 1
}

filename="$output_dir/window_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
audio_monitor=$(pactl list short sources | grep monitor | head -1 | awk '{print $2}')

notify-send "Recording initiated" "wf-recorder"
wf-recorder -c libx264rgb -g "$geometry" --audio="$audio_monitor" --file="$filename"
