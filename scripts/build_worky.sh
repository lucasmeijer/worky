#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="Worky"
BIN_NAME="Worky"
INFO_PLIST="$ROOT_DIR/Resources/WorkyInfo.plist"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CERT_HOLDER="Lucas Meijer"

ACTION="app"
MODE=""
NOTARIZE=false

usage() {
  cat <<EOF
Usage: $0 [app|dmg] [--mode dev|dist] [--notarize]

Defaults:
  app -> dev signing
  dmg -> dist signing

Notes:
  - Looks for signing identities owned by "$CERT_HOLDER".
  - For DMG builds, --mode dist is required.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    app|dmg)
      ACTION="$1"
      shift
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --notarize)
      NOTARIZE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  if [[ "$ACTION" == "dmg" ]]; then
    MODE="dist"
  else
    MODE="dev"
  fi
fi

if [[ "$MODE" != "dev" && "$MODE" != "dist" ]]; then
  echo "--mode must be 'dev' or 'dist'." >&2
  exit 1
fi

if [[ "$ACTION" == "dmg" && "$MODE" != "dist" ]]; then
  echo "DMG builds require --mode dist." >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist at $INFO_PLIST" >&2
  exit 1
fi

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing icon at $ICON_FILE" >&2
  exit 1
fi

find_identity() {
  local kind="$1"
  /usr/bin/security find-identity -v -p codesigning \
    | /usr/bin/awk -F'"' -v kind="$kind" -v holder="$CERT_HOLDER" \
      '$2 ~ "^"kind": " holder " \\(" { print $2; exit }'
}

ensure_identity() {
  local kind="$1"
  local identity
  identity=$(find_identity "$kind")
  if [[ -z "$identity" ]]; then
    cat >&2 <<EOF
No "$kind" signing identity found for "$CERT_HOLDER".

Make sure your certificate is installed (Xcode -> Settings -> Accounts -> Manage Certificates).
Then re-run:
  security find-identity -v -p codesigning

TEAMID is in parentheses in the identity line, e.g.:
  "$kind: $CERT_HOLDER (ABCDE12345)"
EOF
    exit 1
  fi
  echo "$identity"
}

sign_app() {
  local identity="$1"
  local sign_args=(--force --sign "$identity")

  if [[ "$MODE" == "dist" && -z "${CODESIGN_OPTIONS:-}" ]]; then
    CODESIGN_OPTIONS="--options runtime --timestamp"
  fi

  if [[ -n "${CODESIGN_ENTITLEMENTS:-}" ]]; then
    sign_args+=(--entitlements "$CODESIGN_ENTITLEMENTS")
  fi
  if [[ -n "${CODESIGN_OPTIONS:-}" ]]; then
    sign_args+=(${(z)CODESIGN_OPTIONS})
  fi

  /usr/bin/codesign "${sign_args[@]}" "$APP_DIR/Contents/MacOS/$BIN_NAME"
  /usr/bin/codesign "${sign_args[@]}" "$APP_DIR"
  /usr/bin/codesign --verify --deep --strict "$APP_DIR"
}

build_app() {
  local bin_dir bin_path
  bin_dir=$(swift build -c release --product "$BIN_NAME" --show-bin-path)
  bin_path="$bin_dir/$BIN_NAME"

  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

  cp "$bin_path" "$APP_DIR/Contents/MacOS/$BIN_NAME"
  cp "$INFO_PLIST" "$APP_DIR/Contents/Info.plist"
  cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
  cp "$ROOT_DIR/scripts/open_or_create_ghostty.sh" "$APP_DIR/Contents/Resources/open_or_create_ghostty.sh"
}

build_dmg() {
  local version dmg_name stage_dir dmg_path temp_dmg device attach_out
  version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
  if [[ -z "$version" ]]; then
    version="0.0"
  fi

  dmg_name="${DMG_NAME:-${APP_NAME}-${version}}"
  stage_dir="$DIST_DIR/.dmg-stage"
  dmg_path="$DIST_DIR/${dmg_name}.dmg"
  temp_dmg="$DIST_DIR/${dmg_name}.temp.dmg"

  rm -rf "$stage_dir"
  mkdir -p "$stage_dir"
  cp -R "$APP_DIR" "$stage_dir/"
  ln -s /Applications "$stage_dir/Applications"

  rm -f "$dmg_path" "$temp_dmg"
  hdiutil create -volname "$APP_NAME" -srcfolder "$stage_dir" -ov -format UDRW "$temp_dmg" >/dev/null

  attach_out=$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen -nobrowse "$temp_dmg")
  device=$(echo "$attach_out" | /usr/bin/awk 'NR==1{print $1}')
  if [[ -z "$device" ]]; then
    echo "Failed to mount DMG for customization." >&2
    exit 1
  fi

  sleep 0.5
  /usr/bin/osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 660, 420}
    set icon size of icon view options of container window to 128
    set arrangement of icon view options of container window to not arranged
    set position of item "$APP_NAME.app" of container window to {160, 200}
    set position of item "Applications" of container window to {440, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

  sleep 0.5
  /usr/bin/hdiutil detach "$device" -quiet
  hdiutil convert "$temp_dmg" -format UDZO -ov -o "$dmg_path" >/dev/null
  rm -f "$temp_dmg"

  /usr/bin/codesign --force --sign "$1" "$dmg_path"

  if [[ "$NOTARIZE" == true ]]; then
    if [[ -z "${NOTARY_PROFILE:-}" ]]; then
      echo "NOTARY_PROFILE is required when using --notarize." >&2
      exit 1
    fi
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
  fi

  echo "Built $dmg_path"
}

if [[ "$MODE" == "dev" ]]; then
  identity=$(ensure_identity "Apple Development")
else
  identity=$(ensure_identity "Developer ID Application")
fi

echo "Using signing identity: $identity"

build_app
sign_app "$identity"

if [[ "$ACTION" == "dmg" ]]; then
  build_dmg "$identity"
  exit 0
fi

echo "Built $APP_DIR"
