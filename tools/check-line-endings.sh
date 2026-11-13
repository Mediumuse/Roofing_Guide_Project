#!/usr/bin/env bash
# check-line-endings.sh — pre-flight line-ending check for agent sessions.
#
# Detects CRLF/LF churn in text files that would pollute diffs and cause an
# agent to loop "fixing" whitespace-only changes. Exits 0 when the tree is
# clean, 1 when CRLF text files are found (circuit breaker), 2 on error.
#
# Usage:
#   ./tools/check-line-endings.sh            # audit only (reports, no edit)
#   ./tools/check-line-endings.sh --fix      # normalise CRLF -> LF in-place
#   ./tools/check-line-endings.sh --strict   # audit; fail (exit 1) on any CRLF
#
# Requires: git (with core.autocrlf=input and a .gitattributes enforcing eol=lf).

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.." || { echo "E: cannot cd to project root"; exit 2; }

FIX=0
STRICT=0
if [[ "${1:-}" == "--fix" ]]; then FIX=1; fi
if [[ "${1:-}" == "--strict" ]]; then STRICT=1; fi

# Files Git tracks. Cache the index listing once so we never diff the working
# tree twice inside one run (that is a source of churn).
mapfile -t TRACKED < <(git ls-files -- '.')

CRLF=()
for f in "${TRACKED[@]}"; do
  # git show "$f" outputs the blob in LF; to test the working tree we use the
  # working-tree path directly. Skip paths that don't exist on disk.
  if [[ ! -e "$f" ]]; then
    continue
  fi
  if file -b "$f" | grep -qE 'CRLF|with CR line terminators|with CRLF'; then
    CRLF+=("$f")
  fi
done

if [[ ${#CRLF[@]} -eq 0 ]]; then
  echo "OK: no CRLF text files found in the tracked tree."
  exit 0
fi

echo "FAIL: ${#CRLF[@]} tracked file(s) still use CRLF (should be LF):"
for f in "${CRLF[@]}"; do
  echo "  - $f"
done

if [[ "$FIX" == "1" ]]; then
  echo "  -> Normalising to LF (git add -A enforces .gitattributes eol=lf)."
  git add -A
  git diff --cached --ignore-cr-at-eol --quiet -- || true
  echo "  -> Done. Re-run this script to confirm."
  exit 0
fi

if [[ "$STRICT" == "1" ]]; then
  echo "  -> Strict mode: aborting agent session."
  exit 1
fi

exit 1
