# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

notify-send "Recording Started" "GPU Screen Recorder"
gpu-screen-recorder -w screen -f 60 -a "$(pactl get-default-sink).monitor" -a "$(pactl get-default-source)" -c mp4 -o ~/Videos/Captures/capture_$(date +%Y-%m-%d_%H-%M-%S).mp4
