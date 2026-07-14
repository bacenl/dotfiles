#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  [ "$actual" = "$expected" ] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
  local file="$1" expected="$2"
  grep -Fq "$expected" "$file" || fail "$file does not contain: $expected"
}

make_repo() {
  local repo="$1"
  mkdir -p "$repo/pkg/.config" "$repo/next/.config"
  printf 'repository version\n' > "$repo/pkg/.config/app.conf"
  printf 'next package\n' > "$repo/next/.config/next.conf"
  git -C "$repo" init -q
  git -C "$repo" config user.name test
  git -C "$repo" config user.email test@example.com
  git -C "$repo" add pkg next
  git -C "$repo" commit -qm initial
}

make_fake_stow() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/stow" <<'FAKE_STOW'
#!/usr/bin/env bash
set -euo pipefail
pkg="${!#}"
printf '%s\n' "$pkg" >> "$STOW_CALLS"
if [ "${STOW_FAIL_PACKAGE:-}" = "$pkg" ]; then
  if [ -n "${STOW_MUTATE_FILE:-}" ]; then
    printf 'partially adopted home version\n' > "$STOW_MUTATE_FILE"
  fi
  if [ -n "${STOW_REPLACEMENT_LINK_PATH:-}" ]; then
    rm -f "$STOW_REPLACEMENT_LINK_PATH"
    ln -s "$STOW_REPLACEMENT_LINK_TARGET" "$STOW_REPLACEMENT_LINK_PATH"
  fi
  exit 42
fi
FAKE_STOW
  chmod +x "$bin_dir/stow"
}

# A failed stow may partially modify tracked package files. The helper must
# restore those files, record the failure, and allow later packages to run.
(
  repo="$TMP_DIR/failure-repo"
  home="$TMP_DIR/failure-home"
  bin_dir="$TMP_DIR/failure-bin"
  calls="$TMP_DIR/failure-calls"
  make_repo "$repo"
  mkdir -p "$home"
  : > "$calls"
  make_fake_stow "$bin_dir"

  export HOME="$home"
  export PATH="$bin_dir:$PATH"
  export STOW_CALLS="$calls"
  export STOW_FAIL_PACKAGE=pkg
  export STOW_MUTATE_FILE="$repo/pkg/.config/app.conf"

  # shellcheck source=../scripts/stow.sh
  source "$ROOT/scripts/stow.sh"
  do_stow pkg "$repo" >/dev/null 2>&1
  unset STOW_FAIL_PACKAGE STOW_MUTATE_FILE
  do_stow next "$repo" >/dev/null 2>&1

  assert_eq 'repository version' "$(tr -d '\n' < "$repo/pkg/.config/app.conf")" \
    'failed stow left a tracked package file modified'
  assert_contains "$calls" 'pkg'
  assert_contains "$calls" 'next'

  if report_stow_failures >"$TMP_DIR/failure-report" 2>&1; then
    fail 'stow failure report unexpectedly returned success'
  fi
  assert_contains "$TMP_DIR/failure-report" 'pkg: stow command failed'
)

# Absolute leaf symlinks outside the package block GNU Stow. A successful real
# Stow run must replace the blocker with a valid managed link while preserving
# the original symlink destination.
if command -v stow >/dev/null 2>&1; then
  (
    repo="$TMP_DIR/symlink-repo"
    home="$TMP_DIR/symlink-home"
    legacy="$TMP_DIR/legacy-app.conf"
    make_repo "$repo"
    mkdir -p "$home/.config"
    printf 'legacy data\n' > "$legacy"
    ln -s "$legacy" "$home/.config/app.conf"

    export HOME="$home"

    # shellcheck source=../scripts/stow.sh
    source "$ROOT/scripts/stow.sh"
    do_stow pkg "$repo" >/dev/null 2>&1

    [ -L "$home/.config/app.conf" ] || fail 'successful stow did not create a managed target symlink'
    case "$(readlink "$home/.config/app.conf")" in
      /*) fail 'successful stow left an absolute target symlink in HOME' ;;
    esac
    assert_eq 'repository version' "$(tr -d '\n' < "$home/.config/app.conf")" \
      'managed target symlink does not expose the repository version'
    assert_eq 'legacy data' "$(tr -d '\n' < "$legacy")" \
      'absolute symlink destination was modified or deleted'
    [ -z "$(git -C "$repo" status --short -- pkg)" ] || \
      fail 'absolute symlink replacement left the package dirty'
    report_stow_failures >/dev/null 2>&1 || fail 'successful stow recorded a failure'
  )
fi

# If Stow fails after an absolute leaf symlink was removed, restore that exact
# symlink so a failed setup does not alter the user's HOME.
(
  repo="$TMP_DIR/symlink-failure-repo"
  home="$TMP_DIR/symlink-failure-home"
  bin_dir="$TMP_DIR/symlink-failure-bin"
  calls="$TMP_DIR/symlink-failure-calls"
  legacy="$TMP_DIR/symlink-failure-legacy.conf"
  make_repo "$repo"
  mkdir -p "$home/.config"
  printf 'legacy data\n' > "$legacy"
  ln -s "$legacy" "$home/.config/app.conf"
  : > "$calls"
  make_fake_stow "$bin_dir"

  export HOME="$home"
  export PATH="$bin_dir:$PATH"
  export STOW_CALLS="$calls"
  export STOW_FAIL_PACKAGE=pkg
  export STOW_REPLACEMENT_LINK_PATH="$home/.config/app.conf"
  export STOW_REPLACEMENT_LINK_TARGET="$repo/pkg/.config/app.conf"

  # shellcheck source=../scripts/stow.sh
  source "$ROOT/scripts/stow.sh"
  do_stow pkg "$repo" >/dev/null 2>&1

  [ -L "$home/.config/app.conf" ] || fail 'failed stow did not restore the absolute leaf symlink'
  assert_eq "$legacy" "$(readlink "$home/.config/app.conf")" \
    'failed stow restored the leaf symlink with the wrong destination'
  assert_eq 'legacy data' "$(tr -d '\n' < "$legacy")" \
    'failed stow modified the absolute symlink destination'
  if report_stow_failures >/dev/null 2>&1; then
    fail 'failed stow through an absolute leaf symlink was not reported'
  fi
)

# A parent directory symlink can represent an entire external configuration
# tree. Never remove it merely because a package owns files below that path.
(
  repo="$TMP_DIR/parent-symlink-repo"
  home="$TMP_DIR/parent-symlink-home"
  bin_dir="$TMP_DIR/parent-symlink-bin"
  calls="$TMP_DIR/parent-symlink-calls"
  external_config="$TMP_DIR/external-config"
  make_repo "$repo"
  mkdir -p "$home" "$external_config"
  printf 'external sibling\n' > "$external_config/sibling.conf"
  ln -s "$external_config" "$home/.config"
  : > "$calls"
  make_fake_stow "$bin_dir"

  export HOME="$home"
  export PATH="$bin_dir:$PATH"
  export STOW_CALLS="$calls"
  export STOW_FAIL_PACKAGE=pkg

  # shellcheck source=../scripts/stow.sh
  source "$ROOT/scripts/stow.sh"
  do_stow pkg "$repo" >/dev/null 2>&1

  [ -L "$home/.config" ] || fail 'stow cleanup removed an absolute parent-directory symlink'
  assert_eq "$external_config" "$(readlink "$home/.config")" \
    'absolute parent-directory symlink destination changed'
  assert_eq 'external sibling' "$(tr -d '\n' < "$external_config/sibling.conf")" \
    'external configuration tree was modified'
)

# Real GNU Stow integration: adopting a conflicting file must preserve the
# repository version, create a managed link in HOME, and remain rerunnable.
if command -v stow >/dev/null 2>&1; then
  (
    repo="$TMP_DIR/integration-repo"
    home="$TMP_DIR/integration-home"
    make_repo "$repo"
    mkdir -p "$home/.config"
    printf 'local conflicting version\n' > "$home/.config/app.conf"

    export HOME="$home"

    # shellcheck source=../scripts/stow.sh
    source "$ROOT/scripts/stow.sh"
    do_stow pkg "$repo" >/dev/null 2>&1

    [ -L "$home/.config/app.conf" ] || fail 'stow did not replace the conflict with a managed symlink'
    assert_eq 'repository version' "$(tr -d '\n' < "$home/.config/app.conf")" \
      'stowed HOME file does not expose the repository version'
    [ -z "$(git -C "$repo" status --short -- pkg)" ] || \
      fail 'successful adoption left the package dirty'

    do_stow pkg "$repo" >/dev/null 2>&1
    [ -L "$home/.config/app.conf" ] || fail 'rerunning stow broke the managed symlink'
    [ -z "$(git -C "$repo" status --short -- pkg)" ] || \
      fail 'rerunning stow left the package dirty'
    report_stow_failures >/dev/null 2>&1 || fail 'idempotent rerun recorded a failure'
  )
fi

printf 'PASS: stow behavior tests\n'
