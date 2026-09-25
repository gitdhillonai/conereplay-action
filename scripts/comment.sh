#!/usr/bin/env bash
# Post the report as a PR comment, updating the previous ConeReplay comment if there is one.
set -euo pipefail
marker='<!-- conereplay-report -->'
body="$(mktemp)"
{
  echo "$marker"
  echo "## ConeReplay regression report"
  echo
  echo "Outcome-change rate: **${CR_RATE}%** · commit ${GITHUB_SHA:0:7} · [run](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
  echo
  head -c 60000 "$CR_REPORT"
} > "$body"
existing="$(gh api "repos/$CR_REPO/issues/$CR_PR/comments" --paginate --jq ".[] | select(.body | startswith(\"$marker\")) | .id" | tail -1)"
payload="$(jq -Rs '{body: .}' < "$body")"
if [ -n "$existing" ]; then
  url="$(echo "$payload" | gh api -X PATCH "repos/$CR_REPO/issues/comments/$existing" --input - --jq .html_url)"
else
  url="$(echo "$payload" | gh api -X POST "repos/$CR_REPO/issues/$CR_PR/comments" --input - --jq .html_url)"
fi
echo "url=$url" >> "$GITHUB_OUTPUT"
echo "Posted ConeReplay report: $url"
