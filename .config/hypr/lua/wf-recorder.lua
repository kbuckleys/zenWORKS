-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local function record(mode)
	local output_dir = os.getenv("HOME") .. "/Videos/Captures"
	local script = [[
mkdir -p "]] .. output_dir .. [["

if pgrep -x "wf-recorder" >/dev/null; then
  pkill -SIGINT wf-recorder
  notify-send " Recording Stopped"
  exit 0
fi

monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ -z "$monitor" ] && { notify-send "󱠑 No monitor"; exit 1; }

filename="]] .. output_dir .. [[/$(date +'%Y-%m-%d-%H%M%S')-$monitor.mp4"   
audio=$(pactl list sources | grep -m1 'Name:.*monitor' | awk '{print $2}')

case "]] .. mode .. [[" in
  "full")
    notify-send "󰑋 Full Screen" "$monitor"
    wf-recorder -c h264_nvenc -p preset=lossless -p rgb_mode=yuv444 -p qp=0 --audio="$audio" -o "$monitor" -f "$filename" &
    ;;
  "region")
    geometry=$(slurp)
    [ -n "$geometry" ] && notify-send " Region Selected" && wf-recorder -c h264_nvenc -p preset=lossless -p rgb_mode=yuv444 -p qp=0 --audio="$audio" -g "$geometry" -f "$filename" &
    ;;
  "window")
    win_info=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    [ "$win_info" = "null" ] && { notify-send " No window"; exit 1; }
    notify-send " Window Recording"
    wf-recorder -c h264_nvenc -p preset=lossless -p rgb_mode=yuv444 -p qp=0 --audio="$audio" -g "$win_info" -f "$filename" &
    ;;
esac
]]
	hl.exec_cmd("bash -c '" .. script:gsub("'", "'\"'\"'") .. "'")
end

-- BINDS
hl.bind("SUPER + R", function() record("full") end)
hl.bind("SUPER + SHIFT + R", function() record("window") end)
hl.bind("SUPER + CONTROL + R", function() record("region") end)
