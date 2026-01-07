# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

ROFI_THEME_INPUT="$HOME/.config/rofi/dictionary.rasi"
ROFI_THEME_RESULTS="$HOME/.config/rofi/dictionary-output.rasi"
last_word=""
max_line_length=100

while true; do
  word=$(rofi -dmenu -wayland-layer top -theme "$ROFI_THEME_INPUT")
  [[ -z "$word" || "$word" == "$last_word" ]] && break

  response=$(curl -s "https://api.dictionaryapi.dev/api/v2/entries/en/$word")

  definition=$(echo "$response" | jq -r --arg color "#e0aea4" '
  if type=="array" and (length > 0) then
    if (.[0].meanings and .[0].meanings[0].definitions and .[0].meanings[0].definitions[0].definition) then
      .[0].meanings[0].definitions[0].definition
    else
      "<span foreground=\"" + $color + "\">No match found</span>"
    end
  else
    "<span foreground=\"" + $color + "\">No match found</span>"
  end
')

  last_word="$word"
  combined="<b>$word</b>: $definition"

  wrapped_lines=$(echo "$combined" | fmt -w $max_line_length)

  printf '%s\n' "$wrapped_lines" | rofi \
    -dmenu -wayland-layer top \
    -theme "$ROFI_THEME_RESULTS" \
    -no-sort \
    -lines 6 \
    -p "Definition" \
    -markup-rows
done
