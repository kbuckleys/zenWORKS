# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

ROFI_THEME="$HOME/.config/rofi/dictionary.rasi"
last_word=""

while true; do
  word=$(rofi -dmenu -theme "$ROFI_THEME" -p "Enter word:")
  [[ -z "$word" || "$word" == "$last_word" ]] && break

  response=$(curl -s "https://api.dictionaryapi.dev/api/v2/entries/en/$word")

  definition=$(echo "$response" | jq -r '
    if type=="array" and (length > 0) then
      if (.[0].meanings and .[0].meanings[0].definitions and .[0].meanings[0].definitions[0].definition) then
        .[0].meanings[0].definitions[0].definition
      else
        "No matches found"
      end
    else
      "No matches found"
    end
  ')

  last_word="$word"
  echo "$word: $definition" | rofi -dmenu -theme "$ROFI_THEME" -p "Definition" -no-sort
done
