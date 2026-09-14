#!/bin/zsh
# Run the unit tests with the same SDK the app is built against (see build-app.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"
swift test --sdk "$SDK" "$@"
