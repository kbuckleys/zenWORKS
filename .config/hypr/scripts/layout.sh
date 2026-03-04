# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/usr/bin/env bash
STATE_FILE=".cache/hyprland_ws_layouts"

# Get active workspace
ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Read current layout for this workspace (default dwindle)
current_layout=$(grep "^$ws:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "dwindle")

# Layout Cycle
case "$current_layout" in
"master") new_layout="scrolling" ;;
"scrolling") new_layout="dwindle" ;;
"dwindle") new_layout="master" ;;
*) new_layout="dwindle" ;;
esac

# Apply to active workspace only
hyprctl keyword "workspace $ws,layout:$new_layout"

# Update state file
mkdir -p "$(dirname "$STATE_FILE")"
echo "$ws:$new_layout" >"$STATE_FILE"
