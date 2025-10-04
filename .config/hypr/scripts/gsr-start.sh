# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

notify-send "Recording Started" "GPU Screen Recorder"
gpu-screen-recorder -w screen -s 1920x1080 -f 60 -c mp4 -o ~/Videos/Captures/capture_$(date +%Y-%m-%d_%H-%M-%S).mp4
