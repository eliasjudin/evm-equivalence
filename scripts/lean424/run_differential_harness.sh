#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: scripts/lean424/run_differential_harness.sh <base-worktree> [candidate-worktree]" >&2
  echo "optional: set HARNESS_FILE=/abs/path/to/DifferentialHarness.lean" >&2
  exit 2
fi

BASE_DIR="$1"
CAND_DIR="${2:-$(pwd)}"
HARNESS_FILE="${HARNESS_FILE:-$CAND_DIR/scripts/lean424/DifferentialHarness.lean}"

for d in "$BASE_DIR" "$CAND_DIR"; do
  if [ ! -d "$d" ]; then
    echo "error: directory does not exist: $d" >&2
    exit 2
  fi
done

if [ ! -f "$HARNESS_FILE" ]; then
  echo "error: harness file does not exist: $HARNESS_FILE" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lean424-diff.XXXXXX")"
if [ "${KEEP_TMP_DIR:-0}" = "1" ]; then
  echo "[lean424] keeping temporary directory: $TMP_DIR"
else
  trap 'rm -rf "$TMP_DIR"' EXIT
fi

run_side() {
  local label="$1"
  local dir="$2"
  local log_file="$TMP_DIR/$label.log"
  local out_file="$TMP_DIR/$label.out"

  if [ "${LEAN424_CLEAN:-1}" = "1" ]; then
    echo "[lean424] cleaning $label build artifacts"
    (cd "$dir" && /Users/elias/.elan/bin/lake clean >>"$log_file" 2>&1)
  fi

  echo "[lean424] building $label: $dir"
  if ! (cd "$dir" && /Users/elias/.elan/bin/lake build EvmEquivalence >"$log_file" 2>&1); then
    echo "[lean424] build failed for $label; log: $log_file" >&2
    cat "$log_file" >&2
    return 1
  fi

  echo "[lean424] running differential harness on $label"
  if ! (cd "$dir" && /Users/elias/.elan/bin/lake env lean "$HARNESS_FILE" >"$out_file" 2>>"$log_file"); then
    echo "[lean424] harness execution failed for $label; log: $log_file" >&2
    if [ -s "$out_file" ]; then
      cat "$out_file" >&2
    fi
    cat "$log_file" >&2
    return 1
  fi
}

run_side "base" "$BASE_DIR"
run_side "candidate" "$CAND_DIR"

echo "[lean424] comparing snapshots"
if diff -u "$TMP_DIR/base.out" "$TMP_DIR/candidate.out"; then
  echo "[lean424] semantic snapshot gate passed: no output deltas"
else
  echo "[lean424] semantic snapshot gate failed: output deltas detected" >&2
  exit 1
fi
