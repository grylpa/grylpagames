#!/usr/bin/env bash

set -e

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "Usage: $0 <filename-without-extension> [target_I]"
	echo "Example: $0 rain -16"
	echo "Default target_I is -18"
	exit 1
fi

base="$1"
target_I="${2:--18}"

in="${base}.ogg"
out="${base}_louder.ogg"

if [ ! -f "$in" ]; then
	echo "Error: input file not found: $in"
	exit 1
fi

if [ -f "$out" ]; then
	echo "Error: output file already exists: $out"
	exit 1
fi

ffmpeg -hide_banner -loglevel error \
	-i "$in" \
	-af "loudnorm=I=${target_I}:TP=-1.5:LRA=11" \
	-c:a libvorbis -q:a 5 \
	"$out"

echo "Normalized: $in → $out (I=${target_I} LUFS)"
