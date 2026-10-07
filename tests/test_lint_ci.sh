#!/usr/bin/env bash
# The self-test workflow must run the three supply-chain gates.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
wf="$ROOT/.github/workflows/self-test.yml"
for needle in \
  scripts/install_actionlint.sh \
  scripts/install_shellcheck.sh \
  scripts/install_gitleaks.sh \
  ".tools/actionlint" \
  ".tools/shellcheck" \
  ".tools/gitleaks detect --source . --redact --exit-code 1"
do
  if ! grep -q -F "$needle" "$wf"; then
    echo "self-test workflow is missing: $needle" >&2
    exit 1
  fi
done
echo "actionlint, shellcheck, and gitleaks are in self-test"
