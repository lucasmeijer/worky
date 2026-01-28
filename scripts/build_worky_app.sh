#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="Worky"
BIN_NAME="GWMApp"
INFO_PLIST="$ROOT_DIR/Resources/WorkyInfo.plist"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

BIN_DIR=$(swift build -c release --product "$BIN_NAME" --show-bin-path)
BIN_PATH="$BIN_DIR/$BIN_NAME"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist at $INFO_PLIST" >&2
  exit 1
fi

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing icon at $ICON_FILE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$BIN_NAME"
cp "$INFO_PLIST" "$APP_DIR/Contents/Info.plist"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "Built $APP_DIR"
