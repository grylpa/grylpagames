#!/bin/bash
# The web build as an itch.io upload: nomizo-v<version>-itch-web.zip, made from export/web/ AFTER zip.sh has made its
# index.html (the exported nomizo.html with the GoatCounter snippet).
#
# itch.io unpacks the zip onto its own server and shows index.html in a frame. Everything goes in at the zip's TOP
# level, laid out exactly as on grylpa.com: index.html, the nomizo.* files beside it and packs/ beside them -- the
# game fetches packs/<game>.pck from the folder its own page was loaded from (scripts/game_packs.gd `_base_url`).
# nomizo.html is left out: itch wants one page, and index.html is it.
#
#     ./itch.sh            (version from project.godot)
#     ./itch.sh 1.2.0
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$BASE_DIR")"
WEB_SRC="$BASE_DIR/web"

if [ $# -ge 1 ] && [ -n "$1" ]; then
	VERSION="$1"
else
	VERSION="$(grep '^config/version=' "$PROJECT_DIR/project.godot" | cut -d'"' -f2)"
fi
if [ -z "$VERSION" ]; then
	echo "Could not determine version. Pass one manually: ./itch.sh 1.0.0"
	exit 1
fi

# what must be there: zip.sh's page, the engine's files and the split packs
for F in index.html nomizo.js nomizo.wasm nomizo.pck; do
	if [ ! -f "$WEB_SRC/$F" ]; then
		echo "Missing: $WEB_SRC/$F (export Web, then run zip.sh)"
		exit 1
	fi
done
if [ ! -d "$WEB_SRC/packs" ] || [ -z "$(ls -A "$WEB_SRC/packs")" ]; then
	echo "Missing: $WEB_SRC/packs/ -- this web export was not split (see CLAUDE.md, \"The web build\")"
	exit 1
fi
if [ "$WEB_SRC/nomizo.html" -nt "$WEB_SRC/index.html" ]; then
	echo "index.html is older than nomizo.html: run zip.sh first"
	exit 1
fi
if ! grep -q "goatcounter" "$WEB_SRC/index.html"; then
	echo "Warning: index.html has no GoatCounter snippet (did zip.sh run?)"
fi
# a pack of ~50 MB means the export was not split: every visitor would load every game
PCK_MB=$(( $(stat -c %s "$WEB_SRC/nomizo.pck") / 1048576 ))
if [ "$PCK_MB" -gt 30 ]; then
	echo "nomizo.pck is ${PCK_MB} MB: this web export was not split"
	exit 1
fi

OUT_FILE="$BASE_DIR/nomizo-v${VERSION}-itch-web.zip"
rm -f "$OUT_FILE"
(
	cd "$WEB_SRC"
	# the page, the engine's files (nomizo.* but the raw nomizo.html) and the packs
	FILES=(index.html)
	for F in nomizo.*; do
		[ "$F" = "nomizo.html" ] || FILES+=("$F")
	done
	zip -9 -r -q "$OUT_FILE" "${FILES[@]}" packs
)

COUNT="$(unzip -Z1 "$OUT_FILE" | grep -vc '/$')"
SIZE_MB="$(du -m "$OUT_FILE" | cut -f1)"
echo "Created: $OUT_FILE ($COUNT files, ${SIZE_MB} MB)"
# itch.io's limits for a browser game: 1000 files, 1 GB unpacked, 200 MB a file
if [ "$COUNT" -gt 1000 ]; then
	echo "Warning: more than 1000 files: itch.io will refuse it"
fi
