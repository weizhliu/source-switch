#!/bin/zsh
# Run the unit tests with the same SDK the app is built against (see build-app.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLCHAIN="${TOOLCHAIN_ROOT:-/Library/Developer/CommandLineTools}"
SDK="${SDKROOT:-$TOOLCHAIN/SDKs/MacOSX26.sdk}"
# SwiftPM doesn't always find the Swift Testing macro plugin when an SDK is overridden.
TESTING_PLUGINS="$TOOLCHAIN/usr/lib/swift/host/plugins/testing"
swift test --sdk "$SDK" -Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS" "$@"
