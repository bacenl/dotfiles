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

export NVIM_VERSION=0.11.2
OS=arch
_sudo() { :; }
_log_setup_fail() { printf 'failure:%s\n' "$1" >> "$TMP_DIR/calls"; }
# shellcheck source=../scripts/install/nvim.sh
source "$ROOT/scripts/install/nvim.sh"

_nvim_version_at_least 0.11.2 0.11.2 || fail 'minimum Neovim version did not satisfy itself'
_nvim_version_at_least 0.12.0 0.11.2 || fail 'newer Neovim version was rejected'
if _nvim_version_at_least 0.11.1 0.11.2; then
  fail 'Neovim 0.11.1 incorrectly satisfied the 0.11.2 minimum'
fi
if _nvim_version_at_least invalid 0.11.2; then
  fail 'an invalid Neovim version was accepted'
fi

# Package-manager profiles must verify the result and use the upstream release
# fallback when a distro package is too old for LazyVim.
mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/nvim" <<'OLD_NVIM'
#!/usr/bin/env bash
printf 'NVIM v0.11.1\n'
OLD_NVIM
chmod +x "$TMP_DIR/bin/nvim"
export PATH="$TMP_DIR/bin:$PATH"
_install_nvim_release() {
  printf 'release-fallback:%s\n' "$NVIM_VERSION" >> "$TMP_DIR/calls"
  cat > "$TMP_DIR/bin/nvim" <<'NEW_NVIM'
#!/usr/bin/env bash
printf 'NVIM v0.11.2\n'
NEW_NVIM
  chmod +x "$TMP_DIR/bin/nvim"
}
: > "$TMP_DIR/calls"
install_nvim > "$TMP_DIR/install.out" 2>&1
assert_contains "$TMP_DIR/calls" 'release-fallback:0.11.2'
assert_contains "$TMP_DIR/install.out" '[warn] installed Neovim 0.11.1 is below LazyVim minimum 0.11.2'
assert_contains "$TMP_DIR/install.out" '[ok] neovim 0.11.2 satisfies LazyVim minimum 0.11.2'

# A newer existing Neovim must be preserved rather than downgraded to the
# fallback release on Debian/WSL or needlessly reinstalled elsewhere.
cat > "$TMP_DIR/bin/nvim" <<'NEWER_NVIM'
#!/usr/bin/env bash
printf 'NVIM v0.12.0\n'
NEWER_NVIM
chmod +x "$TMP_DIR/bin/nvim"
: > "$TMP_DIR/calls"
_sudo() { printf 'unexpected-package-install\n' >> "$TMP_DIR/calls"; }
install_nvim > "$TMP_DIR/current.out" 2>&1
[ ! -s "$TMP_DIR/calls" ] || fail 'installer replaced an existing compatible Neovim'
assert_contains "$TMP_DIR/current.out" '[skip] neovim 0.12.0 already satisfies LazyVim minimum 0.11.2'

# If the Arch/Fedora package manager itself fails, setup must still attempt the
# official upstream release instead of giving up before the fallback.
cat > "$TMP_DIR/bin/nvim" <<'MISSING_NVIM'
#!/usr/bin/env bash
exit 127
MISSING_NVIM
chmod +x "$TMP_DIR/bin/nvim"
: > "$TMP_DIR/calls"
_sudo() { return 1; }
install_nvim > "$TMP_DIR/pkg-failure.out" 2>&1
assert_contains "$TMP_DIR/calls" 'release-fallback:0.11.2'
assert_contains "$TMP_DIR/pkg-failure.out" '[ok] neovim 0.11.2 satisfies LazyVim minimum 0.11.2'

assert_contains "$ROOT/setup.sh" 'NVIM_VERSION="${NVIM_VERSION:-0.11.2}"'
assert_contains "$ROOT/scripts/install/nvim.sh" 'NVIM_MIN_VERSION="${NVIM_MIN_VERSION:-0.11.2}"'

printf 'PASS: Neovim install tests\n'
