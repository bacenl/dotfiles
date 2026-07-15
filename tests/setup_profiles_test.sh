#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
CALLS="$TMP_DIR/calls"

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

reset_mocks() {
  : > "$CALLS"
  OS=debian
  install_nvim() { printf 'install:nvim\n' >> "$CALLS"; }
  install_pkg() { printf 'install:%s\n' "$1" >> "$CALLS"; }
  do_stow() { printf 'stow:%s\n' "$1" >> "$CALLS"; }
  resolve_pkg_name() { printf '%s\n' "$1"; }
  setup_tmux_plugins() { printf 'tmux:plugins\n' >> "$CALLS"; }
  reload_tmux_config() { printf 'tmux:reload\n' >> "$CALLS"; }
  select_pi_settings_profile() { printf 'pi-profile:%s\n' "$2" >> "$CALLS"; }
  install_pi_packages() { printf 'pi-packages:%s\n' "$2" >> "$CALLS"; }
  _log_setup_fail() { printf 'failure:%s\n' "$1" >> "$CALLS"; }
  _report_setup_failures() { :; }
}

# Portable home paths must not encode a machine-specific username.
assert_not_contains "$ROOT/fish/.config/fish/config.fish" '/home/bacen'
assert_contains "$ROOT/fish/.config/fish/config.fish" '$HOME/miniforge3'
assert_not_contains "$ROOT/scripts/profile/personal.sh" '/home/ethan'
assert_contains "$ROOT/scripts/profile/personal.sh" '%h/.pi/agent/pi_daily_capture/capture.py'

# Devcontainers keep their dedicated Pi profile but now install and stow Fish.
reset_mocks
# shellcheck source=../scripts/profile/container.sh
source "$ROOT/scripts/profile/container.sh"
run_container_profile "$ROOT" >/dev/null
assert_contains "$CALLS" 'install:fish'
assert_contains "$CALLS" 'stow:fish'
assert_contains "$CALLS" 'pi-profile:devcontainer'
assert_contains "$CALLS" 'pi-packages:devcontainer'

# WSL gets the portable terminal stack and the personal Pi package profile.
[ -f "$ROOT/scripts/profile/wsl.sh" ] || fail 'scripts/profile/wsl.sh is missing'
reset_mocks
# shellcheck source=../scripts/profile/wsl.sh
source "$ROOT/scripts/profile/wsl.sh"
run_wsl_profile "$ROOT" >/dev/null
for pkg in nvim tmux fzf ripgrep bat zoxide eza fish node npm python go gcc gh yazi; do
  assert_contains "$CALLS" "install:$pkg"
done
for pkg in nvim tmux fish scripts claude pi npm; do
  assert_contains "$CALLS" "stow:$pkg"
done
assert_not_contains "$CALLS" 'install:kitty'
assert_not_contains "$CALLS" 'stow:kitty'
assert_contains "$CALLS" 'pi-profile:personal'
assert_contains "$CALLS" 'pi-packages:personal'

# The public CLI advertises the WSL profile.
HELP_OUTPUT=$(bash "$ROOT/setup.sh" --help)
printf '%s\n' "$HELP_OUTPUT" | grep -Fq 'devcontainer|personal|wsl' \
  || fail 'setup.sh --help does not advertise the WSL profile'

# The WSL profile refuses non-WSL hosts and Windows-mounted HOME directories
# before package installation or stowing can begin.
if WSL_DISTRO_NAME=Ubuntu HOME="$TMP_DIR/home" bash "$ROOT/setup.sh" --profile wsl \
  >"$TMP_DIR/non-wsl.out" 2>&1; then
  fail 'wsl profile trusted a spoofed WSL_DISTRO_NAME outside WSL'
fi
assert_contains "$TMP_DIR/non-wsl.out" 'must be run inside WSL'

for windows_home in /mnt /mnt/c/Users/test; do
  if HOME="$windows_home" bash "$ROOT/setup.sh" --profile wsl \
    >"$TMP_DIR/windows-home.out" 2>&1; then
    fail "wsl profile unexpectedly accepted Windows-mounted HOME: $windows_home"
  fi
  assert_contains "$TMP_DIR/windows-home.out" 'requires a Linux home directory'
done

ln -s /mnt/c/Users/test "$TMP_DIR/windows-home-link"
if HOME="$TMP_DIR/windows-home-link" bash "$ROOT/setup.sh" --profile wsl \
  >"$TMP_DIR/windows-home-link.out" 2>&1; then
  fail 'wsl profile unexpectedly accepted HOME resolving into /mnt'
fi
assert_contains "$TMP_DIR/windows-home-link.out" 'requires a Linux home directory'

if HOME="$TMP_DIR/home" bash "$ROOT/setup.sh" --profile wsl \
  --dotfiles-dir /mnt/c/Users/test/dotfiles >"$TMP_DIR/windows-dotfiles.out" 2>&1; then
  fail 'wsl profile unexpectedly accepted a Windows-mounted dotfiles checkout'
fi
assert_contains "$TMP_DIR/windows-dotfiles.out" 'dotfiles checkout must be in the WSL filesystem'

# Every WSL stow target must have a valid GNU Stow layout into a Linux HOME.
if command -v stow >/dev/null 2>&1; then
  mkdir -p "$TMP_DIR/home"
  for pkg in nvim tmux fish scripts claude pi npm; do
    stow --simulate --no-folding --dir="$ROOT" --target="$TMP_DIR/home" "$pkg" \
      >/dev/null 2>&1 || fail "stow dry-run failed for $pkg"
  done
fi

printf 'PASS: setup profile tests\n'
