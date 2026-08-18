#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${OUTPUT_DIR:-"$root_dir/build/release"}"
archive_path="$output_dir/Chap.xcarchive"
export_path="$output_dir/export"
export_options="$root_dir/Scripts/ExportOptions-DeveloperID.plist"
staging_dir="$output_dir/dmg-root"
signing_identity="${SIGNING_IDENTITY:-Developer ID Application}"

cd "$root_dir"

code_signing_identities="$(security find-identity -v -p codesigning)"
if [[ "$code_signing_identities" != *"\"$signing_identity"* ]]; then
  cat >&2 <<EOF
Missing code-signing identity: $signing_identity
Create and install a Developer ID Application certificate, then retry.
https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
EOF
  exit 1
fi

rm -rf "$output_dir"
mkdir -p "$output_dir"

xcodegen

# --- Step 1: Archive ---
xcodebuild \
  -project Chap.xcodeproj \
  -scheme Chap \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  archive

if [[ ! -d "$archive_path" ]]; then
  echo "Archive was not created: $archive_path" >&2
  exit 1
fi

# --- Step 2: Export with Developer ID signing ---
# This is the critical step: xcodebuild -exportArchive re-signs all nested
# code (including Sparkle SPM binary helpers that ship ad-hoc in the archive)
# with the Developer ID identity, hardened runtime, and secure timestamp.
xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path"

app_path="$export_path/Chap.app"
if [[ ! -d "$app_path" ]]; then
  echo "Expected exported app was not created: $app_path" >&2
  exit 1
fi

version="$(defaults read "$app_path/Contents/Info" CFBundleShortVersionString)"
build_number="$(defaults read "$app_path/Contents/Info" CFBundleVersion)"
dmg_path="$output_dir/Chap-${version}-${build_number}.dmg"

# --- Step 3: Verify nested Sparkle helper signatures ---
# All nested code must be Developer ID signed with timestamp and hardened runtime
# before packaging. Fail early if any component does not meet notarization requirements.
Scripts/verify-sparkle-signatures.sh "$app_path"

# --- Step 4: Verify main app bundle ---
codesign --verify --deep --strict --verbose=4 "$app_path"
codesign --display --verbose=4 "$app_path"
codesign --display --entitlements :- "$app_path"

# --- Step 5: Create DMG ---
mkdir -p "$staging_dir"
ditto "$app_path" "$staging_dir/Chap.app"
cp README.md "$staging_dir/README.md"

hdiutil create \
  -volname Chap \
  -srcfolder "$staging_dir" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$dmg_path"
hdiutil verify "$dmg_path"

printf '\nCreated signed, not-yet-notarized DMG:\n%s\n' "$dmg_path"
printf 'Submit it with: NOTARYTOOL_KEYCHAIN_PROFILE=<profile> Scripts/notarize-release-dmg.sh "%s"\n' "$dmg_path"
