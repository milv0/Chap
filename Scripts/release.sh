#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Scripts/release.sh <version> [--publish | --resume]

Without flags, runs a read-only preflight and prints the release plan.
With --publish, updates version metadata, validates the app, promotes dev to
main, tags the release, builds/notarizes PKG and DMG artifacts, publishes the
GitHub Release, and waits for GitHub Pages to build the promoted main commit.

With --resume, resumes artifact build/notarization/publishing for a version
whose tag already exists but whose GitHub Release was never created (e.g. after
a notarization failure). Strict preconditions are enforced:
  • Clean dev matching origin/dev
  • Supplied version matches the app's current MARKETING_VERSION
  • Local and remote annotated tag v<version> exists
  • Tag is an ancestor of current main
  • GitHub Release does not already exist
  • No version bump, tag creation, or branch promotion is performed

Release notes are read from release-notes/<version>.md (must exist before
--publish or --resume). The file contents become the GitHub Release body.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 64
fi

version="$1"
publish=false
resume=false
if [[ $# -eq 2 ]]; then
  case "$2" in
    --publish) publish=true ;;
    --resume)  resume=true ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
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
if ! [[ "$current_build" =~ ^[1-9][0-9]*$ ]]; then
  echo "CURRENT_PROJECT_VERSION must be a positive integer: $current_build" >&2
  exit 65
fi
next_build=$((current_build + 1))

if $resume; then
  # --resume: strict precondition validation for resuming a failed release.
  # This mode ONLY builds/notarizes/publishes artifacts for an existing tag
  # whose GitHub Release was never created (e.g. notarization failure).
  # It never bumps versions, creates tags, or promotes branches.

  if [[ "$current_version" != "$version" ]]; then
    echo "--resume: app MARKETING_VERSION ($current_version) does not match $version." >&2
    echo "This version was not bumped. Cannot resume a release that was not started." >&2
    exit 65
  fi

  require_clean_worktree
  require_identity codesigning "Developer ID Application"
  require_identity basic "Developer ID Installer"

  # Verify dev matches origin/dev
  remote_dev="$(git ls-remote origin refs/heads/dev | awk '{print $1}')"
  if [[ -z "$remote_dev" || "$(git rev-parse HEAD)" != "$remote_dev" ]]; then
    echo "--resume: local dev must match origin/dev." >&2
    exit 65
  fi

  # Verify local annotated tag exists
  if ! git show-ref --verify --quiet "refs/tags/v$version"; then
    echo "--resume: local tag v$version does not exist." >&2
    exit 65
  fi
  tag_type="$(git cat-file -t "v$version")"
  if [[ "$tag_type" != "tag" ]]; then
    echo "--resume: v$version is not an annotated tag (found: $tag_type)." >&2
    exit 65
  fi

  # Verify remote tag exists
  if ! git ls-remote --exit-code --tags origin "v$version" >/dev/null 2>&1; then
    echo "--resume: remote tag v$version does not exist on origin." >&2
    exit 65
  fi

  # Verify tag is an ancestor of current main
  tag_commit="$(git rev-list -n1 "v$version")"
  main_head="$(git rev-parse origin/main)"
  if ! git merge-base --is-ancestor "$tag_commit" "$main_head"; then
    echo "--resume: tag v$version is not an ancestor of main." >&2
    exit 65
  fi

  # Verify GitHub Release does NOT already exist
  if gh release view "v$version" --repo milv0/Chap >/dev/null 2>&1; then
    echo "--resume: GitHub Release v$version already exists. Nothing to resume." >&2
    exit 65
  fi

  release_notes_file="$root_dir/release-notes/$version.md"
  if [[ ! -f "$release_notes_file" ]]; then
    echo "--resume: missing release notes: $release_notes_file" >&2
    exit 65
  fi

  printf 'Resume preconditions passed for v%s.\n' "$version"
  printf 'Tag v%s exists at %s. GitHub Release not yet created.\n' "$version" "$tag_commit"
  printf 'Resuming artifact build and publication...\n\n'

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

  # --- Sparkle appcast generation ---
  # Appcast must be committed on main for GitHub Pages. Switch to main, generate
  # the feed entry, commit/push, then fast-forward dev to keep branches in sync.
  # This mirrors the normal --publish appcast flow.
  if [[ -n "${SPARKLE_BIN_DIR:-}" || -n "${SPARKLE_GENERATE_APPCAST:-}" ]]; then
    git switch main
    Scripts/generate-appcast.sh "$dmg_path"
    git add -- docs/appcast.xml
    git diff --staged --quiet docs/appcast.xml || {
      git commit -m "docs(appcast): add v$version update entry"
      git push origin main
      main_commit="$(git rev-parse HEAD)"
      # Synchronize dev to include the appcast commit so branches do not diverge.
      # main is a direct descendant of dev HEAD (pre-resume they are equal, plus
      # the appcast commit), so dev can always fast-forward here.
      git switch dev
      if ! git merge --ff-only main; then
        echo "Error: dev cannot fast-forward to main after appcast commit." >&2
        echo "This indicates branch divergence that must be resolved manually." >&2
        exit 1
      fi
      git push origin dev
    }
    # Ensure we are back on dev for the remainder of the resume flow.
    git switch dev
  else
    echo "Note: Sparkle appcast not updated (SPARKLE_BIN_DIR/SPARKLE_GENERATE_APPCAST not set)."
    echo "Run Scripts/generate-appcast.sh manually after release to update the feed."
  fi

  main_commit="${main_commit:-$(git rev-parse origin/main)}"

  gh release create "v$version" "$pkg_path" "$dmg_path" \
    --repo milv0/Chap \
    --title "Chap $version" \
    --notes-file "$release_notes_file"
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
fi

if [[ "$current_version" == "$version" ]]; then
  echo "Version is already $version; choose a new release version." >&2
  exit 65
fi

# Release notes must exist for the target version.
release_notes_file="$root_dir/release-notes/$version.md"
if [[ ! -f "$release_notes_file" ]]; then
  echo "Missing release notes: $release_notes_file" >&2
  echo "Create it before running the release." >&2
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

To resume a failed release whose tag exists but GitHub Release does not:
  Scripts/release.sh $version --resume

Publish will:
  1. Update $current_version (build $current_build) → $version (build $next_build) in app, README, and Pages download URLs.
  2. Run XcodeGen, Swift format/lint, tests, Debug build, and diff checks.
  3. Commit/push dev, merge dev into main, and push annotated tag v$version.
  4. Build and notarize PKG primary installer plus DMG fallback.
  5. Create GitHub Release v$version and wait for GitHub Pages to build main.

Release notes ($release_notes_file):
$(cat "$release_notes_file")
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
    && -z "$(git status --porcelain)" ]] \
    && ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
    git switch "$starting_branch" >/dev/null
  fi
}
trap restore_branch EXIT

VERSION="$version" CURRENT_VERSION="$current_version" CURRENT_BUILD_NUMBER="$current_build" BUILD_NUMBER="$next_build" python3 - <<'PY'
import os, sys
from pathlib import Path

old = os.environ["CURRENT_VERSION"]
new = os.environ["VERSION"]
current_build = os.environ["CURRENT_BUILD_NUMBER"]
build = os.environ["BUILD_NUMBER"]

# Each entry: (file, old_string, new_string, required)
# required=True means exactly-one occurrence is mandatory; the script aborts if
# the count is not 1.  required=False means 0 occurrences are silently skipped
# (the target may not exist yet because another agent is adding it).
replacements: list[tuple[Path, str, str, bool]] = [
    # --- project.yml: app version ---
    (Path("project.yml"),
     f'MARKETING_VERSION: "{old}"',
     f'MARKETING_VERSION: "{new}"',
     True),
    (Path("project.yml"),
     f'CURRENT_PROJECT_VERSION: "{current_build}"',
     f'CURRENT_PROJECT_VERSION: "{build}"',
     True),

    # --- Models.swift: fallback version string ---
    (Path("Sources/ChapCore/Models.swift"),
     f'?? "{old}"',
     f'?? "{new}"',
     True),

    # --- README.md: badge ---
    (Path("README.md"),
     f"version-{old}-orange",
     f"version-{new}-orange",
     True),

    # --- README.md: release command example (preflight) ---
    # The standalone line includes a trailing newline to avoid matching the
    # substring inside the "--publish" line.
    (Path("README.md"),
     f"Scripts/release.sh {old}\n",
     f"Scripts/release.sh {new}\n",
     True),

    # --- README.md: release command example (publish) ---
    (Path("README.md"),
     f"Scripts/release.sh {old} --publish",
     f"Scripts/release.sh {new} --publish",
     True),

    # --- docs/index.html: PKG download URL ---
    (Path("docs/index.html"),
     f"releases/download/v{old}/Chap-{old}-{current_build}.pkg",
     f"releases/download/v{new}/Chap-{new}-{build}.pkg",
     True),

    # --- docs/index.html: DMG download URL ---
    (Path("docs/index.html"),
     f"releases/download/v{old}/Chap-{old}-{current_build}.dmg",
     f"releases/download/v{new}/Chap-{new}-{build}.dmg",
     True),

    # --- docs/index.html: footer version text ---
    (Path("docs/index.html"),
     f"Chap {old} · macOS",
     f"Chap {new} · macOS",
     True),
]

# Pass 1: validate all targets before mutating any file.
errors: list[str] = []
for path, before, _after, required in replacements:
    if not path.exists():
        errors.append(f"File not found: {path}")
        continue
    text = path.read_text()
    count = text.count(before)
    if required and count != 1:
        errors.append(
            f"Expected exactly 1 occurrence of {before!r} in {path}, found {count}")
    elif not required and count > 1:
        errors.append(
            f"Expected 0 or 1 occurrences of {before!r} in {path}, found {count}")

if errors:
    print("Version bump validation failed:", file=sys.stderr)
    for e in errors:
        print(f"  • {e}", file=sys.stderr)
    sys.exit(1)

# Pass 2: apply replacements (files may appear multiple times; accumulate edits).
file_contents: dict[Path, str] = {}
for path, before, after, required in replacements:
    if path not in file_contents:
        file_contents[path] = path.read_text()
    text = file_contents[path]
    count = text.count(before)
    if count == 0 and not required:
        print(f"  [skip] {before!r} not found in {path} (optional)")
        continue
    file_contents[path] = text.replace(before, after)
    print(f"  [ok]   {path}: {before!r} → {after!r}")

for path, text in file_contents.items():
    path.write_text(text)

print(f"\nVersion surfaces updated: {old} (build {current_build}) → {new} (build {build})")
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

# --- Sparkle appcast generation ---
# Update docs/appcast.xml with a signed entry for the notarized DMG.
# This runs before the GitHub Release so the appcast commit can be included.
# The generate-appcast script requires SPARKLE_BIN_DIR or SPARKLE_GENERATE_APPCAST.
if [[ -n "${SPARKLE_BIN_DIR:-}" || -n "${SPARKLE_GENERATE_APPCAST:-}" ]]; then
  Scripts/generate-appcast.sh "$dmg_path"
  git add -- docs/appcast.xml
  git diff --staged --quiet docs/appcast.xml || {
    git commit -m "docs(appcast): add v$version update entry"
    git push origin main
    main_commit="$(git rev-parse HEAD)"
    # Synchronize dev to include the appcast commit so branches do not diverge.
    # main is a direct descendant of the pre-release dev HEAD (merge commit + optional
    # appcast commit), so dev can always fast-forward here. If it cannot, the release
    # invariants were violated; fail with an actionable error rather than force-push.
    git switch dev
    if ! git merge --ff-only main; then
      echo "Error: dev cannot fast-forward to main after appcast commit." >&2
      echo "This indicates branch divergence that must be resolved manually." >&2
      exit 1
    fi
    git push origin dev
    git switch main
  }
else
  echo "Note: Sparkle appcast not updated (SPARKLE_BIN_DIR/SPARKLE_GENERATE_APPCAST not set)."
  echo "Run Scripts/generate-appcast.sh manually after release to update the feed."
fi

gh release create "v$version" "$pkg_path" "$dmg_path" \
  --repo milv0/Chap \
  --title "Chap $version" \
  --notes-file "$release_notes_file"

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
