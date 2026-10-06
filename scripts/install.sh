#!/usr/bin/env bash
# Install the pinned conereplay package into a fresh virtualenv and put it on PATH.
# The virtualenv is created on a filesystem that allows symlinks (RUNNER_TEMP, then /tmp).
# actions/setup-python is not used: its archive contains symlinks, and the self-hosted
# runner for this repo cannot create those while extracting the action.
set -euo pipefail

: "${CR_CONEREPLAY_VERSION:?CR_CONEREPLAY_VERSION is required}"

here="$(cd "$(dirname "$0")" && pwd)"
py="$("$here/python_bin.sh")"
echo "ConeReplay: using $("$py" --version 2>&1) at $py (requested ${CR_PYTHON_VERSION:-3.11})"

venv_parent=""
for parent in "${RUNNER_TEMP:-}" /tmp; do
  [ -n "$parent" ] || continue
  [ -d "$parent" ] && [ -w "$parent" ] || continue
  link="${parent}/conereplay-link-test-$$"
  if ln -s /bin/sh "$link" 2>/dev/null; then
    rm -f "$link"
    venv_parent="$parent"
    break
  fi
  echo "ConeReplay: $parent does not allow the symlinks a virtualenv needs" >&2
done
if [ -z "$venv_parent" ]; then
  echo "::error::No writable directory allows symlinks for a virtualenv (tried RUNNER_TEMP and /tmp)." >&2
  exit 1
fi

venv="${venv_parent}/conereplay-venv-$$"
"$py" -m venv "$venv"
"$venv/bin/python" -m pip install --disable-pip-version-check "conereplay==${CR_CONEREPLAY_VERSION}"
installed="$("$venv/bin/python" -c 'from importlib.metadata import version; print(version("conereplay"))')"
if [ "$installed" != "$CR_CONEREPLAY_VERSION" ]; then
  echo "::error::Installed conereplay ${installed}, expected ${CR_CONEREPLAY_VERSION}" >&2
  exit 1
fi
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$venv/bin" >> "$GITHUB_PATH"
fi
echo "ConeReplay: installed conereplay==${installed} into ${venv}"
