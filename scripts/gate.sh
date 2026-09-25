#!/usr/bin/env bash
# Fail when the outcome-change rate exceeds the fail-on threshold.
set -euo pipefail
[ "$CR_FAIL_ON" = "never" ] && exit 0
limit="${CR_FAIL_ON#outcome-change:}"; limit="${limit%\%}"
if awk -v r="$CR_RATE" -v l="$limit" 'BEGIN { exit !(r > l) }'; then
  echo "::error::ConeReplay: outcome-change rate ${CR_RATE}% is above the ${limit}% threshold"
  exit 1
fi
echo "ConeReplay: outcome-change rate ${CR_RATE}% is within the ${limit}% threshold"
