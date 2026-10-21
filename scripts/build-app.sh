#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Jfred.app"
if [ -e "$APP" ]; then
  mkdir -p /tmp/grok
  mv "$APP" "/tmp/grok/$(basename "$APP").$(date +%Y%m%d%H%M%S)"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Jfred "$APP/Contents/MacOS/Jfred"
cp Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.png ]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  sips -z 16 16 Resources/AppIcon.png --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 Resources/AppIcon.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 Resources/AppIcon.png --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 Resources/AppIcon.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 Resources/AppIcon.png --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 Resources/AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 Resources/AppIcon.png --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 Resources/AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 Resources/AppIcon.png --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 Resources/AppIcon.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  cp Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
  mkdir -p /tmp/grok
  mv "$(dirname "$ICONSET")" "/tmp/grok/AppIcon.iconset.$(date +%Y%m%d%H%M%S)"
fi
if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP"
fi
echo "$APP"
