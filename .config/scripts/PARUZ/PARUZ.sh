# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

SCRIPT_UPDATE="$HOME/.config/scripts//PARUZ/update.sh"
SCRIPT_PARUZ="$HOME/.config/scripts/PARUZ/pm.sh"

show_logo() {
    if [ -f ~/.config/logo ]; then
        cat ~/.config/logo
        echo ""
    fi
}

hard_clear() {
    printf "\033c"
    stty sane 2>/dev/null
}

show_logo
if ! sudo -v 2>/dev/null; then
    if ! sudo -v; then echo "Auth failed."; exit 1; fi
fi
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_PID=$!
trap "kill $SUDO_PID" EXIT

hard_clear

while true; do
    show_logo

    options=("Update Packages" "Add/Remove Packages" "Exit")
    
    choice=$(printf '%s\n' "${options[@]}" | fzf \
        --disabled \
        --no-input \
        --layout=reverse-list \
        --height=40%)

    case "$choice" in
        "Update Packages")
            if [ -f "$SCRIPT_UPDATE" ]; then
                source "$SCRIPT_UPDATE"
            else
                echo "Error: $SCRIPT_UPDATE not found!"
            fi
            hard_clear
            ;;
        "Add/Remove Packages")
            if [ -f "$SCRIPT_PARUZ" ]; then
                source "$SCRIPT_PARUZ"
            else
                echo "Error: $SCRIPT_PARUZ not found!"
            fi
            hard_clear
            ;;
        "Exit"|"")
            echo "Exiting."
            exit 0
            ;;
    esac
done
