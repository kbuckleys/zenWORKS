# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/
# Original idea by https://www.reddit.com/user/MochironNoob/

#!/bin/bash

toggle=0
hyprctl keyword animation "workspacesOut, 1, 4, default, slidevertfade top"
hyprctl keyword animation "workspacesIn, 1, 4, default, slidevertfade bottom"
if [[ $(hyprctl activeworkspace -j | jq '.id') -eq 9 ]]; then toggle=1; fi
hyprctl dispatch workspace 9
[[ "$toggle" -eq 1 ]] || hyprctl dispatch togglespecialworkspace magic
echo $toggle
hyprctl keyword animation "workspacesOut, 1, 2, default, slidefade 15%"
hyprctl keyword animation "workspacesIn, 1, 2, default, slidefade 15%"
