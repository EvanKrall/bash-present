#!/bin/bash


function trap_winch() {
    LINES="$(tput lines)"
    COLUMNS="$(tput cols)"
    redraw
}

function discover_slides() {
    local slidefile="$1"
    SLIDES=()
    for slide_func in $(compgen -A "function" "slide_" ); do
        read func line file <<< $(shopt -s extdebug; declare -F "$slide_func")
        if [[ "$file" == "$slidefile" ]]; then
            SLIDES["$line"]="$func"
        fi
    done
    SLIDES=("${SLIDES[@]}")
}


function next_slide() {
    if (( current_slide_number + 1 < ${#SLIDES[@]} )); then
        (( current_slide_number++ ))
    fi
    redraw
}

function prev_slide() {
    if (( current_slide_number > 0 )); then
        (( current_slide_number-- ))
    fi
    redraw
}

function last_slide() {
    current_slide_number="$((${#SLIDES[@]}-1))"
    redraw
}

function first_slide() {
    current_slide_number=0
    redraw
}

function redraw() {
    slideoutput="$("${SLIDES[$current_slide_number]}")"
    clear
    echo "$slideoutput"  | pad_on_bottom "$LINES"
    echo -n $'\e[?25l'
    echo -n "$(black "$((current_slide_number+1))/${#SLIDES[@]}" | bold | pad_on_left "$COLUMNS")"
}

function check_input() {
    input="$1"
    case "$input" in
        ' ') next_slide;;
        $'\e[6~'|$'\e[C') next_slide;;
        $'\e[5~') prev_slide;;
        $'\e[B') last_slide;;
        $'\e[A') first_slide;;
        $'\e[') return 1;;
        $'\e[6') return 1;;
        $'\e[5') return 1;;
        $'\e') return 1;;
        q|Q) exit;;
    esac
}

function present() (

    trap trap_winch WINCH
    slidefile="$1"
    source text_manipulations.sh
    source "$slidefile"

    discover_slides "$slidefile"
    current_slide_number=0
    trap_winch

    input_buffer=""
    while IFS='' read -sn1 key; do

        input_buffer="${input_buffer}${key}"
        if check_input "${input_buffer}"; then
            input_buffer=''
        fi
    done
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # not being sourced.
    present "$@"
fi
