# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

output_dir="$HOME/Videos/Captures"
mkdir -p "$output_dir"
rofi_theme="$HOME/.config/rofi/wfr-monitors.rasi"

monitor_count=$(hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo 1)

if [ "$monitor_count" -eq 1 ]; then
  monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null)
  [ -z "$monitor" ] && monitor=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[0].name' 2>/dev/null)
  [ -z "$monitor" ] && {
    notify-send "No monitor detected"
    exit 1
  }
  notify-send "Recording" "$monitor (single monitor)"
else
  monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
  [ -z "$monitors" ] && {
    notify-send "No monitors detected"
    exit 1
  }
  monitor=$(echo "$monitors" | rofi -dmenu -theme "$rofi_theme" -p "Select monitor:")
  [ -z "$monitor" ] && {
    notify-send "Cancelled" "No monitor selected"
    exit 1
  }
fi

filename="$output_dir/capture_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
audio_monitor=$(pactl list short sources | grep monitor | head -1 | awk '{print $2}')

if [ -n "$audio_monitor" ]; then
  notify-send "Recording Started" "wf-recorder ($monitor + system audio)"
  wf-recorder -c libx264rgb --audio="$audio_monitor" -o "$monitor" --file="$filename"
else
  notify-send "Recording Video Only" "No system audio monitor detected"
  wf-recorder -c libx264rgb -o "$monitor" --file="$filename"
fi
