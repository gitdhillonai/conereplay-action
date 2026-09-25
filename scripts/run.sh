#!/usr/bin/env bash
# Run conereplay replay (single file) or corpus (dir/glob) and export the outcome-change rate.
set -euo pipefail
log="$(mktemp)"
if [ -f "$CR_TRACES" ]; then
  conereplay replay --trace "$CR_TRACES" --modify "$CR_MODIFY" --report "$CR_REPORT" 2> >(tee "$log" >&2)
  wait
  if grep -q 'outcome_changed=True' "$log"; then rate=100; else rate=0; fi
else
  # shellcheck disable=SC2086
  conereplay corpus --traces $CR_TRACES --modify "$CR_MODIFY" --report "$CR_REPORT" --format markdown 2> >(tee "$log" >&2)
  wait
  rate="$(grep -oE 'outcome_change_rate=[0-9.]+' "$log" | tail -1 | cut -d= -f2)"
fi
[ -n "${rate:-}" ] || { echo "conereplay: could not read the outcome-change rate" >&2; exit 1; }
echo "report=$CR_REPORT" >> "$GITHUB_OUTPUT"
echo "rate=$rate" >> "$GITHUB_OUTPUT"
{ echo "### ConeReplay: outcome-change rate ${rate}%"; echo; cat "$CR_REPORT"; } >> "$GITHUB_STEP_SUMMARY"
