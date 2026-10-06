#!/usr/bin/env bash
# fail-on parser: valid values, invalid values, and exit codes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/scripts/gate.sh"
pass=0
fail=0

check() {
  local name="$1"
  local expected="$2"
  local rate="$3"
  local spec="$4"
  local output rc
  set +e
  output="$(CR_RATE="$rate" CR_FAIL_ON="$spec" bash "$GATE" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne "$expected" ]; then
    echo "FAIL $name: exit $rc, expected $expected" >&2
    printf '%s\n' "$output" >&2
    fail=$((fail + 1))
    return
  fi
  echo "ok $name (exit $rc)"
  pass=$((pass + 1))
}

check_contains() {
  local name="$1"
  local expected_rc="$2"
  local rate="$3"
  local spec="$4"
  local needle="$5"
  local output rc
  set +e
  output="$(CR_RATE="$rate" CR_FAIL_ON="$spec" bash "$GATE" 2>&1)"
  rc=$?
  set -e
  if [ "$rc" -ne "$expected_rc" ] || ! printf '%s\n' "$output" | grep -F -q "$needle"; then
    echo "FAIL $name: exit $rc (expected $expected_rc), output did not match" >&2
    printf '%s\n' "$output" >&2
    fail=$((fail + 1))
    return
  fi
  echo "ok $name"
  pass=$((pass + 1))
}

# Valid: never ignores the rate.
check "never with high rate" 0 100 never
check "never with zero" 0 0 never
check "never with decimal" 0 12.5 never

# Valid thresholds. Equal to the limit is within it. Above fails.
check "5% equals limit" 0 5 "outcome-change:5%"
check "5% below" 0 4.9 "outcome-change:5%"
check "5% above" 1 5.01 "outcome-change:5%"
check "integer above 5%" 1 6 "outcome-change:5%"
check "0% equals" 0 0 "outcome-change:0%"
check "0% above" 1 0.1 "outcome-change:0%"
check "100% equals" 0 100 "outcome-change:100%"
check "100.0 within 100%" 0 100.0 "outcome-change:100%"
check "1.5% equals" 0 1.5 "outcome-change:1.5%"
check "1.5% above" 1 1.6 "outcome-change:1.5%"
check "leading zero threshold" 0 5 "outcome-change:05%"
check "default 1% below" 0 1 "outcome-change:1%"
check "default 1% above" 1 1.1 "outcome-change:1%"

# Invalid fail-on values exit 2 and do not compare.
check "empty fail-on" 2 0 ""
check "missing percent" 2 0 "outcome-change:5"
check "double percent" 2 0 "outcome-change:5%%"
check "negative" 2 0 "outcome-change:-1%"
check "word threshold" 2 0 "outcome-change:five%"
check "NEVER uppercase" 2 0 NEVER
check "never with space" 2 0 "never "
check "space before number" 2 0 "outcome-change: 5%"
check "trailing dot" 2 0 "outcome-change:5.%"
check "leading dot" 2 0 "outcome-change:.5%"
check "bare percent" 2 0 "5%"
check "shell metacharacters" 2 0 "outcome-change:5%; echo pwned"
check "unknown key" 2 0 "token-change:5%"

# Invalid rate with a valid threshold.
check "empty rate" 2 "" "outcome-change:5%"
check "rate word" 2 "high" "outcome-change:5%"
check "rate percent sign" 2 "5%" "outcome-change:5%"
check "rate negative" 2 "-1" "outcome-change:5%"

check_contains "above message" 1 9 "outcome-change:5%" "above the 5% threshold"
check_contains "within message" 0 5 "outcome-change:5%" "within the 5% threshold"
check_contains "invalid message" 2 1 "nope" "invalid fail-on"
check_contains "never message" 0 40 never "reporting only"

echo "gate: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
