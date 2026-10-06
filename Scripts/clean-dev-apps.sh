#!/usr/bin/env bash
# Remove every Chap.app copy except the installed /Applications/Chap.app.
#
# Builds, tests, and the offscreen renderer leave a Debug Chap.app in DerivedData,
# and releases leave intermediates (xcarchive, export, dmg-root) in build/release.
# Those copies share ~/.chap.json with the installed app, so a stale or newer copy
# can write settings the installed version can't read. Run this at the end of each
# task. Installers (*.pkg, *.dmg) are kept.
#
# Usage: Scripts/clean-dev-apps.sh [--dry-run]
set -euo pipefail

dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
installed=/Applications/Chap.app

targets=()
while IFS= read -r path; do
    [[ -n "$path" && "$path" != "$installed" ]] && targets+=("$path")
done < <(
    {
        find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 5 \
            -path "*/Chap-*/Build/Products/*/Chap.app" -type d 2>/dev/null
        mdfind 'kMDItemCFBundleIdentifier == "com.mingyupark.Chap"' 2>/dev/null
    } | sort -u
)

for dir in "$repo_root/build/release/Chap.xcarchive" "$repo_root/build/release/export" \
    "$repo_root/build/release/dmg-root"; do
    [[ -e "$dir" ]] && targets+=("$dir")
done

if [[ ${#targets[@]} -eq 0 ]]; then
    echo "Nothing to remove; only $installed remains."
    exit 0
fi

for path in "${targets[@]}"; do
    # Only touch Chap copies under the user's home or this repo, never /Applications.
    case "$path" in
        "$HOME"/*) ;;
        *) echo "skip (outside home): $path"; continue ;;
    esac
    if $dry_run; then
        echo "would remove: $path"
        continue
    fi
    pkill -f "$path/Contents/MacOS/Chap" 2>/dev/null || true
    [[ "$path" == *.app ]] && "$lsregister" -u "$path" 2>/dev/null || true
    rm -rf "$path"
    echo "removed: $path"
done
