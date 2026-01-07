# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

dir=~/Pictures/Screenshots
mkdir -p "$dir"
monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
file="$dir/$(date +%Y%m%d-%H%M%S)-$monitor.png"
grim -o "$monitor" "$file"
notify-send -i "$file" "Screenshot" "Saved to $file"
