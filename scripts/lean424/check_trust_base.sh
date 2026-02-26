#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${1:-origin/master}"
HEAD_REF="${2:-HEAD}"
PATHSPEC="${3:-EvmEquivalence}"

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "error: base ref '$BASE_REF' does not exist" >&2
  exit 2
fi

if ! git rev-parse --verify "$HEAD_REF" >/dev/null 2>&1; then
  echo "error: head ref '$HEAD_REF' does not exist" >&2
  exit 2
fi

HITS="$(
  git diff "$BASE_REF...$HEAD_REF" -- "$PATHSPEC" \
    | rg -n '^\+[^+].*\b(private axiom|axiom|sorry)\b' || true
)"

if [ -n "$HITS" ]; then
  echo "trust-base gate failed: added forbidden tokens in diff ($BASE_REF...$HEAD_REF):" >&2
  printf '%s\n' "$HITS" >&2
  exit 1
fi

echo "trust-base gate passed: no added 'sorry'/'axiom'/'private axiom' tokens in $BASE_REF...$HEAD_REF"
