# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

ICON_INSTALL=""
ICON_REMOVE=""

paru -Scc --noconfirm && paru --clean && rm -rf ~/.cache/paru/ && paru -Sy

hard_clear

while true; do
  mapfile -t available_pkgs < <(paru -Slq)
  mapfile -t installed_pkgs_arr < <(paru -Qq)

  declare -A installed_pkgs=()
  for pkg in "${installed_pkgs_arr[@]}"; do
    installed_pkgs["$pkg"]=1
  done

  combined=()
  
  for pkg in "${available_pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue
    if [[ -z ${installed_pkgs["$pkg"]} ]]; then
      combined+=("$ICON_INSTALL $pkg")
    fi
  done
  
  for pkg in "${installed_pkgs_arr[@]}"; do
    combined+=("$ICON_REMOVE $pkg")
  done

  preview_func() {
    local prefix=$1
    local pkg=$2

    if [[ "$prefix" == "$ICON_INSTALL" ]]; then
      paru -Si "$pkg"
    else
      paru -Qi "$pkg"
    fi
  }
  export -f preview_func
  export ICON_INSTALL ICON_REMOVE

selected=$(
  printf '%s\n' "${combined[@]}" | fzf --multi \
    --border=top \
    --header-border=line \
    --bind 'ctrl-a:toggle-all,ctrl-d:clear-multi' \
    --header="TAB: Select  󰇙  C-a: Invert  󰇙  C-d: Clear  󰇙  RETURN: Confirm" \
    --prompt="  > " \
    --preview='bash -c '\''line="$1"; prefix="${line%% *}"; pkg="${line#* }"; preview_func "$prefix" "$pkg"'\'' -- {}' \
    --preview-window="bottom:50%"
)   

  [[ -z $selected ]] && break

  to_install=()
  to_uninstall=()

  while IFS= read -r line; do
    action_icon=${line%% *}
    pkg=${line#* }
    
    if [[ "$action_icon" == "$ICON_INSTALL" ]]; then
      to_install+=("$pkg")
    elif [[ "$action_icon" == "$ICON_REMOVE" ]]; then
      to_uninstall+=("$pkg")
    fi
  done <<<"$selected"

  if [[ ${#to_install[@]} -gt 0 ]]; then
    paru -S "${to_install[@]}"
  fi

  if [[ ${#to_uninstall[@]} -gt 0 ]]; then
    paru -Rs --noconfirm "${to_uninstall[@]}"
  fi

  if [[ ${#to_install[@]} -gt 0 || ${#to_uninstall[@]} -gt 0 ]]; then
    echo "Cleaning paru cache..."
    paru --clean
    echo ""
    echo $'\033[1;32mPress RETURN to continue\033[0m'
    read -r
    hard_clear
  fi
  
  unset installed_pkgs
done   
