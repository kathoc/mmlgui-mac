#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <app-bundle> <output-dmg>" >&2
	exit 1
fi

APP_BUNDLE=$1
OUTPUT_DMG=$2

if [ ! -d "$APP_BUNDLE" ]; then
	echo "App bundle not found: $APP_BUNDLE" >&2
	exit 1
fi

APP_NAME=$(basename "$APP_BUNDLE")
APP_STEM=${APP_NAME%.app}
VOLUME_NAME="$APP_STEM"

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mmlgui-dmg.XXXXXX")
STAGE_DIR="$WORK_DIR/stage"
mkdir -p "$STAGE_DIR"

cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

cp -R "$APP_BUNDLE" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"

hdiutil create \
	-volname "$VOLUME_NAME" \
	-srcfolder "$STAGE_DIR" \
	-ov \
	-format UDZO \
	"$OUTPUT_DMG"

echo "Created $OUTPUT_DMG"
