# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

cat ~/.config/logo
echo ""
paru -Sy

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
  echo ""
  read -p $'\033[1;32mPress RETURN to exit...\033[0m'
  exit 0
fi

echo ""
printf "\033[1;38;5;216mAvailable updates (%d):\033[0m\n" ${#all_updates[@]}
echo ""
for i in "${!all_updates[@]}"; do
  printf "%-4d %-25s \033[1;33m%-15s\033[0m \033[1;32m%-15s\033[0m\n" \
    $((i + 1)) "${all_updates[$i]}" "${old_versions[$i]}" "${new_versions[$i]}"
done

echo ""
printf "\033[1;36mInput space-separated numbers/ranges (e.g. 1 2 3 OR 1-3 OR 1 3-4)\n"
printf "Alternatively, press RETURN to sync all available updates\n"
printf ":: \033[0m"

read -r input
updated=false

if [ -z "$input" ]; then
  echo "Installing all updates..."
  paru -Syu
  updated=true
else
  selected=()

  # Split input into tokens (numbers or ranges)
  IFS=' ' read -ra tokens <<<"$input"

  for token in "${tokens[@]}"; do
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      # Range: 1-4
      start=${BASH_REMATCH[1]}
      end=${BASH_REMATCH[2]}
      if [ "$start" -ge 1 ] && [ "$end" -le ${#all_updates[@]} ] && [ "$start" -le "$end" ]; then
        for ((i = start; i <= end; i++)); do
          idx=$((i - 1))
          selected+=("${all_updates[$idx]}")
          echo "Selected (range): ${all_updates[$idx]}"
        done
      else
        echo "Invalid range: $token (out of 1-${#all_updates[@]} range)"
      fi
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      # Single number: 2
      num=$token
      if [ "$num" -ge 1 ] && [ "$num" -le ${#all_updates[@]} ]; then
        selected+=("${all_updates[$((num - 1))]}")
        echo "Selected: ${all_updates[$((num - 1))]}"
      else
        echo "Invalid number: $num"
      fi
    else
      echo "Invalid token: $token"
    fi
  done

  if [ ${#selected[@]} -gt 0 ]; then
    echo "Installing selected packages: ${selected[*]}"
    paru -S "${selected[@]}"
    updated=true
  else
    echo "No valid packages selected."
  fi
fi

echo "Cleaning paru cache..."
paru --clean

echo ""
if [ "$updated" = true ]; then
  read -p $'\033[1;32mPress RETURN to continue...\033[0m'
else
  read -p $'\033[1;32mPress RETURN to exit...\033[0m'
fi
