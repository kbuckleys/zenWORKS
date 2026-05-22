-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local function screenshot()
	local dir = os.getenv("HOME") .. "/Pictures/Screenshots"
	local script = [[
mkdir -p "]] .. dir .. [["

monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ -z "$monitor" ] && exit 1

file="]] .. dir .. [[/$(date +'%Y-%m-%d-%H%M%S')-$monitor.png"
grim -o "$monitor" "$file" && notify-send -i "$file" "Screenshot saved" "Saved to $file"
]]
	hl.exec_cmd("bash -c '" .. script:gsub("'", "'\"'\"'") .. "'")
end

-- BINDS
hl.bind("SUPER + SHIFT + CONTROL + P", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots/"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots/"))
hl.bind("SUPER + P", screenshot)
