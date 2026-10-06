#!/usr/bin/env bash
# Run every action test. Requires bash, jq, and conereplay==0.1.2 on PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for test in "$ROOT"/tests/test_*.sh; do
  echo "== $(basename "$test")"
  if bash "$test"; then
    echo
  else
    echo "FAILED $(basename "$test")" >&2
    fail=1
  fi
done
exit "$fail"
