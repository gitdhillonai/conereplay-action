#!/usr/bin/env bash
# Post the report as one PR comment. A later run updates that comment.
# Extra comments that carry the same marker are deleted.
# A missing write token (fork pull requests) logs a message and exits 0.
# Uses curl against the GitHub API. The self-hosted runner does not have gh.
set -euo pipefail

marker='<!-- conereplay-report -->'
api_root="${GITHUB_API_URL:-https://api.github.com}"
api_root="${api_root%/}"

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

if ! command -v curl >/dev/null 2>&1; then
  echo "::error::curl is required to post the PR comment" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "::error::jq is required to post the PR comment" >&2
  exit 1
fi

# Prints the HTTP status on stdout. Writes the response body to $outfile.
api() {
  local method="$1"
  local path="$2"
  local outfile="$3"
  local datafile="${4:-}"
  local args=(
    --silent
    --show-error
    --output "$outfile"
    --write-out '%{http_code}'
    --request "$method"
    --header "Authorization: Bearer ${GH_TOKEN}"
    --header "Accept: application/vnd.github+json"
    --header "X-GitHub-Api-Version: 2022-11-28"
  )
  if [ -n "$datafile" ]; then
    args+=(--header "Content-Type: application/json" --data-binary "@${datafile}")
  fi
  curl "${args[@]}" "${api_root}${path}"
}

stop_unless_ok() {
  local code="$1"
  local method="$2"
  local path="$3"
  local outfile="$4"
  case "$code" in
    200|201|204) return 0 ;;
    401|403)
      echo "ConeReplay: GitHub API returned HTTP ${code}" >&2
      skip_for_permissions
      exit 0
      ;;
    *)
      echo "::error::ConeReplay: GitHub API ${method} ${path} returned HTTP ${code}" >&2
      cat "$outfile" >&2
      exit 1
      ;;
  esac
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

combined="$(mktemp)"
echo '[]' > "$combined"
page=1
while [ "$page" -le 10 ]; do
  page_body="$(mktemp)"
  code="$(api GET "/repos/${CR_REPO}/issues/${CR_PR}/comments?per_page=100&page=${page}" "$page_body")"
  stop_unless_ok "$code" GET "/repos/${CR_REPO}/issues/${CR_PR}/comments" "$page_body"
  jq -s '.[0] + .[1]' "$combined" "$page_body" > "${combined}.next"
  mv "${combined}.next" "$combined"
  count="$(jq 'length' "$page_body")"
  if [ "$count" -lt 100 ]; then
    break
  fi
  page=$((page + 1))
done

ids="$(mktemp)"
jq -r --arg marker "$marker" '.[] | select(.body | startswith($marker)) | .id' "$combined" > "$ids"
first="$(head -n 1 "$ids" || true)"

url_body="$(mktemp)"
if [ -z "$first" ]; then
  code="$(api POST "/repos/${CR_REPO}/issues/${CR_PR}/comments" "$url_body" "$payload")"
  stop_unless_ok "$code" POST "/repos/${CR_REPO}/issues/${CR_PR}/comments" "$url_body"
else
  code="$(api PATCH "/repos/${CR_REPO}/issues/comments/${first}" "$url_body" "$payload")"
  stop_unless_ok "$code" PATCH "/repos/${CR_REPO}/issues/comments/${first}" "$url_body"
  rest="$(mktemp)"
  tail -n +2 "$ids" > "$rest"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    deleted="$(mktemp)"
    code="$(api DELETE "/repos/${CR_REPO}/issues/comments/${id}" "$deleted")"
    stop_unless_ok "$code" DELETE "/repos/${CR_REPO}/issues/comments/${id}" "$deleted"
    echo "ConeReplay: removed duplicate comment ${id}" >&2
  done < "$rest"
fi

url="$(jq -r '.html_url // empty' "$url_body")"
if [ -z "$url" ]; then
  echo "ConeReplay: comment API returned no URL" >&2
  exit 1
fi
echo "url=${url}" >> "$GITHUB_OUTPUT"
echo "Posted ConeReplay report: ${url}"
