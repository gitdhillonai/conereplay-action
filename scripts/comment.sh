#!/usr/bin/env bash
# Post the report as one PR comment. A later run updates that comment.
# Extra comments that carry the same marker are deleted.
# A missing write token (fork pull requests) logs a message and exits 0.
set -euo pipefail

marker='<!-- conereplay-report -->'

skip_for_permissions() {
  echo "ConeReplay: skipping PR comment; no pull-requests write token. Fork pull requests do not receive a write token. The report is in the job summary and this log." >&2
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "url=" >> "$GITHUB_OUTPUT"
  fi
}

if [ -z "${GH_TOKEN:-}" ]; then
  skip_for_permissions
  exit 0
fi

: "${CR_REPORT:?CR_REPORT is required}"
: "${CR_RATE:?CR_RATE is required}"
: "${CR_PR:?CR_PR is required}"
: "${CR_REPO:?CR_REPO is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_SERVER_URL:?GITHUB_SERVER_URL is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

# gh exit 86 is not a real gh code. run_gh uses it for a permissions failure.
run_gh() {
  local out="$1"
  shift
  local err rc
  err="$(mktemp)"
  set +e
  gh "$@" >"$out" 2>"$err"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    cat "$err" >&2
    if grep -Eq 'HTTP 401|HTTP 403|Requires authentication|Bad credentials' "$err"; then
      return 86
    fi
    return "$rc"
  fi
}

finish_gh() {
  local rc="$1"
  if [ "$rc" -eq 86 ]; then
    skip_for_permissions
    exit 0
  fi
  if [ "$rc" -ne 0 ]; then
    exit "$rc"
  fi
}

body="$(mktemp)"
{
  echo "$marker"
  echo "## ConeReplay regression report"
  echo
  echo "Outcome-change rate: **${CR_RATE}%** · commit ${GITHUB_SHA:0:7} · [run](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
  echo
  head -c 60000 "$CR_REPORT"
} > "$body"
payload="$(mktemp)"
jq -Rs '{body: .}' < "$body" > "$payload"

list_out="$(mktemp)"
filter=".[] | select(.body | startswith(\"${marker}\")) | .id"
rc=0
run_gh "$list_out" api "repos/${CR_REPO}/issues/${CR_PR}/comments" --paginate --jq "$filter" || rc=$?
finish_gh "$rc"

ids="$(mktemp)"
grep -E '^[0-9]+$' "$list_out" > "$ids" || true
first="$(head -n 1 "$ids" || true)"

url_out="$(mktemp)"
if [ -z "$first" ]; then
  rc=0
  run_gh "$url_out" api -X POST "repos/${CR_REPO}/issues/${CR_PR}/comments" --input "$payload" --jq .html_url || rc=$?
  finish_gh "$rc"
else
  rc=0
  run_gh "$url_out" api -X PATCH "repos/${CR_REPO}/issues/comments/${first}" --input "$payload" --jq .html_url || rc=$?
  finish_gh "$rc"
  rest="$(mktemp)"
  tail -n +2 "$ids" > "$rest"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    deleted="$(mktemp)"
    rc=0
    run_gh "$deleted" api -X DELETE "repos/${CR_REPO}/issues/comments/${id}" || rc=$?
    finish_gh "$rc"
    echo "ConeReplay: removed duplicate comment ${id}" >&2
  done < "$rest"
fi

url="$(tr -d '\r\n' < "$url_out")"
if [ -z "$url" ]; then
  echo "ConeReplay: comment API returned no URL" >&2
  exit 1
fi
echo "url=${url}" >> "$GITHUB_OUTPUT"
echo "Posted ConeReplay report: ${url}"
