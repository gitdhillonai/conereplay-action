#!/usr/bin/env bash
# Run conereplay replay (single file) or corpus (directory or glob) and export the outcome-change rate.
# A glob is passed through quoted. conereplay expands file, directory, and glob specs itself.
set -euo pipefail

: "${CR_TRACES:?CR_TRACES is required}"
: "${CR_MODIFY:?CR_MODIFY is required}"
: "${CR_REPORT:?CR_REPORT is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"

log="$(mktemp)"
stdout="$(mktemp)"
set +e
if [ -f "$CR_TRACES" ]; then
  mode="replay"
  conereplay replay --trace "$CR_TRACES" --modify "$CR_MODIFY" --report "$CR_REPORT" >"$stdout" 2>"$log"
else
  mode="corpus"
  conereplay corpus --traces "$CR_TRACES" --modify "$CR_MODIFY" --report "$CR_REPORT" --format markdown >"$stdout" 2>"$log"
fi
rc=$?
set -e
cat "$log" >&2
if [ "$rc" -ne 0 ]; then
  exit "$rc"
fi

if [ "$mode" = "replay" ]; then
  if grep -q 'outcome_changed=True' "$log"; then
    rate=100
  else
    rate=0
  fi
else
  rate="$(grep -oE 'outcome_change_rate=[0-9.]+' "$log" | tail -n 1 | cut -d= -f2 || true)"
  rate="${rate%%%}"
fi
if [ -z "${rate:-}" ]; then
  echo "conereplay: could not read the outcome-change rate" >&2
  exit 1
fi
if [[ ! "$rate" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "conereplay: outcome-change rate '${rate}' is not a number" >&2
  exit 1
fi

echo "report=$CR_REPORT" >> "$GITHUB_OUTPUT"
echo "rate=$rate" >> "$GITHUB_OUTPUT"
{
  echo "### ConeReplay: outcome-change rate ${rate}%"
  echo
  cat "$CR_REPORT"
} >> "$GITHUB_STEP_SUMMARY"
