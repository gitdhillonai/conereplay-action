#!/usr/bin/env bash
# Interpreter selection: exact name, newer python3, and rejection of Python older than 3.11.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PICK="$ROOT/scripts/python_bin.sh"
pass=0
fail=0

ok() { echo "ok $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1" >&2; fail=$((fail + 1)); }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

write_py() {
  local path="$1"
  local version="$2"
  cat > "$path" << EOF
#!/bin/sh
if [ "\${1:-}" = "--version" ]; then
  echo "Python $version"
  exit 0
fi
case "\${2:-}" in
  *">= (3, 11)"*)
    major=\$(printf '%s' "$version" | cut -d. -f1)
    minor=\$(printf '%s' "$version" | cut -d. -f2)
    if [ "\$major" -gt 3 ] || { [ "\$major" -eq 3 ] && [ "\$minor" -ge 11 ]; }; then
      exit 0
    fi
    exit 1
    ;;
  *"version_info[:2]"*)
    printf '%s\n' "$version"
    exit 0
    ;;
esac
echo "fake python: unhandled \$*" >&2
exit 1
EOF
  chmod +x "$path"
}

bin_old="$workdir/old"
bin_both="$workdir/both"
mkdir -p "$bin_old" "$bin_both"
write_py "$bin_old/python3" "3.10"
write_py "$bin_old/python" "3.10"
write_py "$bin_both/python3" "3.12"
write_py "$bin_both/python3.11" "3.11"

set +e
out="$(CR_PYTHON_VERSION=3.11 PATH="$bin_old:/bin:/usr/bin" bash "$PICK" 2>"$workdir/old.err")"
rc=$?
set -e
if [ "$rc" -ne 0 ] && grep -q 'not on PATH' "$workdir/old.err"; then
  ok "Python 3.10 is rejected"
else
  bad "Python 3.10 rc=$rc out=$out"
  cat "$workdir/old.err" >&2
fi

set +e
out="$(CR_PYTHON_VERSION=3.11 PATH="$bin_both:/bin:/usr/bin" bash "$PICK" 2>"$workdir/both.err")"
rc=$?
set -e
if [ "$rc" -eq 0 ] && [ "$out" = "$bin_both/python3.11" ]; then
  ok "requested python3.11 is preferred over python3"
else
  bad "preferred interpreter rc=$rc out=$out"
fi

rm "$bin_both/python3.11"
set +e
out="$(CR_PYTHON_VERSION=3.11 PATH="$bin_both:/bin:/usr/bin" bash "$PICK" 2>"$workdir/fallback.err")"
rc=$?
set -e
if [ "$rc" -eq 0 ] && [ "$out" = "$bin_both/python3" ]; then
  ok "python3 3.12 is used when python3.11 is absent"
else
  bad "fallback interpreter rc=$rc out=$out"
fi

mkdir -p "$workdir/empty"
set +e
out="$(CR_PYTHON_VERSION=3.11 PATH="$workdir/empty:/bin:/usr/bin" bash "$PICK" 2>"$workdir/none.err")"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  ok "missing Python fails"
else
  bad "missing Python should fail out=$out"
fi

echo "python: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
