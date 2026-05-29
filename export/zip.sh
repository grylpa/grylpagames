#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$BASE_DIR")"

if [ $# -ge 1 ] && [ -n "$1" ]; then
	VERSION="$1"
else
	VERSION="$(
		grep '^config/version=' "$PROJECT_DIR/project.godot" \
		| cut -d'"' -f2
	)"
fi

if [ -z "$VERSION" ]; then
	echo "Could not determine version."
	echo "Pass one manually: ./package_release.sh 1.0.0"
	exit 1
fi

echo "Packaging version: $VERSION"

for PLATFORM in android linux win; do
	SRC_DIR="$BASE_DIR/$PLATFORM"

	if [ ! -d "$SRC_DIR" ]; then
		echo "Missing folder: $SRC_DIR"
		exit 1
	fi

	if [ "$PLATFORM" = "android" ]; then
		ARTIFACT="$(find "$SRC_DIR" -maxdepth 1 -type f -name 'grylpa_brain*.apk' | head -n 1)"

		if [ -z "$ARTIFACT" ]; then
			echo "No grylpa_brain*.apk found in $SRC_DIR"
			exit 1
		fi

		OUT_FILE="$BASE_DIR/grylpa_brain-v${VERSION}-android.apk"
		OUT_SHA="$OUT_FILE.sha256"

		rm -f "$OUT_FILE" "$OUT_SHA"
		cp "$ARTIFACT" "$OUT_FILE"

	else
		ARTIFACT="$(find "$SRC_DIR" -maxdepth 1 -type f -name 'grylpa_brain.*' ! -name '*.idsig' | head -n 1)"

		if [ -z "$ARTIFACT" ]; then
			echo "No grylpa_brain.* artifact found in $SRC_DIR"
			exit 1
		fi

		if [ "$PLATFORM" = "linux" ]; then
			chmod +x "$ARTIFACT"
			OUT_FILE="$BASE_DIR/grylpa_brain-v${VERSION}-linux-x86_64.zip"
		else
			OUT_FILE="$BASE_DIR/grylpa_brain-v${VERSION}-windows-x86_64.zip"
		fi

		OUT_SHA="$OUT_FILE.sha256"

		rm -f "$OUT_FILE" "$OUT_SHA"

		(
			cd "$SRC_DIR"
			zip -9 "$OUT_FILE" "$(basename "$ARTIFACT")"
		)
	fi

	(
		cd "$BASE_DIR"
		sha256sum "$(basename "$OUT_FILE")" > "$(basename "$OUT_SHA")"
	)

	echo "Created: $OUT_FILE"
	echo "Created: $OUT_SHA"
done
