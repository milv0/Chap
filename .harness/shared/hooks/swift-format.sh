#!/bin/bash
# Format and lint Swift files after edits.
# Shared between Claude Code (PostToolUse) and Kiro (fileEdited hook).
#
# Inputs (in priority order):
#   $CLAUDE_FILE_PATHS  — Claude Code, space-separated paths
#   $KIRO_FILE_PATH     — Kiro, single file path (currently not provided by Kiro)
#   $1                  — CLI argument, single file (manual invocation)
#
# Fallback when no input is provided (Kiro fileEdited triggers):
#   - Discovers changed .swift files via git diff + untracked files
#
# Actions:
#   - `xcrun swift-format -i` on each .swift file (in-place format)
#   - `xcrun swift-format lint` and report warnings (non-blocking)

set -u

INPUT="${CLAUDE_FILE_PATHS:-${KIRO_FILE_PATH:-${1:-}}}"

if [ -n "$INPUT" ]; then
    SWIFT_FILES=$(echo "$INPUT" | tr ' ' '\n' | grep '\.swift$' || true)
else
    # Fallback: discover changed Swift files via git
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$REPO_ROOT" ]; then
        exit 0
    fi
    cd "$REPO_ROOT" || exit 0
    CHANGED=$(git diff --name-only --diff-filter=ACMR HEAD -- '*.swift' 2>/dev/null || true)
    UNTRACKED=$(git ls-files --others --exclude-standard -- '*.swift' 2>/dev/null || true)
    SWIFT_FILES=$(printf '%s\n%s\n' "$CHANGED" "$UNTRACKED" | grep -v '^$' | sort -u || true)
fi

if [ -z "$SWIFT_FILES" ]; then
    exit 0
fi

# Format in-place
echo "$SWIFT_FILES" | while IFS= read -r file; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue
    xcrun swift-format -i "$file" 2>&1 || echo "[swift-format] format failed: $file" >&2
done

# Lint (warnings only, non-blocking)
LINT_OUTPUT=""
while IFS= read -r file; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue
    OUT=$(xcrun swift-format lint "$file" 2>&1 || true)
    [ -n "$OUT" ] && LINT_OUTPUT="${LINT_OUTPUT}${OUT}\n"
done <<< "$SWIFT_FILES"

if [ -n "$LINT_OUTPUT" ]; then
    echo "[swift-format lint warnings]"
    echo -e "$LINT_OUTPUT"
fi

exit 0
