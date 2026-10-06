#!/usr/bin/env bash
# File, directory, and glob inputs. Stub checks the command. The published package checks the report.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/scripts/run.sh"
pass=0
fail=0

ok() {
  echo "ok $1"
  pass=$((pass + 1))
}

bad() {
  echo "FAIL $1" >&2
  fail=$((fail + 1))
}

output_value() {
  local file="$1"
  local key="$2"
  grep -E "^${key}=" "$file" | tail -n 1 | cut -d= -f2-
}

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

stubdir="$workdir/stub"
mkdir -p "$stubdir"
cat > "$stubdir/conereplay" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${STUB_LOG:?}"
mode=""
report=""
traces=""
prev=""
for arg in "$@"; do
  if [ -z "$mode" ]; then
    mode="$arg"
    continue
  fi
  if [ "$prev" = "--report" ]; then
    report="$arg"
    prev=""
    continue
  fi
  if [ "$prev" = "--traces" ] || [ "$prev" = "--trace" ]; then
    traces="$arg"
    prev=""
    continue
  fi
  case "$arg" in
    --report|--traces|--trace) prev="$arg" ;;
  esac
done
printf '# stub report\n' > "$report"
if [ "$mode" = "replay" ]; then
  case "$traces" in
    *outcome-changed.json) echo "conereplay: wrote $report (outcome_changed=True)" >&2 ;;
    *) echo "conereplay: wrote $report (outcome_changed=False)" >&2 ;;
  esac
  exit 0
fi
if [ "$mode" = "corpus" ]; then
  case "$traces" in
    *missing*) echo "conereplay: no trace files resolved from --traces" >&2; exit 2 ;;
    *half*) echo "conereplay: wrote $report (outcome_change_rate=12.5%)" >&2 ;;
    *) echo "conereplay: wrote $report (outcome_change_rate=0.0%)" >&2 ;;
  esac
  exit 0
fi
echo "stub: unknown mode $mode" >&2
exit 1
EOF
chmod +x "$stubdir/conereplay"

run_stub() {
  local traces="$1"
  local dir="$2"
  mkdir -p "$dir"
  : > "$dir/stub.log"
  : > "$dir/output"
  : > "$dir/summary"
  set +e
  STUB_LOG="$dir/stub.log" \
    PATH="$stubdir:$PATH" \
    CR_TRACES="$traces" \
    CR_MODIFY="$ROOT/example/modify.json" \
    CR_REPORT="$dir/report.md" \
    GITHUB_OUTPUT="$dir/output" \
    GITHUB_STEP_SUMMARY="$dir/summary" \
    bash "$RUN" >"$dir/stdout" 2>"$dir/stderr"
  local rc=$?
  set -e
  echo "$rc"
}

touch "$workdir/outcome-same.json" "$workdir/outcome-changed.json"

rc="$(run_stub "$workdir/outcome-same.json" "$workdir/file-same")"
logged="$(cat "$workdir/file-same/stub.log")"
if [ "$rc" = "0" ] && [ "$logged" = "replay --trace $workdir/outcome-same.json --modify $ROOT/example/modify.json --report $workdir/file-same/report.md" ] && [ "$(output_value "$workdir/file-same/output" rate)" = "0" ]; then
  ok "single file calls replay and reports rate 0 when the outcome is unchanged"
else
  bad "single unchanged file rc=$rc log=$logged rate=$(output_value "$workdir/file-same/output" rate)"
fi

rc="$(run_stub "$workdir/outcome-changed.json" "$workdir/file-changed")"
if [ "$rc" = "0" ] && grep -q '^replay ' "$workdir/file-changed/stub.log" && [ "$(output_value "$workdir/file-changed/output" rate)" = "100" ]; then
  ok "single file reports rate 100 when the outcome changes"
else
  bad "single changed file rc=$rc log=$(cat "$workdir/file-changed/stub.log") rate=$(output_value "$workdir/file-changed/output" rate)"
fi

rc="$(run_stub "example/traces" "$workdir/dir")"
expected="corpus --traces example/traces --modify $ROOT/example/modify.json --report $workdir/dir/report.md --format markdown"
actual="$(cat "$workdir/dir/stub.log")"
if [ "$rc" = "0" ] && [ "$actual" = "$expected" ] && [ "$(output_value "$workdir/dir/output" rate)" = "0.0" ]; then
  ok "directory calls corpus with the directory spec"
else
  bad "directory rc=$rc rate=[$(output_value "$workdir/dir/output" rate)]"
  printf 'expected: [%s]\nactual:   [%s]\n' "$expected" "$actual" >&2
fi

rc="$(run_stub "example/traces/*.json" "$workdir/glob")"
if [ "$rc" = "0" ] && grep -F -q -- '--traces example/traces/*.json' "$workdir/glob/stub.log" && [ "$(output_value "$workdir/glob/output" rate)" = "0.0" ]; then
  ok "glob is passed to corpus without shell expansion"
else
  bad "glob rc=$rc log=$(cat "$workdir/glob/stub.log")"
fi

rc="$(run_stub "example/traces/half/*.json" "$workdir/half")"
if [ "$rc" = "0" ] && [ "$(output_value "$workdir/half/output" rate)" = "12.5" ] && grep -q 'outcome-change rate 12.5%' "$workdir/half/summary"; then
  ok "corpus percentage is parsed from the CLI log"
else
  bad "percent parse rc=$rc rate=$(output_value "$workdir/half/output" rate)"
fi

rc="$(run_stub "missing/*.json" "$workdir/miss")"
if [ "$rc" = "2" ]; then
  ok "unresolved glob exits with the CLI status"
else
  bad "unresolved glob rc=$rc expected 2"
fi

# Published package. These fixtures change the refund outcome, so the rate is 100.
# Globs are relative to the workspace, which is the checkout root in Actions.
cd "$ROOT"
if ! command -v conereplay >/dev/null 2>&1; then
  echo "conereplay is not on PATH. Install conereplay==0.1.2 and re-run." >&2
  exit 1
fi
installed="$(python3 -c 'from importlib.metadata import version; print(version("conereplay"))')"
if [ "$installed" != "0.1.2" ]; then
  echo "expected conereplay 0.1.2, found $installed" >&2
  exit 1
fi
ok "published conereplay ${installed} is the package under test"

run_real() {
  local traces="$1"
  local dir="$2"
  mkdir -p "$dir"
  : > "$dir/output"
  : > "$dir/summary"
  set +e
  CR_TRACES="$traces" \
    CR_MODIFY="$ROOT/example/modify.json" \
    CR_REPORT="$dir/report.md" \
    GITHUB_OUTPUT="$dir/output" \
    GITHUB_STEP_SUMMARY="$dir/summary" \
    bash "$RUN" >"$dir/stdout" 2>"$dir/stderr"
  local rc=$?
  set -e
  echo "$rc"
}

rc="$(run_real "example/traces/refund-order-a.json" "$workdir/real-file")"
if [ "$rc" = "0" ] && [ "$(output_value "$workdir/real-file/output" rate)" = "100" ] && grep -q 'Outcome changed: \*\*yes\*\*' "$workdir/real-file/report.md"; then
  ok "published package replays one fixture file"
else
  bad "real file rc=$rc rate=$(output_value "$workdir/real-file/output" rate)"
  cat "$workdir/real-file/stderr" >&2
fi

rc="$(run_real "example/traces" "$workdir/real-dir")"
if [ "$rc" = "0" ] && [ "$(output_value "$workdir/real-dir/output" rate)" = "100.0" ] && grep -q 'Total traces: \*\*3\*\*' "$workdir/real-dir/report.md"; then
  ok "published package replays the fixture directory"
else
  bad "real directory rc=$rc rate=$(output_value "$workdir/real-dir/output" rate)"
  cat "$workdir/real-dir/stderr" >&2
fi

rc="$(run_real "example/traces/*.json" "$workdir/real-glob")"
if [ "$rc" = "0" ] && [ "$(output_value "$workdir/real-glob/output" rate)" = "100.0" ] && grep -q 'refund-order-c.json' "$workdir/real-glob/report.md"; then
  ok "published package replays the fixture glob"
else
  bad "real glob rc=$rc rate=$(output_value "$workdir/real-glob/output" rate)"
  cat "$workdir/real-glob/stderr" >&2
fi

echo "run: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
