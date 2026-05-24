#!/usr/bin/env bash

set -e

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <filename-without-extension>"
	exit 1
fi

base="$1"
in="${base}.wav"
out="${base}.ogg"

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
	-c:a libvorbis -q:a 5 \
	"$out"

echo "Converted: $in → $out"
