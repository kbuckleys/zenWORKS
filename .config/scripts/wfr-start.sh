# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

output_dir="$HOME/Videos/Captures"

if [ ! -d "$output_dir" ]; then
  mkdir -p "$output_dir"
fi

notify-send "Recording Started" "wf-recorder"
wf-recorder -a --file="$output_dir/capture_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
