#!/bin/bash

USAGE="$(basename "$0") [OPTION]... -i INPUT

Options:
    -t, --top               Top text
    -b, --bot               Bottom text
    -o, --output            Output path
    -i, --input             Input path
    -M, --top-margin        Top margin
    -m, --bottom-margin     Bottom margin
    -S, --top-scale         Top text fontsize scale
    -s, --bottom-scale      Bottom text fontsize scale
    -h, --help              Display this help and exit
    -d, --debug             Show debug info
"

# Check ffmpeg
if ! type ffmpeg > /dev/null; then
    echo "Cannot find ffmpeg" >&2
    exit 1
fi
if ! type ffprobe > /dev/null; then
    echo "Cannot find ffprobe" >&2
    exit 1
fi

# Parse arguments
OUTPUT="out"
TOP_TEXT=()
BOT_TEXT=()
TOP_MARGIN=0.05
BOT_MARGIN=0.05
TOP_SCALE=1.0
BOT_SCALE=1.0
INTERLINE=0.1

VALID_ARGS=$(getopt -o t:b:o:i:M:m:S:s:hd --long top:,bottom:,output:,input:,top-margin:,bottom-margin:,top-scale:,bottom-scale:,help,debug, -- "$@")

eval set -- "$VALID_ARGS"

function check_float () {
    grep -qE '^[0-9]+(\.[0-9]+)?$' <<<"$1";
}

function check_text () {
    grep -v "'" --quiet <<<"$1"
}

while :;do
    case $1 in
        -t | --top)
            TOP_TEXT+=("$2")
            shift 2
            ;;
        -b | --bottom)
            BOT_TEXT+=("$2")
            shift 2
            ;;
        -o | --output)
            OUTPUT="$2"
            shift 2
            ;;
        -i | --input)
            INPUT="$2"
            shift 2
            ;;
        -M | --top-margin)
            TOP_MARGIN="$2"
            shift 2
            ;;
        -m | --bottom-margin)
            BOT_MARGIN="$2"
            shift 2
            ;;
        -S | --top-scale)
            TOP_SCALE="$2"
            shift 2
            ;;
        -s | --bottom-scale)
            BOT_SCALE="$2"
            shift 2
            ;;
        -h | --help)
            echo "$USAGE" >&2
            exit 0
            ;;
        -d | --debug)
            DEBUG=yes
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

# Check if margins are float
if ! check_float "$TOP_MARGIN"; then
    echo "Top margin should be a float number, not \"$TOP_MARGIN\"" >&2
    exit 1
fi
if ! check_float "$BOT_MARGIN"; then
    echo "Bottom margin should be a float number, not \"$BOT_MARGIN\"" >&2
    exit 1
fi
# Check if scales are float
if ! check_float "$TOP_SCALE"; then
    echo "Top scale should be a float number, not \"$TOP_SCALE\"" >&2
    exit 1
fi
if ! check_float "$BOT_SCALE"; then
    echo "Bottom scale should be a float number, not \"$BOT_SCALE\"" >&2
    exit 1
fi

# Check if text does not contain ' symbol
for PHRASE in "${TOP_TEXT[@]}"; do
    if ! check_text "$PHRASE"; then
        echo "Phrase \"$PHRASE\" contains ' symbol. Remove it" >&2
        exit 1
    fi
done
for PHRASE in "${BOT_TEXT[@]}"; do
    if ! check_text "$PHRASE"; then
        echo "Phrase \"$PHRASE\" contains ' symbol. Remove it" >&2
        exit 1
    fi
done

# Check if input was provided
if [ -z "$INPUT" ]; then
    echo "Input file was not provided. Use -i path" >&2
    exit 1
fi

# Check if input exists
if [ ! -f "$INPUT" ]; then
    echo "Input file \"$INPUT\" does not exist" >&2
    exit 1
fi

# Check if ffmpeg can read input file
ffmpeg -i "$INPUT" -f null /dev/null &>/dev/null || echo "ffmpeg cannot read input file \"$INPUT\"" >&2

# Get image sizes
IMAGE_WIDTH=$(ffprobe -v error -select_streams v -show_entries stream=width -of csv=p=0:s=x "$INPUT")
IMAGE_HEIGHT=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0:s=x "$INPUT")
IMAGE_MIN=$((IMAGE_WIDTH > IMAGE_HEIGHT ? IMAGE_HEIGHT : IMAGE_WIDTH))

TEXT_TEMPLATE="drawtext=font=Impact:fontcolor=white:bordercolor=black:x=(w-text_w)/2"

# Construct top text argument
ARGUMENT=""
K=0
if [ "${#TOP_TEXT[@]}" -gt 0 ]; then
    TOP_TEXT_SIZE=$((IMAGE_MIN * 3 / 2 / (${#TOP_TEXT[0]} + 1)))
    TOP_TEXT_SIZE=$(printf %.0f "$(echo "$TOP_TEXT_SIZE * $TOP_SCALE" | bc)")
    for PHRASE in "${TOP_TEXT[@]}"; do
        TEMP_SIZE=$((IMAGE_MIN * 3 / 2 / (${#PHRASE} + 1)))
        TEMP_SIZE=$(printf %.0f "$(echo "$TEMP_SIZE * $TOP_SCALE" | bc)")
        if [ "$TOP_TEXT_SIZE" -gt "$TEMP_SIZE" ]; then
            TOP_TEXT_SIZE="$TEMP_SIZE"
        fi
    done
    N=0
    for PHRASE in "${TOP_TEXT[@]}"; do
        ARGUMENT="$ARGUMENT;[$K]$TEXT_TEMPLATE:fontsize=$TOP_TEXT_SIZE:borderw=$((TOP_TEXT_SIZE/20)):text='$PHRASE':y=$TOP_MARGIN*h+$N*$TOP_TEXT_SIZE*(1+$INTERLINE)[$((K+1))]"
        N=$((N+1))
        K=$((K+1))
    done
    ARGUMENT="${ARGUMENT:1}"
fi

if [ "${#BOT_TEXT[@]}" -gt 0 ]; then
    BOT_TEXT_SIZE=$((IMAGE_MIN * 3 / 2 / (${#BOT_TEXT[0]} + 1)))
    BOT_TEXT_SIZE=$(printf %.0f "$(echo "$BOT_TEXT_SIZE * $BOT_SCALE" | bc)")
    for PHRASE in "${BOT_TEXT[@]}"; do
        TEMP_SIZE=$((IMAGE_MIN * 3 / 2 / (${#PHRASE} + 1)))
        TEMP_SIZE=$(printf %.0f "$(echo "$TEMP_SIZE * $BOT_SCALE" | bc)")
        if [ "$BOT_TEXT_SIZE" -gt "$TEMP_SIZE" ]; then
            BOT_TEXT_SIZE="$TEMP_SIZE"
        fi
    done
    N="${#BOT_TEXT[@]}"
    BARGUMENT=""
    for PHRASE in "${BOT_TEXT[@]}"; do
        BARGUMENT="$BARGUMENT;[$K]$TEXT_TEMPLATE:fontsize=$BOT_TEXT_SIZE:borderw=$((BOT_TEXT_SIZE/20)):text='$PHRASE':y=h-$BOT_MARGIN*h-$N*(text_h+$INTERLINE*$BOT_TEXT_SIZE)[$((K+1))]"
        N=$((N-1))
        K=$((K+1))
    done
    BARGUMENT="${BARGUMENT:1}"

    if [ -n "$ARGUMENT" ]; then
        ARGUMENT="$ARGUMENT;$BARGUMENT"
    else
        ARGUMENT="$BARGUMENT"
    fi
fi

if [ -n "$ARGUMENT" ]; then
    LAST="[$K]"
    TRUNC_LAST=-${#LAST}
    ARGUMENT="${ARGUMENT::TRUNC_LAST}"
    ARGUMENT="-filter_complex \"$ARGUMENT\""
fi

INPUT_FILENAME=$(basename -- "$INPUT")
OUTPUT="$OUTPUT.${INPUT_FILENAME##*.}"

# Build ffmpeg command
FFMPEG_COMMAND="yes | ffmpeg -i \"$INPUT\" $ARGUMENT"
FFMPEG_COMMAND="$FFMPEG_COMMAND \"$OUTPUT\""

if [ -n "$DEBUG" ]; then
    echo "ffmpeg command:"
    echo "$FFMPEG_COMMAND"
    eval "${FFMPEG_COMMAND}"
else
    eval "${FFMPEG_COMMAND}" &>/dev/null
fi


exit $?
