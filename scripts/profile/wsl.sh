#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins,
# reload_tmux_config, _log_setup_fail, _report_setup_failures
# already defined (sourced by setup.sh before calling this).

_step() {
  local label="$1"; shift
  if ! "$@"; then
    echo "[warn] $label failed — continuing" >&2
    _log_setup_fail "$label"
    return 0
  fi
}

run_wsl_profile() {
  local dotfiles_dir="$1"

  echo ""
  echo "==> [wsl] Installing packages"

  install_nvim

  local pkgs=(tmux fzf ripgrep bat zoxide fish node npm python go gcc gh)
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  install_pkg yazi

  echo ""
  echo "==> [wsl] Stowing configs into $HOME"

  # Keep the checkout and HOME in WSL's Linux filesystem. Windows projects can
  # still be edited under /mnt/c without creating Windows-hosted stow links.
  local stow_targets=(nvim tmux fish scripts claude pi npm)
  for target in "${stow_targets[@]}"; do
    _step "stow $target" do_stow "$target" "$dotfiles_dir"
  done

  local yazi_pkg
  yazi_pkg=$(resolve_pkg_name yazi "$OS")
  if [ -n "$yazi_pkg" ]; then
    _step "stow yazi" do_stow yazi "$dotfiles_dir"
  else
    echo "[skip] stow: yazi not installed on $OS"
  fi

  echo ""
  echo "==> [wsl] Setting up tmux plugins"
  _step "tmux plugins" setup_tmux_plugins
  reload_tmux_config

  echo ""
  echo "==> [wsl] Installing personal Pi packages"
  _step "pi settings profile" select_pi_settings_profile "$dotfiles_dir" personal
  _step "pi packages" install_pi_packages "$dotfiles_dir" personal

  _report_setup_failures "wsl"

  echo ""
  echo "[done] wsl profile complete"
}
