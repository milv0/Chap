#!/usr/bin/env bash
set -euo pipefail

# Scripts/generate-appcast.sh — Generate or update the Sparkle appcast feed.
#
# This script is invoked AFTER notarized artifacts (PKG + DMG) and the GitHub
# Release are published. It updates docs/appcast.xml with a new enclosure entry
# for the notarized DMG (Sparkle does not support PKG-based updates).
#
# Prerequisites:
#   - The notarized DMG must exist at the path passed as argument.
#   - The Sparkle EdDSA private key must be available in the operator's Keychain
#     (default account name: "ed25519"), or via SPARKLE_KEY_FILE env var.
#   - SPARKLE_BIN_DIR or SPARKLE_GENERATE_APPCAST must point to the Sparkle CLI.
#
# Usage:
#   Scripts/generate-appcast.sh <notarized-dmg-path>
#
# Environment:
#   SPARKLE_BIN_DIR           — Directory containing generate_appcast and sign_update.
#   SPARKLE_GENERATE_APPCAST  — Explicit path to generate_appcast (overrides SPARKLE_BIN_DIR).
#   SPARKLE_SIGN_UPDATE       — Explicit path to sign_update (overrides SPARKLE_BIN_DIR).
#   SPARKLE_KEY_FILE          — Path to private EdDSA key file (optional; Keychain is default).
#   DOWNLOAD_URL_PREFIX       — Base URL for release downloads. Default:
#                               https://github.com/milv0/Chap/releases/download
#
# The script:
#   1. Resolves Sparkle CLI tools (fail-closed if not found).
#   2. Signs the notarized DMG with sign_update to produce the EdDSA signature.
#   3. Runs generate_appcast on a staging directory containing the DMG and the
#      existing appcast.xml, producing an updated feed.
#   4. Validates the resulting appcast.xml with xmllint and checks for required
#      Sparkle enclosure attributes (sparkle:edSignature, sparkle:version, url, length).
#   5. Copies the validated appcast.xml to docs/appcast.xml.
#
# The operator then commits and pushes docs/appcast.xml to dev, which will
# reach main (and GitHub Pages) via the normal release merge or a follow-up commit.
#
# SAFETY:
#   - Does NOT force-push, amend, retag, or mutate main/tags.
#   - Does NOT access or export private keys beyond what Sparkle's own CLI does.
#   - Fails closed: any missing tool, signing failure, or validation error aborts.

usage() {
    cat >&2 <<'EOF'
Usage: Scripts/generate-appcast.sh <notarized-dmg-path>

Generate/update the Sparkle appcast with a signed entry for the notarized DMG.

Required environment (one of):
  SPARKLE_BIN_DIR          — Directory containing Sparkle CLI tools.
  SPARKLE_GENERATE_APPCAST — Explicit path to generate_appcast.

Optional:
  SPARKLE_SIGN_UPDATE      — Explicit path to sign_update.
  SPARKLE_KEY_FILE         — Path to EdDSA private key file (default: Keychain).
  DOWNLOAD_URL_PREFIX      — Download URL base (default: GitHub Releases).
EOF
    exit 64
}

if [[ $# -ne 1 ]]; then
    usage
fi

dmg_path="$1"

if [[ ! -f "$dmg_path" ]]; then
    echo "Error: DMG not found: $dmg_path" >&2
    exit 1
fi

if [[ "${dmg_path##*.}" != "dmg" ]]; then
    echo "Error: Expected a .dmg file: $dmg_path" >&2
    exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docs_appcast="$root_dir/docs/appcast.xml"

# --- Resolve Sparkle CLI tools (fail-closed) ---

resolve_tool() {
    local tool_name="$1"
    local override_var="$2"

    # 1. Explicit override variable
    if [[ -n "${!override_var:-}" ]]; then
        if [[ -x "${!override_var}" ]]; then
            printf '%s' "${!override_var}"
            return 0
        fi
        echo "Error: $override_var is set but not executable: ${!override_var}" >&2
        return 1
    fi

    # 2. SPARKLE_BIN_DIR
    if [[ -n "${SPARKLE_BIN_DIR:-}" ]]; then
        local candidate="$SPARKLE_BIN_DIR/$tool_name"
        if [[ -x "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
        echo "Error: SPARKLE_BIN_DIR is set but $tool_name not found at: $candidate" >&2
        return 1
    fi

    # 3. Fail closed with actionable message
    cat >&2 <<EOF
Error: Cannot locate '$tool_name'.

Set one of these environment variables:
  SPARKLE_BIN_DIR=/path/to/Sparkle/bin
  ${override_var}=/path/to/$tool_name

The Sparkle CLI tools are typically found in:
  • Xcode DerivedData: ~/Library/Developer/Xcode/DerivedData/<project>/SourcePackages/artifacts/sparkle/Sparkle/bin/
  • Sparkle release archive: Sparkle-2.x.y/bin/
EOF
    return 1
}

GENERATE_APPCAST="$(resolve_tool "generate_appcast" "SPARKLE_GENERATE_APPCAST")"
SIGN_UPDATE="$(resolve_tool "sign_update" "SPARKLE_SIGN_UPDATE")"

# --- Extract version from DMG filename ---
# Expected pattern: Chap-<version>-<build>.dmg
dmg_filename="$(basename "$dmg_path")"
if [[ ! "$dmg_filename" =~ ^Chap-([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)\.dmg$ ]]; then
    echo "Error: DMG filename does not match expected pattern Chap-VERSION-BUILD.dmg: $dmg_filename" >&2
    exit 1
fi
version="${BASH_REMATCH[1]}"
build="${BASH_REMATCH[2]}"

# --- Prepare staging directory ---
staging_dir="$(mktemp -d)"
cleanup() {
    local rc=$?
    rm -rf "$staging_dir"
    exit $rc
}
trap cleanup EXIT

# Copy existing appcast if present
if [[ -f "$docs_appcast" ]]; then
    cp "$docs_appcast" "$staging_dir/appcast.xml"
fi

# Copy the notarized DMG to staging
cp "$dmg_path" "$staging_dir/"

# Copy release notes if available (generate_appcast uses .md/.html/.txt with same basename)
release_notes_file="$root_dir/release-notes/$version.md"
if [[ -f "$release_notes_file" ]]; then
    cp "$release_notes_file" "$staging_dir/$dmg_filename.md"
    # Rename to match archive basename (without .dmg extension)
    mv "$staging_dir/$dmg_filename.md" "$staging_dir/${dmg_filename%.dmg}.md"
fi

# --- Determine download URL ---
download_url_prefix="${DOWNLOAD_URL_PREFIX:-https://github.com/milv0/Chap/releases/download}"
download_url="$download_url_prefix/v$version/$dmg_filename"

# --- Run generate_appcast ---
key_args=()
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
    if [[ ! -f "$SPARKLE_KEY_FILE" ]]; then
        echo "Error: SPARKLE_KEY_FILE not found: $SPARKLE_KEY_FILE" >&2
        exit 1
    fi
    key_args+=(--ed-key-file "$SPARKLE_KEY_FILE")
fi

"$GENERATE_APPCAST" \
    --download-url-prefix "$download_url_prefix/v$version/" \
    ${key_args[@]+"${key_args[@]}"} \
    "$staging_dir"

generated_appcast="$staging_dir/appcast.xml"
if [[ ! -f "$generated_appcast" ]]; then
    echo "Error: generate_appcast did not produce appcast.xml in staging directory." >&2
    exit 1
fi

# --- Validate generated appcast ---
echo "Validating generated appcast..."

# XML well-formedness
if ! xmllint --noout "$generated_appcast" 2>&1; then
    echo "Error: Generated appcast.xml is not well-formed XML." >&2
    exit 1
fi

# Validate required Sparkle fields using namespace-aware XML queries.
# Sparkle 2.9.6 represents sparkle:version and sparkle:shortVersionString as XML
# elements (not enclosure attributes), while edSignature, url, and length are
# enclosure attributes. This validator handles both representations robustly.
validate_appcast() {
    local appcast_file="$1"
    local expected_version="$2"
    local errors=0

    # Helper: extract text via xmllint --xpath; returns empty string on failure.
    xpath_text() {
        xmllint --xpath "$1" "$appcast_file" 2>/dev/null || true
    }

    # --- Enclosure URL (attribute on <enclosure>) ---
    local enc_url
    enc_url="$(xpath_text 'string(//*[local-name()="enclosure"]/@url)')"
    if [[ -z "$enc_url" ]]; then
        echo "Error: appcast.xml missing enclosure url attribute." >&2
        errors=$((errors + 1))
    elif [[ "$enc_url" != *"$dmg_filename"* ]]; then
        echo "Error: enclosure url does not reference expected DMG '$dmg_filename': $enc_url" >&2
        errors=$((errors + 1))
    fi

    # --- Enclosure length (attribute on <enclosure>) ---
    local enc_length
    enc_length="$(xpath_text 'string(//*[local-name()="enclosure"]/@length)')"
    if [[ -z "$enc_length" || "$enc_length" == "0" ]]; then
        echo "Error: appcast.xml missing or zero enclosure length attribute." >&2
        errors=$((errors + 1))
    fi

    # --- EdDSA signature: may be an enclosure attribute OR a sparkle:edSignature element ---
    local ed_sig
    ed_sig="$(xpath_text 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])')"
    if [[ -z "$ed_sig" ]]; then
        # Fallback: check for <sparkle:edSignature> element inside <item>
        ed_sig="$(xpath_text 'string(//*[local-name()="item"][1]/*[local-name()="edSignature"])')"
    fi
    if [[ -z "$ed_sig" ]]; then
        echo "Error: appcast.xml missing EdDSA signature (sparkle:edSignature)." >&2
        errors=$((errors + 1))
    fi

    # --- Build version (CFBundleVersion): element or enclosure attribute ---
    local build_ver
    # Try element first: <sparkle:version>N</sparkle:version>
    build_ver="$(xpath_text 'string(//*[local-name()="item"][1]/*[local-name()="version"])')"
    if [[ -z "$build_ver" ]]; then
        # Fallback: sparkle:version attribute on <enclosure>
        build_ver="$(xpath_text 'string(//*[local-name()="enclosure"]/@*[local-name()="version"])')"
    fi
    if [[ -z "$build_ver" ]]; then
        echo "Error: appcast.xml missing build version (sparkle:version element or attribute)." >&2
        errors=$((errors + 1))
    fi

    # --- Short version string validation (marketing version) ---
    local short_ver
    short_ver="$(xpath_text 'string(//*[local-name()="item"][1]/*[local-name()="shortVersionString"])')"
    if [[ -z "$short_ver" ]]; then
        # Fallback: sparkle:shortVersionString attribute on <enclosure>
        short_ver="$(xpath_text 'string(//*[local-name()="enclosure"]/@*[local-name()="shortVersionString"])')"
    fi
    if [[ -n "$expected_version" && -n "$short_ver" && "$short_ver" != "$expected_version" ]]; then
        echo "Error: appcast shortVersionString '$short_ver' does not match expected '$expected_version'." >&2
        errors=$((errors + 1))
    fi

    # --- Expected download URL prefix check ---
    if [[ -n "$expected_version" && -n "$enc_url" ]]; then
        local expected_url_fragment="v$expected_version/"
        if [[ "$enc_url" != *"$expected_url_fragment"* ]]; then
            echo "Error: enclosure url does not contain expected version path '$expected_url_fragment': $enc_url" >&2
            errors=$((errors + 1))
        fi
    fi

    return $errors
}

if ! validate_appcast "$generated_appcast" "$version"; then
    echo "Error: Appcast validation failed. See errors above." >&2
    exit 1
fi

echo "Appcast validation passed."

# --- Copy validated appcast to docs/ ---
cp "$generated_appcast" "$docs_appcast"
echo ""
echo "Updated: $docs_appcast"
echo ""
echo "Version: $version (build $build)"
echo "DMG:     $dmg_filename"
echo "URL:     $download_url"
echo ""
echo "Next steps:"
echo "  1. Review the updated docs/appcast.xml"
echo "  2. Commit and push to dev (or include in the release commit)"
echo "  3. After merge to main, GitHub Pages will serve the updated feed"
