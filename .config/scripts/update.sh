# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

cat ~/.config/logo
paru -Sy

echo "Fetching updates..."
all_updates=$(paru -Qu --color=never | awk '{print $1}' | sort -u)

all_updates=($(printf '%s\n' "${pacman_updates[@]}" "${aur_updates[@]}" | sort -u))

if [ ${#all_updates[@]} -eq 0 ]; then
  echo "No updates available."
  read -p "Press RETURN to exit..."
  exit 0
fi

echo ""
echo "Available updates (${#all_updates[@]} total):"
printf '%s\n' "${all_updates[@]}" | nl -w2 -s': '

echo ""
echo "Press RETURN to install ALL updates,"
echo "or enter space-separated numbers (e.g. 1 2 3)"
echo -n ":: "

read -r input

if [ -z "$input" ]; then
  echo "Installing all updates..."
  paru -Syu
elif [[ "$input" =~ ^[0-9]+([[:space:]]+[0-9]+)*$ ]]; then
  selected=()
  IFS=' ' read -ra nums <<<"$input"
  for num in "${nums[@]}"; do
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#all_updates[@]} ]; then
      pkg="${all_updates[$((num - 1))]}"
      selected+=("$pkg")
      echo "Selected: $pkg"
    else
      echo "Invalid number: $num"
    fi
  done

  if [ ${#selected[@]} -gt 0 ]; then
    echo "Installing selected packages: ${selected[*]}"
    paru -S "${selected[@]}"
  else
    echo "No valid packages selected."
  fi
else
  echo "Invalid input. Use RETURN for all, or numbers like '1 2 3'"
  read -p "Press RETURN to exit..."
  exit 0
fi

echo ""
read -p "Press RETURN to exit..."
