#!/bin/bash
# Sign a Jfred.app bundle.
#
# macOS ties Desktop, Documents, and Downloads access to the designated
# requirement. An ad-hoc signature ("codesign --sign -") makes that requirement
# the current cdhash, so every rebuild is a new app and the grants are dropped.
# Release builds instead sign with one long-lived self-signed certificate.
# The requirement is then the bundle id plus that certificate's leaf hash,
# which stays the same across machines and versions.
set -euo pipefail

app="${1:?usage: codesign-app.sh Jfred.app}"
identity="Jfred Codesign"
# Designated requirement of every release build. The in-app updater refuses a
# download that does not satisfy it. Keep this line in sync with
# UpdateSignature.requirement in Sources/JfredCore/AppUpdate.swift; a test
# compares the two.
release_requirement='identifier "dev.jim.jfred.local" and certificate leaf = H"e4bb0d4d89c4d6d1ab0c3617de5d88225c5a3910"'
local_dir="${HOME}/.config/jfred/codesign"
p12="${JFRED_CODESIGN_P12:-}"
password="${JFRED_CODESIGN_PASSWORD:-}"

if [ -z "$p12" ] && [ -f "${local_dir}/jfred-codesign.p12" ]; then
  p12="${local_dir}/jfred-codesign.p12"
  password="$(tr -d '\n' < "${local_dir}/password")"
fi

if [ -z "$p12" ]; then
  if [ "${JFRED_CODESIGN_REQUIRED:-}" = "1" ]; then
    echo "JFRED_CODESIGN_P12 is required for this build" >&2
    exit 1
  fi
  codesign --force --sign - "$app"
  codesign --verify --deep --strict "$app"
  echo "Signed ad-hoc. The cdhash changes every build, so TCC folder grants will not survive an update."
  exit 0
fi

if [ ! -f "$p12" ]; then
  echo "Signing certificate not found: $p12" >&2
  exit 1
fi
if [ -z "$password" ]; then
  echo "Signing certificate password is empty" >&2
  exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/jfred-codesign.XXXXXX")"
keychain="${work}/signing.keychain-db"
default_keychain="$(security default-keychain | tr -d '[:space:]"')"
search_list="$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g')"

cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  if [ -n "$search_list" ]; then
    # Paths come from `security list-keychains` and do not contain spaces.
    # shellcheck disable=SC2086
    security list-keychains -d user -s $search_list >/dev/null 2>&1 || true
  fi
  if [ -n "$default_keychain" ]; then
    security default-keychain -s "$default_keychain" >/dev/null 2>&1 || true
  fi
  mkdir -p /tmp/grok
  dest="/tmp/grok/$(basename "$work").$(date +%Y%m%d%H%M%S)"
  mv "$work" "$dest" 2>/dev/null || true
}
trap cleanup EXIT

security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
# codesign only sees identities in the user search list. Put the temporary
# keychain there for this process, and restore the previous list on exit.
# shellcheck disable=SC2086
security list-keychains -d user -s "$keychain" $search_list >/dev/null
security default-keychain -s "$keychain" >/dev/null
security import "$p12" -k "$keychain" -P "$password" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
if ! security find-certificate -c "$identity" "$keychain" >/dev/null; then
  echo "Imported certificate is missing the $identity identity." >&2
  exit 1
fi
codesign --force --sign "$identity" --keychain "$keychain" "$app"
# The same check the in-app updater runs on a downloaded app.
if ! codesign --verify --deep --strict --test-requirement "=${release_requirement}" "$app"; then
  echo "Signed app does not satisfy the release requirement: $release_requirement" >&2
  exit 1
fi
req="$(codesign -d -r- "$app" 2>&1 | sed -n 's/^.*designated => //p')"
if [ "$req" != "$release_requirement" ]; then
  echo "Unexpected designated requirement: $req" >&2
  echo "Expected: $release_requirement" >&2
  exit 1
fi
echo "Signed: $req"
