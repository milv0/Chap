#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: NOTARYTOOL_KEYCHAIN_PROFILE=<profile> $0 /path/to/Chap.dmg" >&2
  exit 64
fi

: "${NOTARYTOOL_KEYCHAIN_PROFILE:?Set the notarytool keychain profile name.}"
dmg_path="$1"

if [[ ! -f "$dmg_path" || "${dmg_path##*.}" != "dmg" ]]; then
  echo "Expected a .dmg artifact: $dmg_path" >&2
  exit 64
fi

xcrun notarytool submit "$dmg_path" \
  --keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE" \
  --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"

mount_dir="$(mktemp -d)"
cleanup() {
  hdiutil detach "$mount_dir" -quiet 2>/dev/null || true
  rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg_path" >/dev/null
codesign --verify --deep --strict --verbose=4 "$mount_dir/Chap.app"
spctl --assess --type execute --verbose=4 "$mount_dir/Chap.app"

printf '\nNotarization, stapling, signature, and Gatekeeper verification succeeded:\n%s\n' "$dmg_path"
