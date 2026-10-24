#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Command Line Tools ships Swift Testing's macro plugin outside SwiftPM's
# default plugin search path on some macOS releases. Point the compiler at it
# when present; Xcode installations don't need this.
SWIFT_BIN="$(xcrun --find swift)"
TOOLCHAIN_ROOT="$(cd "$(dirname "$SWIFT_BIN")/../.." && pwd)"
PLUGIN="$TOOLCHAIN_ROOT/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$PLUGIN" ]]; then
  exec swift test -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" "$@"
fi
exec swift test "$@"
