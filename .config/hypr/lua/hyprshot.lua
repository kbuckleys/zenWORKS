-- ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
-- ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
-- └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
-- https://github.com/kbuckleys/

local function screen()
    local dir = os.getenv("HOME") .. "/Pictures/Screenshots"
    local script = [[
mkdir -p "]] .. dir .. [["
monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
file="]] .. dir .. [[/$(date +'%Y-%m-%d-%H%M%S')-$monitor.png"
grim -o "$monitor" "$file" && convert "$file" -background black -flatten "$file" && wl-copy < "$file" && notify-send -i "$file" "Screenshot saved" "Saved to $file and copied to clipboard"
]]
    hl.exec_cmd("bash -c '" .. script:gsub("'", "'\"'\"'") .. "'")
end

local function region()
    local dir = os.getenv("HOME") .. "/Pictures/Screenshots"
    local script = [[
mkdir -p "]] .. dir .. [["
file="]] .. dir .. [[/$(date +'%Y-%m-%d-%H%M%S')_region.png"
grim -g "$(slurp -d)" "$file" && wl-copy < "$file" && notify-send -i "$file" "Screenshot saved" "Saved to $file and copied to clipboard"
]]
    hl.exec_cmd("bash -c '" .. script:gsub("'", "'\"'\"'") .. "'")
end

local function window()
    local dir = os.getenv("HOME") .. "/Pictures/Screenshots"
    local script = [[
mkdir -p "]] .. dir .. [["
file="]] .. dir .. [[/$(date +'%Y-%m-%d-%H%M%S')_window.png"
geometry=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
grim -g "$geometry" "$file" && wl-copy < "$file" && notify-send -i "$file" "Screenshot saved" "Saved to $file and copied to clipboard"
]]
    hl.exec_cmd("bash -c '" .. script:gsub("'", "'\"'\"'") .. "'")
end

-- BINDS
hl.bind("SUPER + SHIFT + PRINT", region)
hl.bind("SUPER + PRINT", window)
hl.bind("PRINT", screen)
