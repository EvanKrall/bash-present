#!/bin/bash


function args_or_stdin() {
    if [[ "${#@}" -gt 0 ]]; then
        (
            IFS=$'\n'
            echo "$*"
        )
    else
        cat
    fi
}

function sum() {
    local sum=0
    local line
    while read line; do
        ((sum+=line))
    done
    echo "$sum"
}

function textwidth() {
    local IFS=':'
    read -ra positions <<< "$(visible_char_positions "$1")"
    echo "${#positions[@]}"
}

function test_textwidth_color() {
    assert "$(textwidth "hurp $(blue durp) gablurp")" == 17
}

function test_textwidth_escapecode() (
    set -e
    assert "$(textwidth "hurp $(bold durp) gablurp")" == 17
)

function test_textwidth_fullwidth() (
    set -e
    assert $(textwidth "ｈｕｒｐ") == 8
)

function indexes_of() {
    local str="$1"
    local pattern="$2"
    for ((i=0; i<${#str}; i++)); do
        if [[ "${str:i}" == "$pattern"* ]]; then
            echo "$i"
        fi
    done
}

function visible_char_positions() (
    shopt -s extglob
    local str="$1"
    local escape_code_pattern=$'\e\[+([0-9])m'
    local double_width_pattern='[！-～]'
    local positions=()
    for ((i=0; i<${#str}; i++)); do
        case "${str:i}" in
            ${escape_code_pattern}*)
                local rest_of_str="${str:i}"
                local str_without_escape_code="${rest_of_str##${escape_code_pattern}}"
                local escape_code="${rest_of_str%%"${str_without_escape_code}"}" #" wtf sublime
                ((i+=${#escape_code}-1))
                ;;
            ${double_width_pattern}*)
                positions+=("" "$i")
                ;;
            *)
                positions+=("$i")
                ;;
        esac
    done
    echo "${positions[*]}"
)


function test_visible_char_positions() {
    set -e
    assert "$(visible_char_positions "foo $(bold bar)")" == '0 1 2 3 8 9 10'
}

function test_visible_char_positions_fullwidth() {
    set -e
    assert "$(visible_char_positions "ｈｕｒｐ")" == ' 0  1  2  3'
}

function test_visible_char_positions_fullwidth_array() (
    set -e
    local IFS=$'\n'
    array=($(visible_char_positions "ｈｕｒｐ"))
)

function linewrap() {
    local line outline nextaddition
    args_or_stdin "$@" | while read line; do
        while [[ "$line" ]]; do
            IFS=' ' read -ra positions <<< "$(visible_char_positions "$line")"
            if [[ "${#positions[@]}" -le "$COLUMNS" ]]; then
                outline="$line"
            else
                outline="${line:0:${positions[$COLUMNS]}+1}"
                outline="${outline% *}"
                if [[ ! "$outline" ]]; then
                    outline="${line}"
                fi
                outline="${outline:0:${positions[$COLUMNS]}}"
            fi
            echo "$outline"
            line="${line:${#outline}}"
            line="${line# }"
        done
    done
}

function test_linewrap_basic() {
    (
        set -e
        COLUMNS=7
        assert "$(linewrap "hi hello")" == $'hi\nhello'
    )
}

function test_linewrap_longword() {
    (
        set -e
        COLUMNS=3
        assert "$(linewrap "hi hello")" == $'hi\nhel\nlo'
    )
}

function test_linewrap_formatting() {
    (
        set -e
        COLUMNS=5
        assert "$(linewrap "hi $(bold hello)")" == $'hi\n'"$(bold hello)"
    )
}

function center() {
    # Center the input or argument.
    local line
    args_or_stdin "$@" | while read line; do
        local linewidth="$(textwidth "$line")"
        printf "%$(( (COLUMNS - linewidth) / 2 ))s%s\n" "" "$line"
    done
}
function escapecode() {
    # Wrap each input line (excluding leading and trailing spaces) in \e[<code>m, where code = $1
    local code=$'\e'"\[$1m"
    shift
    args_or_stdin "$@" | sed -e "s/^ */&${code}/" -e $'s/\e\\[0m/&'"${code}/g" -e $'s/ *$/\e\\[0m&/g'
}

function underline() {
    escapecode 4 "$@"
}

function bold() {
    escapecode 1 "$@"
}

function capitalize() {
    # Change all letters to uppercase, except those in an escape sequence.
    local IFS=''
    lowers=({a..z})
    uppers=({A..Z})
    args_or_stdin "$@" | sed -e "y/${lowers[*]}/${uppers[*]}/" -e $'s/\\(\e\\[[0-9]\\)M/\\1m/g'
}

function test_capitalize() {
    set -e
    assert "$(capitalize hurp)" == "HURP"
    assert "$(capitalize "$(bold hurp)")" == "$(bold HURP)"
}


function line() {
    local num="$1"
    local char="$2"

    spaces="$(printf "%${num}s")"
    echo "${spaces// /$char}"
}

function test_line() {
    set -e
    assert "$(line 5 -)" == "-----"
}

function pad_on_right() {
    local width="$1"
    local line
    shift
    local IFS=''
    args_or_stdin "$@" | while read line; do
        echo "${line}$(line "$((width-$(textwidth "$line")))" ' ')"
    done
}

function pad_on_left() {
    local width="$1"
    local line
    local IFS=''
    shift
    args_or_stdin "$@" | while read line; do
        echo "$(line "$((width-$(textwidth "$line")))" ' ')${line}"
    done
}

function margin_left() {
    local marginsize="$1"
    shift
    local margin="$(line "$marginsize" ' ')"
    local IFS=''
    args_or_stdin "$@" | while read line; do
        echo "${margin}${line}"
    done
}

function pad_on_bottom() {
    local height="$1"
    shift
    args_or_stdin "$@" | (
        local inputlines=0
        local IFS=''
        while read line; do
            echo "$line"
            ((inputlines++))
        done
        while ((inputlines + 1 < height)); do
            echo
            ((inputlines++))
        done
    )
}

function box() {
    local bottomleft=$'\xe2\x94\x94'
    local bottomright=$'\xe2\x94\x98'
    local topleft=$'\xe2\x94\x8c'
    local topright=$'\xe2\x94\x90'
    local horizontal=$'\xe2\x94\x80'
    local vertical=$'\xe2\x94\x82'
    local longestline=0
    local line
    local IFS=''

    lines=()
    while read line; do
        width="$(textwidth "$line")"
        if [[ "$width" -gt "$longestline" ]]; then
            longestline="$width"
        fi
        lines+=("$line")
    done < <(args_or_stdin "$@")

    echo "${topleft}$(line "$longestline" "$horizontal")${topright}"
    for line in "${lines[@]}"; do
        echo "${vertical}$(pad_on_right "$longestline" "$line")${vertical}"
    done
    echo "${bottomleft}$(line "$longestline" "$horizontal")${bottomright}"

}

function test_box() {
    local IFS=$'\n'
    expected=(
        "┌─────┐"
        "│hi   │"
        "│hello│"
        "└─────┘"
    )
    assert "$(box hi hello)" == "${expected[*]}"
}

function bigger_letterpart() (
    cd "$( dirname "${BASH_SOURCE[0]}" )"
    letter="$1"
    part="$2"
    fgrep "#${letter}${part}#" "smbraille.txt" | sed 's/^#..#\(.*\)#$/\1/'
    # IFS='#'
    # # exec 3<smbraille.txt
    # while read line; do
    #     if [[ "${line:1:2}" == "${letter}${part}" ]]; then
    #         echo "${line:4:${#line}-5}"
    #         # break
    #     fi
    # done <smbraille.txt
)

function bigger_line() {
    local line="$1"
    local part="$2"
    local outline=''
    for ((i=0; i<${#line}; i++)); do
        letter="${line:$i:1}"
        outline="${outline}$(bigger_letterpart "$letter" "$part")"
    done
    echo "$outline"
}

function bigger() {
    local line
    local IFS=''
    args_or_stdin "$@" | while read line; do
        local outline=''
        local wrappedline
        bigger_line "$line" "0" |
            linewrap |
            tr -d '%' |
            sed 's/  / /g' |
            while read wrappedline; do
                bigger_line "$wrappedline" 1
                bigger_line "$wrappedline" 2
            done

    done
}

function fullwidth_char() {
    args_or_stdin "$@" | tr '!-~' '！-～'
}

function fullwidth() (
    # set -x
    local line pos
    args_or_stdin "$@" | while read line; do
        local outline=''
        local lastpos=-1
        local IFS=' '
        for pos in $(visible_char_positions "$line") "${#line}"; do
            local invisiblestart="$((${lastpos}+1))"
            local invisiblelength=$((pos - invisiblestart))
            local invisible="${line:$invisiblestart:$invisiblelength}"
            local char="${line:$pos:1}"
            outline+="${invisible}$(fullwidth_char "$char")"
            lastpos="$pos"
        done
        echo "$outline"
    done
)

function black() {
    escapecode 30 "$@"
}
function red() {
    escapecode 31 "$@"
}
function green() {
    escapecode 32 "$@"
}
function yellow() {
    escapecode 33 "$@"
}
function blue() {
    escapecode 34 "$@"
}
function purple() {
    escapecode 35 "$@"
}
function cyan() {
    escapecode 36 "$@"
}
function white() {
    escapecode 37 "$@"
}