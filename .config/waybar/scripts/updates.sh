#!/bin/bash
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set -u

ICON=" "
OFFICIAL_ICON="󰣇"
AUR_ICON=""
MAX_ENTRIES=10

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
CACHE_FILE="$CACHE_DIR/updates.list"

mkdir -p "$CACHE_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

json_escape() {
    sed -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e ':a;N;$!ba;s/\n/\\n/g'
}

official_updates="$(paru -Qu 2>/dev/null || true)"
aur_updates="$(paru -Qua 2>/dev/null || true)"

official_count=0
aur_count=0

[[ -n "$official_updates" ]] && official_count=$(printf '%s\n' "$official_updates" | grep -c '.')
[[ -n "$aur_updates" ]] && aur_count=$(printf '%s\n' "$aur_updates" | grep -c '.')

total=$((official_count + aur_count))

merged=""
[[ -n "$official_updates" ]] && merged+="$official_updates"$'\n'
[[ -n "$aur_updates" ]] && merged+="$aur_updates"

if [[ $total -eq 0 ]]; then
    rm -f "$CACHE_FILE"
    printf '{"text":"","tooltip":"System is up to date","class":"none"}\n'
    exit 0
fi

if [[ ! -f "$CACHE_FILE" ]] || ! cmp -s <(printf '%s' "$merged") "$CACHE_FILE"; then
    printf '%s' "$merged" >"$CACHE_FILE"

    if have notify-send; then
        body="Official: $official_count\nAUR: $aur_count"
        shown=0
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            pkg="${line%% *}"
            body+="\n• $pkg"
            shown=$((shown+1))
            [[ $shown -ge 10 ]] && break
        done <<<"$merged"

        [[ $total -gt 10 ]] && body+="\n..."
        notify-send "󰚰 Package Updates Available" "$body"
    fi
fi

tooltip=""

if (( official_count > 0 )); then
    tooltip+="${OFFICIAL_ICON} ${official_count}\n"
    shown=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        tooltip+="$line\n"
        shown=$((shown+1))
        [[ $shown -ge $MAX_ENTRIES ]] && break
    done <<<"$official_updates"
    [[ $official_count -gt $MAX_ENTRIES ]] && tooltip+="...\n"
    (( aur_count > 0 )) && tooltip+="\n"
fi

if (( aur_count > 0 )); then
    tooltip+="${AUR_ICON} ${aur_count}\n"
    shown=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        tooltip+="$line\n"
        shown=$((shown+1))
        [[ $shown -ge $MAX_ENTRIES ]] && break
    done <<<"$aur_updates"
    [[ $aur_count -gt $MAX_ENTRIES ]] && tooltip+="..."
fi

tooltip=$(printf '%b' "$tooltip" | json_escape)

printf '{"text":"%s %d","tooltip":"%s","class":"updates"}\n' \
    "$ICON" "$total" "$tooltip"
