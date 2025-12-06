# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

cat ~/.config/logo
paru

while true; do
  mapfile -t available_pkgs < <(paru -Slq)
  mapfile -t installed_pkgs_arr < <(paru -Qq)

  declare -A installed_pkgs=()
  for pkg in "${installed_pkgs_arr[@]}"; do
    installed_pkgs["$pkg"]=1
  done

  combined=()
  for pkg in "${available_pkgs[@]}"; do
    if [[ -z ${installed_pkgs[$pkg]} ]]; then
      combined+=("I $pkg")
    fi
  done
  for pkg in "${installed_pkgs_arr[@]}"; do
    combined+=("U $pkg")
  done

  preview_func() {
    local prefix=$1
    local pkg=$2
    local cache_file="/tmp/paru_${prefix}_${pkg}.cache"

    if [[ ! -f $cache_file ]]; then
      if [[ $prefix == I ]]; then
        paru -Si "$pkg" >"$cache_file"
      else
        paru -Qi "$pkg" >"$cache_file"
      fi
    fi
    cat "$cache_file"
  }
  export -f preview_func

  selected=$(
    printf '%s\n' "${combined[@]}" | fzf --multi \
      --preview='bash -c '\''prefix="${1:0:1}"; pkg="${1:2}"; preview_func "$prefix" "$pkg"'\'' -- {}' \
      --preview-window=down:70%
  )

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

  if [[ ${#to_install[@]} -gt 0 ]]; then
    paru -S "${to_install[@]}"
  fi

  if [[ ${#to_uninstall[@]} -gt 0 ]]; then
    paru -Rs "${to_uninstall[@]}"
  fi

  if [[ ${#to_install[@]} -gt 0 || ${#to_uninstall[@]} -gt 0 ]]; then
    echo "Press Return to continue..."
    read -r
  fi
done
