# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

cat ~/.config/logo
paru -Sy

echo "Fetching updates..."
mapfile -t updates < <(paru -Qu --color=never | awk '{print $1 " " $2 " -> " $3}' | sort -u)

all_updates=()
versions=()

for line in "${updates[@]}"; do
  pkg=$(echo "$line" | awk '{print $1}')
  version_info=$(echo "$line" | cut -d' ' -f2-)
  all_updates+=("$pkg")
  versions+=("$version_info")
done

if [ ${#all_updates[@]} -eq 0 ]; then
  echo "No updates available."
  echo ""
  read -p "Press RETURN to exit..."
  exit 0
fi

echo ""
echo "Available updates (${#all_updates[@]} total):"
for i in "${!all_updates[@]}"; do
  printf "%2d: \033[0;31m%s\033[0m \033[1;32m%s\033[0m\n" \
    $((i + 1)) "${versions[$i]}" "${all_updates[$i]}"
done

echo ""
printf "\033[1;33mPress RETURN to install ALL updates,\n"
printf "or enter space-separated numbers (e.g. 1 2 3)\n"
printf ":: \033[0m"

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
