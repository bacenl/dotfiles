#!/usr/bin/env bash
set -euo pipefail

# _pi_is_working
# Returns 0 if pi is installed and actually runs (not just a broken symlink).
_pi_is_working() {
  command -v pi >/dev/null 2>&1 && pi --version >/dev/null 2>&1
}

_pi_add_local_bin_to_path() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
  hash -r 2>/dev/null || true
}

# install_pi_cli
# Installs pi when it is missing using Pi's official user-local installer.
# Returns nonzero on failure so the profile can record it in the final summary.
install_pi_cli() {
  _pi_add_local_bin_to_path

  if _pi_is_working; then
    echo "[skip] pi CLI already installed"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "[error] pi CLI install requires curl; install curl and rerun setup" >&2
    return 1
  fi

  echo "[install] pi CLI via https://pi.dev/install.sh"
  if ! curl -fsSL https://pi.dev/install.sh | sh; then
    echo "[error] pi CLI install failed; check network access to https://pi.dev/install.sh and rerun setup" >&2
    return 1
  fi

  _pi_add_local_bin_to_path

  # Verify the install actually produced a working binary.
  if ! _pi_is_working; then
    echo "[error] pi installer completed but pi is not working; verify $HOME/.local/bin/pi and rerun setup" >&2
    return 1
  fi
}


# select_pi_settings_profile <dotfiles_dir> <personal|devcontainer>
# Points ~/.pi/agent/settings.json at the profile-specific package list.
select_pi_settings_profile() {
  local dotfiles_dir="$1"
  local profile="$2"
  local src="$dotfiles_dir/pi-$profile/.pi/agent/settings.json"
  local dest="$HOME/.pi/agent/settings.json"

  if [ ! -f "$src" ]; then
    echo "[error] missing pi settings profile: $src" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  echo "[pi] selected settings profile: $profile"
}

# install_pi_packages <dotfiles_dir> [personal|devcontainer]
# Reconciles the pi package list recorded in ~/.pi/agent/settings.json.
# Attempts every package, then returns nonzero if parsing or installation failed.
install_pi_packages() {
  local dotfiles_dir="$1"
  local profile="${2:-personal}"
  local pi_settings="$HOME/.pi/agent/settings.json"

  if ! install_pi_cli; then
    return 1
  fi

  if ! _pi_is_working; then
    echo "[error] pi packages were not installed because pi is not working; rerun setup after fixing Pi" >&2
    return 1
  fi

  if [ ! -f "$pi_settings" ]; then
    echo "[skip] pi packages: settings.json missing"
    return 0
  fi

  echo "[sync] pi packages from $pi_settings"
  local package_output
  if ! package_output=$(node -e "
    const fs = require('fs');
    const s = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    for (const p of s.packages || []) {
      const source = typeof p === 'string' ? p : p && p.source;
      if (source) process.stdout.write(source + '\\n');
    }
  " "$pi_settings"); then
    echo "[error] could not read Pi packages from $pi_settings; fix the JSON and rerun setup" >&2
    if declare -f _log_setup_fail >/dev/null 2>&1; then
      _log_setup_fail "read Pi package settings"
    fi
    return 1
  fi

  local package_status=0
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    echo "[pi] installing package: $pkg"
    if ! pi install "$pkg"; then
      echo "[error] pi install failed for: $pkg; fix the package source and rerun setup" >&2
      if declare -f _log_setup_fail >/dev/null 2>&1; then
        _log_setup_fail "pi install $pkg"
      fi
      package_status=1
    fi
  done <<< "$package_output"

  if [ "$profile" = "personal" ]; then
    apply_pi_local_patches "$dotfiles_dir"
  else
    echo "[skip] pi local patches: profile $profile"
  fi

  return "$package_status"
}

# apply_pi_local_patches <dotfiles_dir>
# Reapplies local patches that are intentionally not upstream package state.
apply_pi_local_patches() {
  local dotfiles_dir="$1"
  local security_pkg="$HOME/.pi/agent/git/github.com/mwolff44/pi-secured-setup"
  local patch="$dotfiles_dir/pi-personal/.pi/agent/patches/pi-secured-setup-peon-approval.patch"
  local target="$security_pkg/lib/guard-pipeline.ts"

  if [ ! -d "$security_pkg/.git" ]; then
    echo "[skip] pi security patch: pi-secured-setup package not installed"
    return 0
  fi

  if [ ! -f "$patch" ]; then
    echo "[skip] pi security patch: patch file missing at $patch"
    return 0
  fi

  if grep -q 'playApprovalPromptSound' "$target" 2>/dev/null; then
    echo "[skip] pi security patch already applied"
    return 0
  fi

  echo "[patch] pi-secured-setup peon approval sound"
  if git -C "$security_pkg" apply --check "$patch"; then
    git -C "$security_pkg" apply "$patch"
  else
    echo "[warn] pi security patch did not apply cleanly; inspect $patch" >&2
  fi
}
