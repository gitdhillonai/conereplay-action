#!/usr/bin/env bash
# Fail when the outcome-change rate is above the fail-on threshold.
# Valid values: "never" or "outcome-change:<number>%" (example: outcome-change:5%).
# Exit 0 when fail-on is never, or the rate is less than or equal to the threshold.
# Exit 1 when the rate is above the threshold.
# Exit 2 when fail-on or the rate is not a valid value.
set -euo pipefail

if [ "${CR_FAIL_ON:-}" = "never" ]; then
  echo "ConeReplay: fail-on is never; reporting only"
  exit 0
fi

if [[ ! "${CR_FAIL_ON:-}" =~ ^outcome-change:([0-9]+([.][0-9]+)?)%$ ]]; then
  echo "::error::ConeReplay: invalid fail-on '${CR_FAIL_ON:-}'. Expected never or outcome-change:<number>% (example: outcome-change:5%)."
  exit 2
fi
limit="${BASH_REMATCH[1]}"

if [[ ! "${CR_RATE:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "::error::ConeReplay: outcome-change rate '${CR_RATE:-}' is not a number"
  exit 2
fi

# Strictly above the threshold. An equal rate stays within it.
if awk -v r="$CR_RATE" -v l="$limit" 'BEGIN { exit !(r > l) }'; then
  echo "::error::ConeReplay: outcome-change rate ${CR_RATE}% is above the ${limit}% threshold"
  exit 1
fi
echo "ConeReplay: outcome-change rate ${CR_RATE}% is within the ${limit}% threshold"
