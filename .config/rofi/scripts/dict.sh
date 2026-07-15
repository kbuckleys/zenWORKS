#!/bin/bash
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set -uo pipefail

ROFI_THEME_INPUT="$HOME/.config/rofi/dictionary.rasi"
ROFI_THEME_RESULTS="$HOME/.config/rofi/dictionary-output.rasi"
max_line_length=80
max_defs_per_pos=2
max_lines=20

COLOR_HEAD="#9bbfbf"
COLOR_PHON="#9bbfbf"
COLOR_POS="#6a707f"
COLOR_EX="#eebebe"
COLOR_SYN="#b6e0a4"
COLOR_ERROR="#e78284"

# looks up a term on Wiktionary's structured definition endpoint
lookup() {
  local encoded
  encoded=$(jq -rn --arg w "$1" '$w|@uri')
  curl -s --max-time 5 "https://en.wiktionary.org/api/rest_v1/page/definition/$encoded"
}

has_entries() { jq -e '(.en? // []) | length > 0' >/dev/null 2>&1 <<< "$1"; }

# --debug <word>: one-shot lookup, prints raw API data + what the script
# extracted from it. No rofi needed — run this straight in a terminal.
if [[ "${1-}" == "--debug" ]]; then
  word="${2-}"
  [[ -z "$word" ]] && { echo "usage: $0 --debug <word>" >&2; exit 1; }
  encoded=$(jq -rn --arg w "$word" '$w|@uri')

  echo "### Wiktionary: $word ###"
  def_response=$(lookup "$word")
  jq . <<< "$def_response" 2>/dev/null || echo "$def_response"

  if ! has_entries "$def_response"; then
    hyphenated="${word// /-}"
    if [[ "$hyphenated" != "$word" ]]; then
      echo "### not found as typed — trying: $hyphenated ###"
      alt=$(lookup "$hyphenated")
      jq . <<< "$alt" 2>/dev/null || echo "$alt"
      has_entries "$alt" && def_response="$alt"
    fi
  fi

  echo "### dictionaryapi.dev (pronunciation source): $word ###"
  phon_response=$(curl -s --max-time 5 "https://api.dictionaryapi.dev/api/v2/entries/en/$encoded")
  jq . <<< "$phon_response" 2>/dev/null || echo "$phon_response"

  echo "### extracted phonetic string (raw bytes via od) ###"
  phonetic=$(jq -r '
    if type=="array" and length>0 then
      (.[0].phonetic // ([.[0].phonetics[]?.text // empty] | first) // "")
    else "" end
  ' 2>/dev/null <<< "$phon_response")
  echo "phonetic: $phonetic"
  printf '%s' "$phonetic" | od -c | head -5

  echo "### computed tab-separated rows ###"
  jq -r --arg WORD "$word" --argjson maxdefs "$max_defs_per_pos" '
    def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
    def striphtml: gsub("<[^>]*>"; "")
      | gsub("&nbsp;"; " ") | gsub("&amp;"; "\u0026") | gsub("&lt;"; "<") | gsub("&gt;"; ">")
      | gsub("&quot;"; "\"") | gsub("&#39;|&apos;"; "'"'"'")
      | gsub("^\\s+|\\s+$"; "");
    def has_content: test("[[:alnum:]]");
    if (.en? // []) | length > 0 then
      ["head\t" + ($WORD|esc)]
      + ( .en | map(
            ( (.definitions // [])[0:$maxdefs]
              | map({ def: ((.definition // "")|striphtml),
                       ex: (((.examples // [])[0] // "")|striphtml) })
              | map(select(.def|has_content))
            ) as $defs
            | if ($defs|length) > 0 then
                ["pos\t" + (.partOfSpeech|esc)]
                + ( $defs | map(
                      ["def\t" + (.def|esc)]
                      + (if (.ex|has_content) then ["ex\t" + (.ex|esc)] else [] end)
                    ) | add // [] )
              else empty end
          ) | add // [] )
      | .[]
    else
      "error\tNo definitions found for \"" + $WORD + "\". Check spelling?"
    end
  ' <<< "$def_response" | cat -A

  exit 0
fi

while true; do
  word=$(rofi -dmenu -wayland-layer top -theme "$ROFI_THEME_INPUT" -p "Define")
  [[ -z "$word" ]] && break

  # definitions, synonyms, and pronunciation all fetched concurrently
  encoded=$(jq -rn --arg w "$word" '$w|@uri')
  tmp_syn=$(mktemp) tmp_phon=$(mktemp)
  curl -s --max-time 5 "https://api.datamuse.com/words?rel_syn=$encoded&max=6" > "$tmp_syn" &
  syn_pid=$!
  curl -s --max-time 5 "https://api.dictionaryapi.dev/api/v2/entries/en/$encoded" > "$tmp_phon" &
  phon_pid=$!

  def_response=$(lookup "$word")

  wait "$syn_pid" "$phon_pid"
  syn_response=$(<"$tmp_syn")
  phon_response=$(<"$tmp_phon")
  rm -f "$tmp_syn" "$tmp_phon"

  if [[ -z "$def_response" ]]; then
    printf '%s\n' "<span foreground=\"$COLOR_ERROR\">Network error — couldn't reach the dictionary API</span>" \
      | rofi -dmenu -wayland-layer top -theme "$ROFI_THEME_RESULTS" -no-sort -lines 1 -p "Definition" -markup-rows
    continue
  fi

  # "fixer upper" -> retry as "fixer-upper" if not found as typed
  if ! has_entries "$def_response"; then
    hyphenated="${word// /-}"
    if [[ "$hyphenated" != "$word" ]]; then
      alt=$(lookup "$hyphenated")
      has_entries "$alt" && def_response="$alt"
    fi
  fi

  phonetic=""
  [[ -n "$phon_response" ]] && phonetic=$(jq -r '
    def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
    if type=="array" and length>0 then
      ((.[0].phonetic // ([.[0].phonetics[]?.text // empty] | first) // "")|esc)
    else "" end
  ' 2>/dev/null <<< "$phon_response")

  # tab-separated "type<TAB>content" rows for bash to format & wrap
  rows=$(jq -r --arg WORD "$word" --argjson maxdefs "$max_defs_per_pos" '
    def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
    def striphtml: gsub("<[^>]*>"; "")
      | gsub("&nbsp;"; " ") | gsub("&amp;"; "\u0026") | gsub("&lt;"; "<") | gsub("&gt;"; ">")
      | gsub("&quot;"; "\"") | gsub("&#39;|&apos;"; "'"'"'")
      | gsub("^\\s+|\\s+$"; "");
    # length>0 alone is fooled by definitions that strip down to only
    # invisible whitespace (nbsp, zero-width chars); require a real letter/digit
    def has_content: test("[[:alnum:]]");
    if (.en? // []) | length > 0 then
      ["head\t" + ($WORD|esc)]
      + ( .en | map(
            ( (.definitions // [])[0:$maxdefs]
              | map({ def: ((.definition // "")|striphtml),
                       ex: (((.examples // [])[0] // "")|striphtml) })
              | map(select(.def|has_content))
            ) as $defs
            | if ($defs|length) > 0 then
                ["pos\t" + (.partOfSpeech|esc)]
                + ( $defs | map(
                      ["def\t" + (.def|esc)]
                      + (if (.ex|has_content) then ["ex\t" + (.ex|esc)] else [] end)
                    ) | add // [] )
              else empty end
          ) | add // [] )
      | .[]
    else
      "error\tNo definitions found for \"" + $WORD + "\". Check spelling?"
    end
  ' <<< "$def_response")

  synonyms=""
  [[ -n "$syn_response" ]] && synonyms=$(jq -r '[.[]?.word] | join(", ")' 2>/dev/null <<< "$syn_response")

  lines=()
  add_blank() { [[ ${#lines[@]} -gt 0 && -n "${lines[-1]}" ]] && lines+=(""); }

  # a "pos" row only becomes permanent once def/ex content follows it;
  # if the next thing we see is another pos row (or the list just ends),
  # this drops the empty header instead of leaving it dangling
  pending_pos_idx=-1
  drop_empty_pos() {
    if (( pending_pos_idx >= 0 )); then
      unset "lines[$pending_pos_idx]"
      lines=("${lines[@]}")
      if (( pending_pos_idx > 0 )) && [[ -z "${lines[$((pending_pos_idx - 1))]-}" ]]; then
        unset "lines[$((pending_pos_idx - 1))]"
        lines=("${lines[@]}")
      fi
      pending_pos_idx=-1
    fi
  }

  while IFS=$'\t' read -r type a; do
    case "$type" in
      head)
        # no size="large" here: a bumped-up font on the header row was
        # overflowing the theme's row height and clipping descenders (y, g, p)
        headline="<b><span foreground=\"$COLOR_HEAD\">$a</span></b>"
        [[ -n "$phonetic" ]] && headline="$headline  <span foreground=\"$COLOR_PHON\">$phonetic</span>"
        lines+=("$headline")
        ;;
      pos)
        drop_empty_pos
        add_blank
        lines+=("<span foreground=\"$COLOR_POS\"><i>$a</i></span>")
        pending_pos_idx=$(( ${#lines[@]} - 1 ))
        ;;
      def)
        [[ "$a" =~ [[:alnum:]] ]] || continue
        pending_pos_idx=-1
        while IFS= read -r wline; do
          lines+=("  $wline")
        done < <(fmt -w "$max_line_length" <<< "$a")
        ;;
      ex)
        [[ "$a" =~ [[:alnum:]] ]] || continue
        pending_pos_idx=-1
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
  drop_empty_pos

  if [[ -n "$synonyms" ]]; then
    add_blank
    lines+=("<span foreground=\"$COLOR_SYN\"><b>Synonyms:</b> $synonyms</span>")
  fi

  # drop any trailing blank rows (e.g. left by the last example's spacer)
  while [[ ${#lines[@]} -gt 0 && -z "${lines[-1]}" ]]; do
    lines=("${lines[@]:0:$(( ${#lines[@]} - 1 ))}")
  done

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
