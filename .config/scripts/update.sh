# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

#!/bin/bash

cat ~/.config/logo
echo ""

refresh_updates() {
  paru -Scc --noconfirm && paru --clean && rm -rf ~/.cache/paru/ && paru -Sy

  echo "Fetching updates..."
  mapfile -t updates < <(paru -Qu --color=never | sort -u)

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

  # Build selection list with version info
  selection_list=()
  for i in "${!all_updates[@]}"; do
    selection_list+=("${all_updates[$i]}  ${old_versions[$i]} -> ${new_versions[$i]}")
  done

  selected_lines=$(printf '%s\n' "${selection_list[@]}" | \
    fzf --multi \
        --reverse \
        --border=sharp \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all' \
        --header="TAB: Flah  󰇙  C-a: All  󰇙  C-d: None  󰇙  RETURN: Confirm" \
        --prompt=" " \
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

  echo ""
  printf "\\033[1;32mPress RETURN to refresh or ESC to exit...\\033[0m\\n"
  echo -n " "

  read -n1 -r choice

  case "$choice" in
  $'\e')
    echo ""
    exit 0
    ;;
  $'\n' | $'\r' | "")
    continue
    ;;
  *) ;;
  esac
done   
