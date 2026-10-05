#!/bin/zsh
# End-to-end check that a switch made by SourceSwitch reaches the front app's IME, not just
# the indicators. Takes focus and changes the input source for a minute; don't type meanwhile.
#   scripts/ime-probe.sh [rounds]            -> switches with SourceSwitch; non-zero if any didn't take effect
#   scripts/ime-probe.sh --native [rounds]   -> switches with macOS's ⌃Space / ⌃⌥Space instead
#                                              (needs Accessibility for IMEProbe; it asks on first run)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build-app.sh" >/dev/null

SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
BIN_DIR="$(swift build -c release --sdk "$SDK" --show-bin-path)"
swift build -c release --sdk "$SDK" --product IMEProbe

# Launched through LaunchServices like a real app: run as a child of the terminal, the probe
# never reproduces the bug.
# Re-signing changes the ad-hoc signature, which voids an Accessibility grant, so only replace
# the bundle when the probe itself changed.
PROBE="$ROOT/build/IMEProbe.app"
UNSIGNED="$ROOT/build/IMEProbe.unsigned"
if [[ ! -d "$PROBE" ]] || ! cmp -s "$BIN_DIR/IMEProbe" "$UNSIGNED"; then
  cp "$BIN_DIR/IMEProbe" "$UNSIGNED"
  rm -rf "$PROBE"
  mkdir -p "$PROBE/Contents/MacOS"
  cp "$BIN_DIR/IMEProbe" "$PROBE/Contents/MacOS/IMEProbe"
  cp "$ROOT/Resources/IMEProbe/Info.plist" "$PROBE/Contents/Info.plist"
  codesign --force --sign - "$PROBE"
fi

SWITCHER="$ROOT/build/SourceSwitch.app/Contents/MacOS/SourceSwitch"
if [[ "${1:-}" == "--native" ]]; then
  SWITCHER="--native"
  shift
fi

LOG="$ROOT/build/ime-probe.log"
rm -f "$LOG"
open -W -n --stdout "$LOG" --stderr "$LOG" "$PROBE" \
  --args "$SWITCHER" "${1:-3}"
grep -vE 'IMKCFRunLoopWakeUpReliable|TSM AdjustCapsLockLED|sandbox_extension' "$LOG"
grep -q '^0 of ' "$LOG"
