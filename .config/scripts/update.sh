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

selected_lines=$(printf '%s\n' "${selection_list[@]}" | \
  fzf --multi \
      --border=top \
      --header-border=line \
      --bind 'ctrl-a:toggle-all,ctrl-d:clear-multi' \
      --header="TAB: Select  󰇙  C-a: Invert Selection  󰇙  C-d: Clear Selection  󰇙  RETURN: Confirm" \
      --prompt="  > " \
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
