#!/usr/bin/env bash
# Print the path of a Python interpreter that is 3.11 or newer.
# Prefer python<CR_PYTHON_VERSION> when that command exists and is new enough.
# This does not download Python.
set -euo pipefail

want="${CR_PYTHON_VERSION:-3.11}"
chosen=""
for candidate in "python${want}" python3 python; do
  if ! command -v "$candidate" >/dev/null 2>&1; then
    continue
  fi
  if ! "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
    echo "ConeReplay: skipping $candidate ($("$candidate" -c 'import sys; print("%d.%d" % sys.version_info[:2])')); need Python 3.11 or newer" >&2
    continue
  fi
  chosen="$(command -v "$candidate")"
  break
done

if [ -z "$chosen" ]; then
  echo "::error::Python 3.11 or newer is not on PATH. This action does not download Python." >&2
  exit 1
fi
printf '%s\n' "$chosen"
