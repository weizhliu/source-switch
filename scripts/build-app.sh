#!/bin/zsh
# Build SourceSwitch.app with SwiftPM only (no Xcode needed).
#   scripts/build-app.sh            -> build/SourceSwitch.app
#   scripts/build-app.sh --install  -> also copy to /Applications and launch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="SourceSwitch"
APP="$ROOT/build/$APP_NAME.app"

# The Command Line Tools ship no SwiftUI macro plugin, and on the macOS 27 SDK even
# `@State` is a macro, so compile against the 26.x SDK. With Xcode installed, unset this.
SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
SWIFT_FLAGS=(-c release --sdk "$SDK")

BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"
swift build "${SWIFT_FLAGS[@]}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST="/Applications/$APP_NAME.app"
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  echo "Installed $DEST"
  open "$DEST"
fi
