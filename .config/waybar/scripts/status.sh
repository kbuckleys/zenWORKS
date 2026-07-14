#!/bin/bash
# ┌─┐┌─┐┌┐┌┬ ┬┌─┐┬─┐┬┌─┌─┐
# ┌─┘├┤ │││││││ │├┬┘├┴┐└─┐
# └─┘└─┘┘└┘└┴┘└─┘┴└─┴ ┴└─┘
# https://github.com/kbuckleys/

set -euo pipefail

# Configuration
declare -Ar ICON=(
    [mic]=""
    [cam]=""
    [loc]=""
    [scr]=""
    [rec]=""
)

declare -Ar COLOR=(
    [mic]="#b6e0a4"
    [cam]="#fab387"
    [loc]="#9bbfbf"
    [scr]="#c8a4e0"
    [rec]="#e78284"
)

declare -Ar LABEL=(
    [mic]="Mic"
    [cam]="Cam"
    [loc]="Location"
    [scr]="Screen sharing"
    [rec]="Recording"
)

declare -A STATE APP

# Helpers
have() { command -v "$1" >/dev/null 2>&1; }

append_app() {
    [[ -z ${2:-} ]] && return
    APP[$1]=${APP[$1]:+"${APP[$1]}, "}$2
}

detect_process() {
    local proc=$1
    local key=$2

    have pgrep || return

    local pids

    pids=$(pgrep -x "$proc" 2>/dev/null || true)

    [[ -z $pids ]] && return

    STATE[$key]=1

    while read -r pid; do
        append_app "$key" "$(ps -p "$pid" -o comm=)"
    done <<< "$pids"
}

# PipeWire
if have pw-dump && have jq; then

    dump=$(pw-dump 2>/dev/null)

    # microphone
    if jq -e '
        any(.[];
            .type=="PipeWire:Interface:Node"
            and (
                .info.props."media.class"=="Audio/Source"
                or
                .info.props."media.class"=="Audio/Source/Virtual"
            )
            and (
                .info.state=="running"
                or
                .state=="running"
            )
        )
    ' <<<"$dump" >/dev/null
    then
        STATE[mic]=1

        APP[mic]=$(
            jq -r '
                [
                    .[]
                    | select(.type=="PipeWire:Interface:Node")
                    | select(.info.props."media.class"=="Stream/Input/Audio")
                    | select(.info.state=="running" or .state=="running")
                    | .info.props["node.name"]
                ]
                | unique
                | join(", ")
            ' <<<"$dump"
        )
    fi

    # screen sharing
    if jq -e '
        any(.[];
            (.info.props["media.name"]? // "")
            | test("^(xdph-streaming|gsr-default|game capture)")
        )
    ' <<<"$dump" >/dev/null
    then
        STATE[scr]=1

        APP[scr]=$(
            jq -r '
                [
                    .[]
                    | select(.type=="PipeWire:Interface:Node")
                    | select(
                        .info.props."media.class"=="Stream/Input/Video"
                        or .info.props."media.name"=="gsr-default_output"
                        or .info.props."media.name"=="game capture"
                    )
                    | select(.info.state=="running" or .state=="running")
                    | .info.props["media.name"]
                ]
                | unique
                | join(", ")
            ' <<<"$dump"
        )
    fi
fi

# Camera
if have fuser; then
    declare -A seen

    for dev in /dev/video*; do

        [[ -e $dev ]] || continue

        pids=$(fuser "$dev" 2>/dev/null || true)

        [[ -z $pids ]] && continue

        STATE[cam]=1

        for pid in $pids; do

            [[ ${seen[$pid]:-} ]] && continue

            seen[$pid]=1

            append_app cam "$(ps -p "$pid" -o comm=)"

        done
    done
fi

# Other process detection
detect_process geoclue loc
detect_process wf-recorder rec

# Waybar output
text=""
tooltip=""
classes="privacydot"

for key in mic cam loc scr rec; do
    state=${STATE[$key]:-0}

    (( state )) && text+="<span foreground=\"${COLOR[$key]}\">${ICON[$key]}</span>  "

    tooltip+="${LABEL[$key]}: ${APP[$key]:-OFF}"$'\n'

    (( state )) && classes+=" $key-on" || classes+=" $key-off"
done

tooltip=${tooltip%$'\n'}
text=${text% }

jq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$classes" \
    '{text:$text,tooltip:$tooltip,class:$class}'
