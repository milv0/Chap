#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: NOTARYTOOL_KEYCHAIN_PROFILE=<profile> $0 /path/to/Chap.pkg" >&2
  exit 64
fi

: "${NOTARYTOOL_KEYCHAIN_PROFILE:?Set the notarytool keychain profile name.}"
pkg_path="$1"

if [[ ! -f "$pkg_path" || "${pkg_path##*.}" != "pkg" ]]; then
  echo "Expected a .pkg artifact: $pkg_path" >&2
  exit 64
fi

xcrun notarytool submit "$pkg_path" \
  --keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE" \
  --wait
xcrun stapler staple "$pkg_path"
xcrun stapler validate "$pkg_path"
pkgutil --check-signature "$pkg_path"
spctl --assess --type install --verbose=4 "$pkg_path"

printf '\nNotarization, stapling, package signature, and Gatekeeper verification succeeded:\n%s\n' "$pkg_path"
