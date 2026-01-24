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

# Auto-detect active monitor in Hyprland
monitor=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor' 2>/dev/null)

# Fallback: try swaymsg if hyprctl fails
[ -z "$monitor" ] && monitor=$(swaymsg -t get_workspaces -j 2>/dev/null | jq -r '.[] | select(.focused) | .output' 2>/dev/null | head -1)

# Final fallback: first available monitor
[ -z "$monitor" ] && monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null)
[ -z "$monitor" ] && monitor=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[0].name' 2>/dev/null)

[ -z "$monitor" ] && {
  notify-send "No monitor detected"
  exit 1
}

filename="$output_dir/capture_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
audio_monitor=$(pactl list short sources | grep monitor | head -1 | awk '{print $2}')

if [ -n "$audio_monitor" ]; then
  notify-send "Recording Started" "wf-recorder ($monitor + system audio)"
  wf-recorder -c libx264rgb --audio="$audio_monitor" -o "$monitor" --file="$filename"
else
  notify-send "Recording Video Only" "No system audio monitor detected"
  wf-recorder -c libx264rgb -o "$monitor" --file="$filename"
fi
