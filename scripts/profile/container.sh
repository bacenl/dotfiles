#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins,
# _log_setup_fail, _report_setup_failures
# already defined (sourced by setup.sh before calling this).
#
# Arguments:
#   $1 - dotfiles_dir
#   $2 - desktop flag: "omarchy" | "hypr" | ""

# _step <label> <command...>
# Runs a non-critical step, warning on failure without aborting.
_step() {
  local label="$1"; shift
  if ! "$@"; then
    echo "[warn] $label failed — continuing" >&2
    _log_setup_fail "$label"
    return 0
  fi
}

run_container_profile() {
  local dotfiles_dir="$1"

  echo ""
  echo "==> [container] Installing packages"

  install_nvim

  local pkgs=(tmux fzf ripgrep bat zoxide fish node npm)
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  # yazi: install if available, skip otherwise (handled by resolve_pkg_name)
  install_pkg yazi

  echo ""
  echo "==> [container] Stowing configs"

  local stow_targets=(nvim tmux fish claude pi npm)
  for target in "${stow_targets[@]}"; do
    _step "stow $target" do_stow "$target" "$dotfiles_dir"
  done

  # Only stow yazi if it was installed (not skipped)
  local yazi_pkg
  yazi_pkg=$(resolve_pkg_name yazi "$OS")
  if [ -n "$yazi_pkg" ]; then
    _step "stow yazi" do_stow yazi "$dotfiles_dir"
  else
    echo "[skip] stow: yazi not installed on $OS"
  fi

  echo ""
  echo "==> [container] Setting up tmux plugins"
  _step "tmux plugins" setup_tmux_plugins

  echo ""
  echo "==> [container] Installing pi packages"
  _step "pi settings profile" select_pi_settings_profile "$dotfiles_dir" devcontainer
  _step "pi packages" install_pi_packages "$dotfiles_dir" devcontainer

  _report_setup_failures "container"

  echo ""
  echo "[done] container profile complete"
}
