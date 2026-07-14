#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1" expected="$2"
  grep -Fq "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_not_contains() {
  local file="$1" unexpected="$2"
  if grep -Fq "$unexpected" "$file"; then
    fail "$file unexpectedly contains: $unexpected"
  fi
}

# Load the actual implementation without executing setup's bottom-level runner.
# The runner begins at the _SETUP_RUN_LOG assignment.
source <(awk '/^_SETUP_RUN_LOG=/{exit} {print}' "$ROOT/setup.sh")

cat > "$TMP_DIR/run.log" <<'LOG'
normal setup output
[skip] yazi not available on debian
[warn] TPM install_plugins binary missing; remove the incomplete TPM directory and rerun setup
[skip] yazi not available on debian
npm ERR! verbose implementation detail
[error] pi CLI install failed; check network access to https://pi.dev/install.sh and rerun setup
LOG

report_setup_run_summary "$TMP_DIR/run.log" > "$TMP_DIR/summary.out"
assert_contains "$TMP_DIR/summary.out" 'End-of-run summary'
assert_contains "$TMP_DIR/summary.out" '[skip] yazi not available on debian'
assert_contains "$TMP_DIR/summary.out" '[warn] TPM install_plugins binary missing'
assert_contains "$TMP_DIR/summary.out" '[error] pi CLI install failed'
assert_not_contains "$TMP_DIR/summary.out" 'normal setup output'
assert_not_contains "$TMP_DIR/summary.out" 'npm ERR! verbose implementation detail'

count=$(grep -Fc '[skip] yazi not available on debian' "$TMP_DIR/summary.out")
[ "$count" -eq 1 ] || fail "summary did not deduplicate repeated skip (count: $count)"

printf 'ordinary output\n' > "$TMP_DIR/clean.log"
report_setup_run_summary "$TMP_DIR/clean.log" > "$TMP_DIR/clean-summary.out"
assert_contains "$TMP_DIR/clean-summary.out" 'No warnings, errors, or skipped steps.'

# setup.sh must emit the consolidated summary after the profile run completes.
assert_contains "$ROOT/setup.sh" 'report_setup_run_summary'

# Argument/preflight failures must also be captured, not only failures that
# happen after package/profile execution begins.
if bash "$ROOT/setup.sh" --profile invalid > "$TMP_DIR/invalid.out" 2>&1; then
  fail 'invalid profile unexpectedly succeeded'
fi
assert_contains "$TMP_DIR/invalid.out" '[error] --profile must be'
assert_contains "$TMP_DIR/invalid.out" 'End-of-run summary'
assert_contains "$TMP_DIR/invalid.out" '[error] setup exited with status 1'

summary_line=$(grep -nF 'End-of-run summary' "$TMP_DIR/invalid.out" | tail -1 | cut -d: -f1)
error_line=$(grep -nF '[error] --profile must be' "$TMP_DIR/invalid.out" | tail -1 | cut -d: -f1)
[ "$error_line" -gt "$summary_line" ] || fail 'validation error was not repeated in the final summary'

# A validation failure must never source a helper from the default checkout,
# especially when argument parsing selected a different checkout in a subshell.
malicious_home="$TMP_DIR/malicious-home"
mkdir -p "$malicious_home/dotfiles/scripts/install"
cat > "$malicious_home/dotfiles/scripts/install/summary.sh" <<EOF
touch "$TMP_DIR/unsafe-source-ran"
EOF
if HOME="$malicious_home" bash "$ROOT/setup.sh" --profile invalid \
    --dotfiles-dir "$TMP_DIR/custom-checkout" > "$TMP_DIR/custom-invalid.out" 2>&1; then
  fail 'invalid profile with custom checkout unexpectedly succeeded'
fi
[ ! -e "$TMP_DIR/unsafe-source-ran" ] || fail 'setup sourced code from the wrong checkout after validation failed'

printf 'PASS: setup summary tests\n'
