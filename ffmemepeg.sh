#!/bin/bash

USAGE="$(basename "$0") [OPTION]... -i INPUT

Options:
    -h, --help              Display this help and exit
    -t, --top               Top text
    -b, --bot               Bottom text
    -o, --output            Output path
    -i, --input             Input path
    -M, --top-margin        Top margin
    -m, --bottom-margin     Bottom margin
    -S, --top-scale         Top text fontsize scale
    -s, --bottom-scale      Bottom text fontsize scale
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
TOP_TEXT=""
BOT_TEXT=""
TOP_MARGIN=0.05
BOTTOM_MARGIN=0.05
TOP_SCALE=1.0
BOT_SCALE=1.0

VALID_ARGS=$(getopt -o t:b:o:i:M:m:S:s:hd --long top:,bottom:,output:,input:,top-margin:,bottom-margin:,top-scale:,bottom-scale:,help,debug, -- "$@")

eval set -- "$VALID_ARGS"

while :;do
    case $1 in
        -t | --top)
            TOP_TEXT="$2"
            shift 2
            ;;
        -b | --bottom)
            BOT_TEXT="$2"
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
            TOP_MARGIN="$2"
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

# Check if input is provided
if [ -z "$INPUT" ]; then
    echo "Input file was not provided. Use -i path" >&2
    exit 1
fi

# Check if input exists
if [ ! -f "$INPUT" ]; then
    echo "Input file \"$INPUT\" does not exist" >&2
    exit 1
fi

IMAGE_WIDTH=$(ffprobe -v error -select_streams v -show_entries stream=width -of csv=p=0:s=x "$INPUT")
IMAGE_HEIGHT=$(ffprobe -v error -select_streams v -show_entries stream=height -of csv=p=0:s=x "$INPUT")

IMAGE_MIN=$((IMAGE_WIDTH > IMAGE_HEIGHT ? IMAGE_HEIGHT : IMAGE_WIDTH))

TOP_TEXT_SIZE=$((IMAGE_MIN * 3 / 2 / (${#TOP_TEXT} + 1)))
TOP_TEXT_SIZE=$(printf %.0f "$(echo "$TOP_TEXT_SIZE * $TOP_SCALE" | bc)")

BOT_TEXT_SIZE=$((IMAGE_MIN * 3 / 2 / (${#BOT_TEXT} + 1)))
BOT_TEXT_SIZE=$(printf %.0f "$(echo "$BOT_TEXT_SIZE * $BOT_SCALE" | bc)")

# Check if ffmpeg can read input file
ffmpeg -i "$INPUT" -f null /dev/null &>/dev/null || echo "ffmpeg cannot read input file \"$INPUT\"" >&2

# Build top and bottom text arguments
TEXT_TEMPLATE="drawtext=font=Impact:fontcolor=white:bordercolor=black:x=(w-text_w)/2"

TOP_TEXT_ARGUMENT="$TEXT_TEMPLATE:fontsize=$TOP_TEXT_SIZE:borderw=$((TOP_TEXT_SIZE/20)):text='$TOP_TEXT':y=$TOP_MARGIN*h"
BOT_TEXT_ARGUMENT="$TEXT_TEMPLATE:fontsize=$BOT_TEXT_SIZE:borderw=$((BOT_TEXT_SIZE/20)):text='$BOT_TEXT':y=h-text_h-$BOTTOM_MARGIN*h"

INPUT_FILENAME=$(basename -- "$INPUT")
OUTPUT="$OUTPUT.${INPUT_FILENAME##*.}"

# Build ffmpeg command
FFMPEG_COMMAND="yes | ffmpeg -i \"$INPUT\" -filter_complex \"[0]$TOP_TEXT_ARGUMENT[top];[top]$BOT_TEXT_ARGUMENT\""
FFMPEG_COMMAND="$FFMPEG_COMMAND \"$OUTPUT\""

if [ -n "$DEBUG" ]; then
    echo "ffmpeg command:"
    echo "$FFMPEG_COMMAND"
    eval "${FFMPEG_COMMAND}"
else
    eval "${FFMPEG_COMMAND}" &>/dev/null
fi


exit $?
