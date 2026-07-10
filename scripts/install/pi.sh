#!/usr/bin/env bash
set -euo pipefail

# _pi_is_working
# Returns 0 if pi is installed and actually runs (not just a broken symlink).
_pi_is_working() {
  command -v pi >/dev/null 2>&1 && pi --version >/dev/null 2>&1
}

# install_pi_cli
# Installs pi when it is missing. Requires node/npm to already be available.
# Warns on failure but does not abort.
install_pi_cli() {
  if _pi_is_working; then
    echo "[skip] pi CLI already installed"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "[skip] pi CLI install: npm not found" >&2
    return 0
  fi

  echo "[install] pi CLI"
  # Use the same flags as the official pi.dev/install.sh:
  # --min-release-age=0 bypasses npm's release-age gate
  # --no-fund --no-audit reduce noise
  # --loglevel=error shows real errors without verbose output
  if ! npm install -g --ignore-scripts \
    --min-release-age=0 \
    --no-fund --no-audit \
    --loglevel=error \
    --progress=false \
    @earendil-works/pi-coding-agent; then
    echo "[warn] pi CLI install failed" >&2
    return 0
  fi

  # Verify the install actually produced a working binary.
  if ! _pi_is_working; then
    echo "[warn] pi install produced broken binary — skipping pi packages" >&2
    return 0
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
# Individual plugin failures are non-fatal.
install_pi_packages() {
  local dotfiles_dir="$1"
  local profile="${2:-personal}"
  local pi_settings="$HOME/.pi/agent/settings.json"

  install_pi_cli

  if ! _pi_is_working; then
    echo "[skip] pi packages: pi not working"
    return 0
  fi

  if [ ! -f "$pi_settings" ]; then
    echo "[skip] pi packages: settings.json missing"
    return 0
  fi

  echo "[sync] pi packages from $pi_settings"
  node -e "
    const fs = require('fs');
    const s = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    for (const p of s.packages || []) {
      const source = typeof p === 'string' ? p : p && p.source;
      if (source) process.stdout.write(source + '\\n');
    }
  " "$pi_settings" | while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    echo "[pi] installing package: $pkg"
    pi install "$pkg" || echo "[warn] pi install failed for: $pkg" >&2
  done

  if [ "$profile" = "personal" ]; then
    apply_pi_local_patches "$dotfiles_dir"
  else
    echo "[skip] pi local patches: profile $profile"
  fi
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
