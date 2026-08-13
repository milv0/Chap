#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${OUTPUT_DIR:-"$root_dir/build/release"}"
archive_path="$output_dir/Chap.xcarchive"
installer_signing_identity="${INSTALLER_SIGNING_IDENTITY:-Developer ID Installer}"

cd "$root_dir"

installer_identities="$(security find-identity -v -p basic)"
if [[ "$installer_identities" != *"\"$installer_signing_identity"* ]]; then
  cat >&2 <<EOF
Missing installer-signing identity: $installer_signing_identity
Create and install a Developer ID Installer certificate, then retry.
https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
EOF
  exit 1
fi

Scripts/build-release-dmg.sh

app_path="$archive_path/Products/Applications/Chap.app"
if [[ ! -d "$app_path" ]]; then
  echo "Expected app was not created: $app_path" >&2
  exit 1
fi

version="$(defaults read "$app_path/Contents/Info" CFBundleShortVersionString)"
build_number="$(defaults read "$app_path/Contents/Info" CFBundleVersion)"
pkg_path="$output_dir/Chap-${version}-${build_number}.pkg"

productbuild \
  --component "$app_path" /Applications \
  --sign "$installer_signing_identity" \
  "$pkg_path"
pkgutil --check-signature "$pkg_path"

printf '\nCreated signed, not-yet-notarized PKG:\n%s\n' "$pkg_path"
printf 'Submit it with: NOTARYTOOL_KEYCHAIN_PROFILE=<profile> Scripts/notarize-release-pkg.sh "%s"\n' "$pkg_path"
