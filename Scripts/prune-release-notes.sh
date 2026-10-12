#!/usr/bin/env bash
# Prune release-note files that are no longer used, so docs/ and release-notes/
# do not pile up with every release.
#
#   docs/Chap-<version>-<build>.md   Sparkle update-window notes. Only the ones
#                                    docs/appcast.xml links to are kept.
#   release-notes/<version>.md       GitHub Release bodies. The newest
#                                    $KEEP_RELEASE_NOTES (default 10) are kept,
#                                    plus the version passed as $1 if given.
#
# Deletions are staged with `git rm` so the caller's commit picks them up.
# Already-published GitHub Releases keep their bodies on GitHub, and every
# deleted file stays in git history.
#
# Usage: Scripts/prune-release-notes.sh [current-version]
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

current_version="${1:-}"
keep="${KEEP_RELEASE_NOTES:-10}"
appcast="docs/appcast.xml"

if [[ ! -f "$appcast" ]]; then
  echo "prune-release-notes: $appcast not found; nothing pruned." >&2
  exit 0
fi

removed=0

# --- docs/Chap-*.md not linked from the appcast ---
shopt -s nullglob
for note in docs/Chap-*.md; do
  name="$(basename "$note")"
  if ! grep -Fq "/$name<" "$appcast"; then
    git rm -q --cached -- "$note" 2>/dev/null || true
    rm -f -- "$note"
    removed=$((removed + 1))
  fi
done

# --- release-notes/<version>.md beyond the newest $keep ---
notes=()
while IFS= read -r line; do notes+=("$line"); done < <(
  for file in release-notes/*.md; do basename "$file" .md; done | sort -t. -k1,1nr -k2,2nr -k3,3nr
)
index=0
for version in "${notes[@]}"; do
  index=$((index + 1))
  [[ "$version" == "$current_version" ]] && continue
  if ((index > keep)); then
    git rm -q --cached -- "release-notes/$version.md" 2>/dev/null || true
    rm -f -- "release-notes/$version.md"
    removed=$((removed + 1))
  fi
done

echo "prune-release-notes: removed $removed file(s)."
