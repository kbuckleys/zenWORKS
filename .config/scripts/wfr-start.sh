# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

output_dir="$HOME/Videos/Captures"
mkdir -p "$output_dir"
rofi_theme="$HOME/.config/rofi/wfr-monitors.rasi"

monitors=$(hyprctl monitors -j | jq -r '.[].name')

monitor=$(echo "$monitors" | rofi -dmenu -theme "$rofi_theme" -p "Select monitor:")
[ -z "$monitor" ] && {
  notify-send "Cancelled" "No monitor selected"
  exit 1
}

filename="$output_dir/capture_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
notify-send "Recording Started" "wf-recorder ($monitor)"
wf-recorder -a -o "$monitor" --file="$filename"
