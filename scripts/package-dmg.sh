#!/bin/sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

ci=0
for arg in "$@"; do
  case "$arg" in
    --ci) ci=1 ;;
    *)
      echo "Unknown option: $arg (expected --ci)" >&2
      exit 1
      ;;
  esac
done

"$root/scripts/build-app.sh"
app="$root/build/Jfred.app"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
arch="$(uname -m)"
stage="$root/dist/dmg-stage"
dmg="$root/dist/Jfred-${version}-${arch}.dmg"

rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/Jfred.app"
ln -s /Applications "$stage/Applications"

cat > "$stage/Install.txt" <<'EOF'
Jfred
=====

Requires macOS 14 or later. This build is Apple Silicon (arm64) only.

1. Drag Jfred into Applications.
2. First launch: right-click Jfred.app and choose Open
   (the app is ad-hoc signed, not notarized).
   Or run: xattr -cr /Applications/Jfred.app

Jfred stays out of the Dock until Preferences is open.
EOF

hdiutil create \
  -volname "Jfred" \
  -srcfolder "$stage" \
  -ov \
  -format UDZO \
  "$dmg" >/dev/null

rm -rf "$stage"

echo "Built $dmg"

if [ "$ci" = 1 ]; then
  exit 0
fi

dropbox="$HOME/Dropbox"
if [ -d "$dropbox" ]; then
  cp -f "$dmg" "$dropbox/$(basename "$dmg")"
  echo "Copied $dropbox/$(basename "$dmg")"
fi
