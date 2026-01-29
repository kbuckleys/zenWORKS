# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

output_dir="$HOME/Videos/Captures"
mkdir -p "$output_dir"

# Check if wf-recorder is already running
if pgrep -x "wf-recorder" >/dev/null; then
  notify-send "Recording Stopped" "wf-recorder"
  pkill -SIGINT -f wf-recorder
  exit 0
fi

notify-send "Select a region to capture" "wf-recorder"
geometry=$(echo "$windows" | slurp)

# Get geometry for selected area using slurp
geometry=$(slurp 2>/dev/null)
if [ -z "$geometry" ]; then
  notify-send "Aborted: No region selected" "wf-recorder"
  exit 1
fi

filename="$output_dir/capture_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
audio_monitor=$(pactl list short sources | grep monitor | head -1 | awk '{print $2}')

notify-send "Recording initiated" "wf-recorder"
wf-recorder -c libx264rgb -g "$geometry" --audio="$audio_monitor" --file="$filename"
