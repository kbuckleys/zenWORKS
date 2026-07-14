#!/bin/bash
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

ROFI_THEME_INPUT="$HOME/.config/rofi/dictionary.rasi"
ROFI_THEME_RESULTS="$HOME/.config/rofi/dictionary-output.rasi"
max_line_length=80
max_defs_per_pos=2   # how many definitions to show per part of speech
max_lines=20         # cap so rofi doesn't grow unbound

COLOR_HEAD="#9bbfbf"
COLOR_PHON="#9bbfbf"
COLOR_POS="#6a707f"
COLOR_EX="#eebebe"
COLOR_SYN="#b6e0a4"
COLOR_ERROR="#e78284"

last_word=""

while true; do
  word=$(rofi -dmenu -wayland-layer top -theme "$ROFI_THEME_INPUT" -p "Define")
  [[ -z "$word" || "$word" == "$last_word" ]] && break
  last_word="$word"

  def_response=$(curl -s --max-time 5 "https://api.dictionaryapi.dev/api/v2/entries/en/$word")
  syn_response=$(curl -s --max-time 5 "https://api.datamuse.com/words?rel_syn=$word&max=6")

  if [[ -z "$def_response" ]]; then
    printf '%s\n' "<span foreground=\"$COLOR_ERROR\">Network error — couldn't reach the dictionary API</span>" \
      | rofi -dmenu -wayland-layer top -theme "$ROFI_THEME_RESULTS" -no-sort -lines 1 -p "Definition" -markup-rows
    continue
  fi

  # Emit tab-separated "type<TAB>content" rows for bash to format & wrap.
  rows=$(echo "$def_response" | jq -r --arg WORD "$word" '
    def esc: gsub("&"; "\u0026amp;") | gsub("<"; "\u0026lt;") | gsub(">"; "\u0026gt;");
    if type=="array" and length>0 then
      .[0] as $e
      | ($e.word // $WORD) as $w
      | ( ($e.phonetic // "") as $p1
          | if ($p1|length)>0 then $p1
            else ( [ $e.phonetics[]?.text // empty ] | first // "" )
            end
        ) as $phon
      | ["head\t" + ($w|esc) + (if ($phon|length)>0 then "\t" + ($phon|esc) else "\t" end)]
        + ( [ $e.meanings[]? ] | map(
              ["pos\t" + (.partOfSpeech|esc)]
              + ( (.definitions // [])[0:'"$max_defs_per_pos"'] | map(
                    ["def\t" + (.definition|esc)]
                    + (if ((.example // "")|length) > 0 then ["ex\t" + (.example|esc)] else [] end)
                  ) | add // [] )
            ) | add // [] )
      | .[]
    else
      "error\tNo definitions found for \"" + $WORD + "\". Check spelling?"
    end
  ')

  synonyms=$(echo "$syn_response" | jq -r '[.[]?.word] | join(", ")' 2>/dev/null)

  lines=()

  while IFS=$'\t' read -r type a b; do
    case "$type" in
      head)
        headline="<b><span foreground=\"$COLOR_HEAD\" size=\"large\">$a</span></b>"
        [[ -n "$b" ]] && headline="$headline  <span foreground=\"$COLOR_PHON\">$b</span>"
        lines+=("$headline")
        ;;
      pos)
        [[ ${#lines[@]} -gt 0 && -n "${lines[-1]}" ]] && lines+=("")
        lines+=("<span foreground=\"$COLOR_POS\"><i>$a</i></span>")
        ;;
      def)
        while IFS= read -r wline; do
          lines+=("  $wline")
        done < <(fmt -w "$max_line_length" <<< "$a")
        ;;
      ex)
        while IFS= read -r wline; do
          lines+=("  <span foreground=\"$COLOR_EX\"><i>$wline</i></span>")
        done < <(fmt -w "$max_line_length" <<< "$a")
        lines+=("")
        ;;
      error)
        lines+=("<span foreground=\"$COLOR_ERROR\">$a</span>")
        ;;
    esac
  done <<< "$rows"

  if [[ -n "$synonyms" ]]; then
    lines+=("")
    lines+=("<span foreground=\"$COLOR_SYN\"><b>Synonyms:</b> $synonyms</span>")
  fi

  n_lines=${#lines[@]}
  [[ $n_lines -gt $max_lines ]] && n_lines=$max_lines
  [[ $n_lines -lt 1 ]] && n_lines=1

  printf '%s\n' "${lines[@]}" | rofi \
    -dmenu -wayland-layer top \
    -theme "$ROFI_THEME_RESULTS" \
    -no-sort \
    -lines "$n_lines" \
    -p "Definition" \
    -markup-rows
done
