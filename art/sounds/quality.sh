#!/usr/bin/env bash

set -e

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "Usage: $0 <filename-without-extension> [quality]"
	echo "OGG quality: 0–10 (default: 4)"
	echo "MP3 bitrate: kbps (default: 128)"
	exit 1
fi

base="$1"
quality="$2"

if [ -f "${base}.ogg" ]; then
	in="${base}.ogg"
	out="${base}_low.ogg"
	q="${quality:-4}"

	if [ -f "$out" ]; then
		echo "Error: output file already exists: $out"
		exit 1
	fi

	ffmpeg -hide_banner -loglevel error \
		-i "$in" \
		-c:a libvorbis -q:a "$q" \
		"$out"

	echo "OGG quality lowered: $in → $out (q=$q)"
	exit 0
fi

if [ -f "${base}.mp3" ]; then
	in="${base}.mp3"
	out="${base}_low.mp3"
	br="${quality:-128}"

	if [ -f "$out" ]; then
		echo "Error: output file already exists: $out"
		exit 1
	fi

	ffmpeg -hide_banner -loglevel error \
		-i "$in" \
		-c:a libmp3lame -b:a "${br}k" \
		"$out"

	echo "MP3 quality lowered: $in → $out (${br} kbps)"
	exit 0
fi

echo "Error: no .ogg or .mp3 found for base name '$base'"
exit 1
