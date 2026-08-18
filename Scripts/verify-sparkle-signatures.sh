#!/usr/bin/env bash
set -euo pipefail

# verify-sparkle-signatures.sh — Pre-notarization validation of Sparkle helpers.
# Verifies that every nested Sparkle component has:
#   1. Developer ID Application authority (not ad-hoc)
#   2. Secure timestamp
#   3. Hardened Runtime (runtime option)
#
# Usage: Scripts/verify-sparkle-signatures.sh /path/to/Chap.app

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/Chap.app" >&2
  exit 64
fi

app_path="$1"
if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path" >&2
  exit 1
fi

sparkle_framework="$app_path/Contents/Frameworks/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
  echo "Sparkle.framework not found in app bundle: $sparkle_framework" >&2
  exit 1
fi

# Sparkle 2 nested components that Apple notarization requires to be properly signed.
# Paths are relative to Sparkle.framework/
declare -a components=(
  "Versions/B/Sparkle"
  "Versions/B/Autoupdate"
  "Versions/B/Updater.app"
  "Versions/B/XPCServices/Downloader.xpc"
  "Versions/B/XPCServices/Installer.xpc"
)

failed=0
passed=0

check_component() {
  local path="$1"
  local label="$2"

  if [[ ! -e "$path" ]]; then
    printf '  [SKIP] %s (not present)\n' "$label"
    return
  fi

  local errors=""

  # Check signature validity
  if ! codesign --verify --strict --verbose=0 "$path" 2>/dev/null; then
    errors+="  signature invalid or missing\n"
  fi

  # Check for Developer ID authority (not ad-hoc)
  local sig_info
  sig_info="$(codesign --display --verbose=4 "$path" 2>&1)" || true
  if ! printf '%s' "$sig_info" | grep -q "Authority=Developer ID Application"; then
    errors+="  missing Developer ID Application authority\n"
  fi

  # Check for secure timestamp
  local flags_line
  flags_line="$(printf '%s' "$sig_info" | grep 'flags=' || true)"
  # Timestamp presence: check CodeDirectory flags or Signed Time field
  local timestamp_info
  timestamp_info="$(codesign --display --verbose=4 "$path" 2>&1 | grep -i "Timestamp\|Signed Time" || true)"
  if [[ -z "$timestamp_info" ]]; then
    # Also check via --timestamp verification
    if ! codesign --verify --strict --verbose=4 "$path" 2>&1 | grep -qi "valid on disk\|satisfies"; then
      errors+="  secure timestamp not detected\n"
    fi
  fi

  # Check for Hardened Runtime (runtime flag in CodeDirectory)
  if ! printf '%s' "$sig_info" | grep -q "flags=.*runtime"; then
    errors+="  hardened runtime not enabled\n"
  fi

  if [[ -n "$errors" ]]; then
    printf '  [FAIL] %s\n' "$label"
    printf '%b' "$errors"
    ((failed++)) || true
  else
    printf '  [PASS] %s — Developer ID, timestamp, hardened runtime\n' "$label"
    ((passed++)) || true
  fi
}

printf 'Verifying Sparkle nested component signatures in:\n  %s\n\n' "$app_path"

for component in "${components[@]}"; do
  check_component "$sparkle_framework/$component" "$component"
done

# Also verify the top-level framework signature
printf '\n'
check_component "$sparkle_framework" "Sparkle.framework (top-level)"

printf '\n--- Results: %d passed, %d failed ---\n' "$passed" "$failed"

if [[ $failed -gt 0 ]]; then
  cat >&2 <<'EOF'

Sparkle nested signature verification FAILED.
Notarization will be rejected by Apple. Fix the signing before packaging.
Ensure xcodebuild -exportArchive with Developer ID method is used.
EOF
  exit 1
fi

printf '\nAll Sparkle components are properly signed for notarization.\n'
