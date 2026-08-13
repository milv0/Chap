#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Scripts/release.sh <version> [--publish]

Without --publish, runs a read-only preflight and prints the release plan.
With --publish, updates version metadata, validates the app, promotes dev to
main, tags the release, builds/notarizes PKG and DMG artifacts, publishes the
GitHub Release, and waits for GitHub Pages to build the promoted main commit.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 64
fi

version="$1"
publish=false
if [[ $# -eq 2 ]]; then
  if [[ "$2" != "--publish" ]]; then
    usage >&2
    exit 64
  fi
  publish=true
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use MAJOR.MINOR.PATCH format: $version" >&2
  exit 64
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

for command in git gh xcodegen xcodebuild xcrun security python3; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 69
  }
done

require_clean_worktree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Release requires a clean working tree." >&2
    exit 65
  fi
}

require_identity() {
  local policy="$1"
  local identity="$2"
  if ! security find-identity -v -p "$policy" | grep -Fq "\"$identity"; then
    echo "Missing signing identity: $identity" >&2
    exit 69
  fi
}

ensure_release_does_not_exist() {
  if git show-ref --verify --quiet "refs/tags/v$version" \
    || git ls-remote --exit-code --tags origin "v$version" >/dev/null 2>&1; then
    echo "Tag v$version already exists." >&2
    exit 65
  fi
  if gh release view "v$version" --repo milv0/Chap >/dev/null 2>&1; then
    echo "GitHub Release v$version already exists." >&2
    exit 65
  fi
}

current_version="$(python3 - <<'PY'
import re
from pathlib import Path
source = Path("project.yml").read_text()
match = re.search(r'MARKETING_VERSION: "([0-9]+\.[0-9]+\.[0-9]+)"', source)
if not match:
    raise SystemExit("Unable to read MARKETING_VERSION from project.yml")
print(match.group(1))
PY
)"
current_build="$(python3 - <<'PY'
import re
from pathlib import Path
source = Path("project.yml").read_text()
match = re.search(r'CURRENT_PROJECT_VERSION: "([0-9]+)"', source)
if not match:
    raise SystemExit("Unable to read CURRENT_PROJECT_VERSION from project.yml")
print(match.group(1))
PY
)"

if [[ "$current_version" == "$version" ]]; then
  echo "Version is already $version; choose a new release version." >&2
  exit 65
fi

require_clean_worktree
ensure_release_does_not_exist
require_identity codesigning "Developer ID Application"
require_identity basic "Developer ID Installer"

if ! $publish; then
  cat <<EOF
Release preflight passed for v$version.

This was read-only. Daily development remains dev-only: commit and push dev.
To publish, run from the clean, origin-synced dev branch:
  Scripts/release.sh $version --publish

Publish will:
  1. Update $current_version → $version in app, README, and Pages download URLs.
  2. Run XcodeGen, Swift format/lint, tests, Debug build, and diff checks.
  3. Commit/push dev, merge dev into main, and push annotated tag v$version.
  4. Build and notarize PKG primary installer plus DMG fallback.
  5. Create GitHub Release v$version and wait for GitHub Pages to build main.
EOF
  exit 0
fi

if [[ "$(git branch --show-current)" != "dev" ]]; then
  echo "--publish must start on the dev branch." >&2
  exit 65
fi

remote_dev="$(git ls-remote origin refs/heads/dev | awk '{print $1}')"
if [[ -z "$remote_dev" || "$(git rev-parse HEAD)" != "$remote_dev" ]]; then
  echo "Local dev must match origin/dev before publishing." >&2
  exit 65
fi

starting_branch="dev"
restore_branch() {
  if [[ "$(git branch --show-current)" != "$starting_branch" \
    && -z "$(git status --porcelain)" \
    && ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
    git switch "$starting_branch" >/dev/null
  fi
}
trap restore_branch EXIT

VERSION="$version" CURRENT_VERSION="$current_version" BUILD_NUMBER="$current_build" python3 - <<'PY'
import os
from pathlib import Path

old = os.environ["CURRENT_VERSION"]
new = os.environ["VERSION"]
build = os.environ["BUILD_NUMBER"]
replacements = {
    Path("project.yml"): [(f'MARKETING_VERSION: "{old}"', f'MARKETING_VERSION: "{new}"')],
    Path("Sources/ChapCore/Models.swift"): [(f'?? "{old}"', f'?? "{new}"')],
    Path("README.md"): [(f'version-{old}-orange', f'version-{new}-orange')],
    Path("docs/index.html"): [
        (f'releases/download/v{old}/Chap-{old}-{build}.pkg', f'releases/download/v{new}/Chap-{new}-{build}.pkg'),
        (f'releases/download/v{old}/Chap-{old}-{build}.dmg', f'releases/download/v{new}/Chap-{new}-{build}.dmg'),
    ],
}
for path, changes in replacements.items():
    text = path.read_text()
    for before, after in changes:
        if text.count(before) != 1:
            raise SystemExit(f"Expected exactly one {before!r} in {path}")
        text = text.replace(before, after)
    path.write_text(text)
PY

xcodegen
xcrun swift-format format --configuration .swift-format --recursive --in-place Sources Tests
xcrun swift-format lint --configuration .swift-format --recursive Sources Tests
xcodebuild -project Chap.xcodeproj -scheme Chap -destination 'platform=macOS' test
xcodebuild -project Chap.xcodeproj -scheme Chap -configuration Debug -destination 'platform=macOS' build
git diff --check

git add -- project.yml Sources/ChapCore/Models.swift README.md docs/index.html
git diff --staged --check
git commit -m "build(release): bump version to $version"
git push origin dev

git switch main
git pull --ff-only origin main
git merge --no-ff --no-commit dev
if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  git diff --cached --check
  git commit -m "merge: release $version from dev"
fi
git push origin main

main_commit="$(git rev-parse HEAD)"
git tag -a "v$version" -m "Chap $version"
git push origin "v$version"

Scripts/build-release-pkg.sh
shopt -s nullglob
pkg_candidates=(build/release/Chap-"$version"-*.pkg)
dmg_candidates=(build/release/Chap-"$version"-*.dmg)
if [[ ${#pkg_candidates[@]} -ne 1 || ${#dmg_candidates[@]} -ne 1 ]]; then
  echo "Expected exactly one PKG and DMG artifact for version $version." >&2
  exit 1
fi
pkg_path="${pkg_candidates[0]}"
dmg_path="${dmg_candidates[0]}"
NOTARYTOOL_KEYCHAIN_PROFILE="${NOTARYTOOL_KEYCHAIN_PROFILE:-ChapNotary}" \
  Scripts/notarize-release-pkg.sh "$pkg_path"
NOTARYTOOL_KEYCHAIN_PROFILE="${NOTARYTOOL_KEYCHAIN_PROFILE:-ChapNotary}" \
  Scripts/notarize-release-dmg.sh "$dmg_path"

gh release create "v$version" "$pkg_path" "$dmg_path" \
  --repo milv0/Chap \
  --title "Chap $version" \
  --notes "Signed and notarized PKG primary installer with DMG manual-install fallback."

for attempt in $(seq 1 30); do
  build_json="$(gh api repos/milv0/Chap/pages/builds/latest)"
  build_commit="$(printf '%s' "$build_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["commit"])')"
  build_status="$(printf '%s' "$build_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["status"])')"
  if [[ "$build_commit" == "$main_commit" && "$build_status" == "built" ]]; then
    echo "GitHub Pages built main commit $main_commit."
    exit 0
  fi
  if [[ "$build_commit" == "$main_commit" && "$build_status" == "errored" ]]; then
    echo "GitHub Pages failed for main commit $main_commit." >&2
    exit 1
  fi
  sleep 10
done

echo "Timed out waiting for GitHub Pages to build main commit $main_commit." >&2
exit 1
