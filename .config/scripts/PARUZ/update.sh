# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

refresh_updates() {
  paru -Scc --noconfirm && paru --clean && rm -rf ~/.cache/paru/ && paru -Sy
  mapfile -t updates < <(paru -Qu --color=never | sort -u)
  
  hard_clear

  all_updates=()
  old_versions=()
  new_versions=()

  for line in "${updates[@]}"; do
    pkg=$(echo "$line" | awk '{print $1}')
    old_ver=$(echo "$line" | awk '{print $2}')
    new_ver=$(echo "$line" | awk -F ' -> ' '{print $2}')
    all_updates+=("$pkg")
    old_versions+=("$old_ver")
    new_versions+=("$new_ver")
  done

  if [ ${#all_updates[@]} -eq 0 ]; then
    echo "No updates available."
    paru --clean
    return
  fi

  selection_list=()
  for line in "${updates[@]}"; do
    pkg=$(echo "$line" | awk '{print $1}')
    old_ver=$(echo "$line" | awk '{print $2}')
    new_ver=$(echo "$line" | awk -F ' -> ' '{print $2}')

    pkg_display=$(printf '%.45s' "$pkg")
    old_ver_display=$(printf '%.20s' "$old_ver")
    new_ver_display=$(printf '%.20s' "$new_ver")

    selection_list+=("$(printf '%-45s %20s          %20s' "$pkg_display" "$old_ver_display" "$new_ver_display")")
  done

selected_lines=$(printf '%s\n' "${selection_list[@]}" | fzf --multi \
      --no-input \
      --border=top \
      --header-border=line \
      --bind 'ctrl-a:toggle-all,ctrl-d:clear-multi' \
      --header="TAB: Select  󰇙  C-a: Invert  󰇙  C-d: Clear  󰇙  RETURN: Confirm" \
      --delimiter ' ' \
      --preview="paru -Si {1}" \
      --preview-window="bottom:50%")

  echo ""
  if [ -n "$selected_lines" ]; then
    selected=()
    while IFS= read -r line; do
      pkg=$(echo "$line" | awk '{print $1}')
      selected+=("$pkg")
    done <<< "$selected_lines"

    if [ ${#selected[@]} -gt 0 ]; then
      echo "Installing selected packages: ${selected[*]}"
      paru -S --noconfirm "${selected[@]}"
      updated=true
    else
      echo "No packages selected."
    fi
  else
    echo "No selection made."
  fi

  echo "Cleaning paru cache..."
  paru --clean
}

while true; do
  clear
  cat ~/.config/logo
  echo ""
  refresh_updates
  updated=false

  read -n1 -r choice

  case "$choice" in
  $'\e')
    echo ""
    MENU="$HOME/.config/scripts/PARUZ/PARUZ.sh"
    
    if [ -f "$MENU" ]; then
      exec "$MENU"
    else
      break
    fi
    ;;
  $'\n' | $'\r' | "")
    continue
    ;;
  *) 
    continue
    ;;
  esac
done   
