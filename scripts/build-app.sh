#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Alfred.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Alfred "$APP/Contents/MacOS/Alfred"
cp Info.plist "$APP/Contents/Info.plist"
if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP"
fi
echo "$APP"
