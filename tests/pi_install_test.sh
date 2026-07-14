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
  grep -Fq -- "$expected" "$file" || fail "$file does not contain: $expected"
}

home="$TMP_DIR/home"
bin_dir="$TMP_DIR/bin"
mkdir -p "$home" "$bin_dir"

cat > "$bin_dir/npm" <<'FAKE_NPM'
#!/usr/bin/env bash
printf 'npm must not be used to install Pi\n' >&2
exit 99
FAKE_NPM
chmod +x "$bin_dir/npm"

cat > "$bin_dir/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$CURL_ARGS_FILE"
cat <<'INSTALLER'
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/pi" <<'PI'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  printf 'test-pi 1.0\n'
  exit 0
fi
exit 0
PI
chmod +x "$HOME/.local/bin/pi"
INSTALLER
FAKE_CURL
chmod +x "$bin_dir/curl"

(
  export HOME="$home"
  export PATH="$bin_dir:/usr/bin:/bin"
  export CURL_ARGS_FILE="$TMP_DIR/curl.args"

  # shellcheck source=../scripts/install/pi.sh
  source "$ROOT/scripts/install/pi.sh"
  install_pi_cli > "$TMP_DIR/install.out" 2>&1 || fail 'official Pi installer path failed'

  _pi_is_working || fail 'Pi is not available immediately after installation'
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) fail 'Pi installer did not add ~/.local/bin to the current PATH' ;;
  esac
)

assert_contains "$TMP_DIR/curl.args" '-fsSL https://pi.dev/install.sh'
if grep -Fq 'npm must not be used' "$TMP_DIR/install.out"; then
  fail 'Pi installation still invoked global npm'
fi

# Installer failures must propagate so every profile's _step wrapper can record
# the Pi failure in the final run summary.
cat > "$bin_dir/curl" <<'FAILING_CURL'
#!/usr/bin/env bash
exit 22
FAILING_CURL
chmod +x "$bin_dir/curl"
rm -rf "$home/.local"

(
  export HOME="$home"
  export PATH="$bin_dir:/usr/bin:/bin"
  # shellcheck source=../scripts/install/pi.sh
  source "$ROOT/scripts/install/pi.sh"

  if install_pi_cli > "$TMP_DIR/install-failure.out" 2>&1; then
    fail 'Pi CLI installer failure was reported as success'
  fi
)
assert_contains "$TMP_DIR/install-failure.out" '[error] pi CLI install failed'
assert_contains "$TMP_DIR/install-failure.out" 'https://pi.dev/install.sh'
assert_contains "$TMP_DIR/install-failure.out" 'rerun setup'
assert_contains "$ROOT/fish/.config/fish/config.fish" 'fish_add_path "$HOME/.local/bin"'

# Package reconciliation failures must propagate through install_pi_packages so
# the profile failure log makes the overall setup command nonzero.
mkdir -p "$home/.pi/agent" "$home/.local/bin"
printf '{"packages":["test:broken-package"]}\n' > "$home/.pi/agent/settings.json"
cat > "$home/.local/bin/pi" <<'FAILING_PI_PACKAGE'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  printf 'test-pi 1.0\n'
  exit 0
fi
if [ "${1:-}" = "install" ]; then
  exit 7
fi
exit 0
FAILING_PI_PACKAGE
chmod +x "$home/.local/bin/pi"
(
  export HOME="$home"
  export PATH="$home/.local/bin:$bin_dir:/usr/bin:/bin"
  source "$ROOT/scripts/install/pi.sh"
  if install_pi_packages "$ROOT" devcontainer > "$TMP_DIR/package-failure.out" 2>&1; then
    fail 'failed Pi package installation was reported as success'
  fi
)
assert_contains "$TMP_DIR/package-failure.out" '[error] pi install failed for: test:broken-package'

printf '{invalid json\n' > "$home/.pi/agent/settings.json"
(
  export HOME="$home"
  export PATH="$home/.local/bin:$bin_dir:/usr/bin:/bin"
  source "$ROOT/scripts/install/pi.sh"
  if install_pi_packages "$ROOT" devcontainer > "$TMP_DIR/settings-failure.out" 2>&1; then
    fail 'invalid Pi settings JSON was reported as success'
  fi
)
assert_contains "$TMP_DIR/settings-failure.out" '[error] could not read Pi packages from'

printf 'PASS: Pi install tests\n'
