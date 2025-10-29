# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

yay -Sy

while true; do
  mapfile -t installs < <(yay -Slq)
  mapfile -t uninstalls < <(yay -Qq)

  declare -A installed_pkgs=()
  for pkg in "${uninstalls[@]}"; do
    installed_pkgs["$pkg"]=1
  done

  combined=()
  for pkg in "${installs[@]}"; do
    if [[ -z ${installed_pkgs[$pkg]} ]]; then
      combined+=("I $pkg")
    fi
  done
  for pkg in "${uninstalls[@]}"; do
    combined+=("U $pkg")
  done

  preview_func() {
    local prefix=$1
    local pkg=$2
    local cache_file="/tmp/yay_${prefix}_${pkg}.cache"
    if [[ ! -f $cache_file ]]; then
      if [[ $prefix == I ]]; then
        yay -Si "$pkg" >"$cache_file"
      else
        yay -Qi "$pkg" >"$cache_file"
      fi
    fi
    cat "$cache_file"
  }

  export -f preview_func

  selected=$(printf '%s\n' "${combined[@]}" | fzf --multi --preview 'prefix=$(echo {} | cut -c1); pkg=$(echo {} | cut -c3-); preview_func "$prefix" "$pkg"' --preview-window=down:70%)

  [[ -z $selected ]] && break

  to_install=()
  to_uninstall=()
  while IFS= read -r line; do
    action=${line:0:1}
    pkg=${line:2}
    if [[ $action == I ]]; then
      to_install+=("$pkg")
    else
      to_uninstall+=("$pkg")
    fi
  done <<<"$selected"

  [[ ${#to_install[@]} -gt 0 ]] && yay -S "${to_install[@]}"
  [[ ${#to_uninstall[@]} -gt 0 ]] && yay -Rs "${to_uninstall[@]}"

done
