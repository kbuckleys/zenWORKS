# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

output_dir="$HOME/Videos/Captures"

if [ ! -d "$output_dir" ]; then
  mkdir -p "$output_dir"
fi

notify-send "Recording Started" "wf-recorder"
wf-recorder --file="$output_dir/recording_$(date +'%Y-%m-%d_%H-%M-%S').mp4"
