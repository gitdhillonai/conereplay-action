#!/usr/bin/env bash
# Comment creation, update on re-run, duplicate removal, and fork-PR fallback.
# The action talks to the GitHub API with curl. This mock is that curl.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMENT="$ROOT/scripts/comment.sh"
pass=0
fail=0

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

ok() {
  echo "ok $1"
  pass=$((pass + 1))
}

bad() {
  echo "FAIL $1" >&2
  fail=$((fail + 1))
}

new_mock() {
  local state="$1"
  mkdir -p "$state/bin"
  if [ ! -f "$state/comments.json" ]; then
    echo '[]' > "$state/comments.json"
  fi
  : > "$state/calls.log"
  cat > "$state/bin/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="${GH_MOCK_STATE:?}"
comments="$state/comments.json"
method="GET"
outfile=""
datafile=""
url=""
prev=""
for arg in "$@"; do
  if [ -n "$prev" ]; then
    case "$prev" in
      --output) outfile="$arg" ;;
      --request) method="$arg" ;;
      --data-binary) datafile="${arg#@}" ;;
      --write-out|--header) ;;
    esac
    prev=""
    continue
  fi
  case "$arg" in
    --output|--request|--data-binary|--write-out|--header)
      prev="$arg"
      ;;
    --silent|--show-error)
      ;;
    http*)
      url="$arg"
      ;;
  esac
done
path="${url#*://}"
path="/${path#*/}"
printf '%s %s\n' "$method" "$path" >> "$state/calls.log"
code="200"
if [ -f "$state/deny" ]; then
  code="$(cat "$state/deny")"
  printf '%s\n' "{\"message\":\"Resource not accessible by integration\",\"status\":${code}}" > "$outfile"
  printf '%s' "$code"
  exit 0
fi
if [ "$method" = "GET" ]; then
  cp "$comments" "$outfile"
  printf '%s' "200"
  exit 0
fi
if [ "$method" = "POST" ]; then
  body="$(jq -r '.body' "$datafile")"
  id="$(jq '[.[].id] | max // 0 | . + 1' "$comments")"
  html="https://github.com/example/repo/pull/7#issuecomment-${id}"
  jq --argjson id "$id" --arg body "$body" --arg html "$html" \
    '. + [{id: $id, body: $body, html_url: $html}]' "$comments" > "$comments.tmp"
  mv "$comments.tmp" "$comments"
  jq -n --argjson id "$id" --arg body "$body" --arg html "$html" \
    '{id: $id, body: $body, html_url: $html}' > "$outfile"
  printf '%s' "201"
  exit 0
fi
if [ "$method" = "PATCH" ]; then
  id="${path##*/}"
  body="$(jq -r '.body' "$datafile")"
  html="https://github.com/example/repo/pull/7#issuecomment-${id}"
  jq --argjson id "$id" --arg body "$body" --arg html "$html" \
    'map(if .id == $id then .body = $body | .html_url = $html else . end)' \
    "$comments" > "$comments.tmp"
  mv "$comments.tmp" "$comments"
  jq -n --argjson id "$id" --arg html "$html" '{id: $id, html_url: $html}' > "$outfile"
  printf '%s' "200"
  exit 0
fi
if [ "$method" = "DELETE" ]; then
  id="${path##*/}"
  jq --argjson id "$id" 'map(select(.id != $id))' "$comments" > "$comments.tmp"
  mv "$comments.tmp" "$comments"
  : > "$outfile"
  printf '%s' "204"
  exit 0
fi
echo "mock curl: unhandled method $method" >&2
printf '%s' "500"
exit 0
EOF
  chmod +x "$state/bin/curl"
}

run_comment() {
  local state="$1"
  local rate="$2"
  local out="$3"
  local log="$4"
  set +e
  GH_MOCK_STATE="$state" \
    GH_TOKEN="fake-token" \
    PATH="$state/bin:$PATH" \
    CR_REPORT="$state/report.md" \
    CR_RATE="$rate" \
    CR_PR="7" \
    CR_REPO="example/repo" \
    GITHUB_OUTPUT="$out" \
    GITHUB_SHA="abcdef1234567890" \
    GITHUB_SERVER_URL="https://github.com" \
    GITHUB_REPOSITORY="example/repo" \
    GITHUB_RUN_ID="99" \
    bash "$COMMENT" >"$log" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# --- create, then update, no second comment ---
state="$workdir/create"
new_mock "$state"
printf '# report one\n' > "$state/report.md"
out="$state/out"
log="$state/log"
: > "$out"
if run_comment "$state" "10" "$out" "$log"; then
  ok "create exits 0"
else
  bad "create exits 0"
  cat "$log" >&2
fi
count="$(jq 'length' "$state/comments.json")"
posts="$(grep -c '^POST /repos/example/repo/issues/7/comments$' "$state/calls.log" || true)"
if [ "$count" = "1" ] && [ "$posts" = "1" ] && grep -q 'url=https://github.com/example/repo/pull/7#issuecomment-1' "$out"; then
  ok "create posts one comment"
else
  bad "create posts one comment (count=$count posts=$posts)"
fi
if jq -e '.[] | select(.body | startswith("<!-- conereplay-report -->"))' "$state/comments.json" >/dev/null; then
  ok "create body starts with marker"
else
  bad "create body starts with marker"
fi

printf '# report two\n' > "$state/report.md"
: > "$out"
if run_comment "$state" "25" "$out" "$log"; then
  ok "update exits 0"
else
  bad "update exits 0"
  cat "$log" >&2
fi
count="$(jq 'length' "$state/comments.json")"
posts="$(grep -c '^POST /repos/example/repo/issues/7/comments$' "$state/calls.log" || true)"
patches="$(grep -c '^PATCH /repos/example/repo/issues/comments/1$' "$state/calls.log" || true)"
body="$(jq -r '.[0].body' "$state/comments.json")"
if [ "$count" = "1" ] && [ "$posts" = "1" ] && [ "$patches" = "1" ] && printf '%s\n' "$body" | grep -q '25%' && printf '%s\n' "$body" | grep -q 'report two'; then
  ok "re-run patches the same comment"
else
  bad "re-run patches the same comment (count=$count posts=$posts patches=$patches)"
  printf '%s\n' "$body" >&2
fi

# --- seeded duplicates collapse to one updated comment ---
state="$workdir/dedupe"
mkdir -p "$state"
cat > "$state/comments.json" << 'EOF'
[
  {"id": 10, "body": "<!-- conereplay-report -->\nold", "html_url": "https://github.com/example/repo/pull/7#issuecomment-10"},
  {"id": 11, "body": "a human comment", "html_url": "https://github.com/example/repo/pull/7#issuecomment-11"},
  {"id": 12, "body": "<!-- conereplay-report -->\nduplicate", "html_url": "https://github.com/example/repo/pull/7#issuecomment-12"}
]
EOF
new_mock "$state"
printf '# fresh\n' > "$state/report.md"
: > "$state/out"
if run_comment "$state" "3" "$state/out" "$state/log"; then
  ok "dedupe exits 0"
else
  bad "dedupe exits 0"
  cat "$state/log" >&2
fi
marker_count="$(jq '[.[] | select(.body | startswith("<!-- conereplay-report -->"))] | length' "$state/comments.json")"
human="$(jq '[.[] | select(.id == 11)] | length' "$state/comments.json")"
deleted="$(grep -c '^DELETE /repos/example/repo/issues/comments/12$' "$state/calls.log" || true)"
patched="$(grep -c '^PATCH /repos/example/repo/issues/comments/10$' "$state/calls.log" || true)"
posted="$(grep -c '^POST /repos/example/repo/issues/7/comments$' "$state/calls.log" || true)"
if [ "$marker_count" = "1" ] && [ "$human" = "1" ] && [ "$deleted" = "1" ] && [ "$patched" = "1" ] && [ "$posted" = "0" ]; then
  ok "re-run keeps one report comment and the human comment"
else
  bad "dedupe result marker=$marker_count human=$human deleted=$deleted patched=$patched posted=$posted"
  cat "$state/comments.json" >&2
fi

# --- no write token: do not call gh ---
state="$workdir/notoken"
new_mock "$state"
printf '# report\n' > "$state/report.md"
notoken_log="$state/log"
set +e
GH_MOCK_STATE="$state" \
  env -u GH_TOKEN -u GITHUB_TOKEN \
  PATH="$state/bin:$PATH" \
  CR_REPORT="$state/report.md" \
  CR_RATE="1" \
  CR_PR="7" \
  CR_REPO="example/repo" \
  GITHUB_OUTPUT="$state/out" \
  GITHUB_SHA="abcdef1234567890" \
  GITHUB_SERVER_URL="https://github.com" \
  GITHUB_REPOSITORY="example/repo" \
  GITHUB_RUN_ID="99" \
  bash "$COMMENT" >"$notoken_log" 2>&1
rc=$?
set -e
calls="$(wc -l < "$state/calls.log" | tr -d ' ')"
if [ "$rc" -eq 0 ] && [ "$calls" = "0" ] && grep -q 'no pull-requests write token' "$notoken_log" && grep -q 'Fork pull requests' "$notoken_log" && grep -qx 'url=' "$state/out"; then
  ok "empty token skips the comment and logs the fork fallback"
else
  bad "empty token fallback rc=$rc calls=$calls"
  cat "$notoken_log" >&2
fi

# --- 403 from gh: same fallback, no comment stored ---
state="$workdir/denied"
new_mock "$state"
echo 403 > "$state/deny"
printf '# report\n' > "$state/report.md"
: > "$state/out"
set +e
GH_MOCK_STATE="$state" \
  GH_TOKEN="fake-token" \
  PATH="$state/bin:$PATH" \
  CR_REPORT="$state/report.md" \
  CR_RATE="1" \
  CR_PR="7" \
  CR_REPO="example/repo" \
  GITHUB_OUTPUT="$state/out" \
  GITHUB_SHA="abcdef1234567890" \
  GITHUB_SERVER_URL="https://github.com" \
  GITHUB_REPOSITORY="example/repo" \
  GITHUB_RUN_ID="99" \
  bash "$COMMENT" >"$state/log" 2>&1
rc=$?
set -e
stored="$(jq 'length' "$state/comments.json")"
if [ "$rc" -eq 0 ] && [ "$stored" = "0" ] && grep -q 'HTTP 403' "$state/log" && grep -q 'no pull-requests write token' "$state/log"; then
  ok "HTTP 403 skips the comment"
else
  bad "HTTP 403 fallback rc=$rc stored=$stored"
  cat "$state/log" >&2
fi

# --- 500 is not treated as a fork ---
state="$workdir/err500"
new_mock "$state"
echo 500 > "$state/deny"
printf '# report\n' > "$state/report.md"
: > "$state/out"
set +e
GH_MOCK_STATE="$state" \
  GH_TOKEN="fake-token" \
  PATH="$state/bin:$PATH" \
  CR_REPORT="$state/report.md" \
  CR_RATE="1" \
  CR_PR="7" \
  CR_REPO="example/repo" \
  GITHUB_OUTPUT="$state/out" \
  GITHUB_SHA="abcdef1234567890" \
  GITHUB_SERVER_URL="https://github.com" \
  GITHUB_REPOSITORY="example/repo" \
  GITHUB_RUN_ID="99" \
  bash "$COMMENT" >"$state/log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ] && ! grep -q 'no pull-requests write token' "$state/log"; then
  ok "HTTP 500 fails the step"
else
  bad "HTTP 500 should fail rc=$rc"
  cat "$state/log" >&2
fi

echo "comment: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
