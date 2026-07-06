#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins
# already defined (sourced by setup.sh before calling this).

run_container_profile() {
  local dotfiles_dir="$1"

  echo ""
  echo "==> [container] Installing packages"

  install_nvim

  local pkgs=(tmux fzf ripgrep bat zoxide node npm)
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  # yazi: install if available, skip otherwise (handled by resolve_pkg_name)
  install_pkg yazi

  echo ""
  echo "==> [container] Stowing configs"

  do_stow nvim            "$dotfiles_dir"
  do_stow tmux            "$dotfiles_dir"
  do_stow claude          "$dotfiles_dir"
  do_stow pi              "$dotfiles_dir"
  do_stow npm             "$dotfiles_dir"

  # Only stow yazi if it was installed (not skipped)
  local yazi_pkg
  yazi_pkg=$(resolve_pkg_name yazi "$OS")
  if [ -n "$yazi_pkg" ]; then
    do_stow yazi "$dotfiles_dir"
  else
    echo "[skip] stow: yazi not installed on $OS"
  fi

  echo ""
  echo "==> [container] Setting up tmux plugins"
  setup_tmux_plugins

  echo ""
  echo "==> [container] Installing pi packages"
  select_pi_settings_profile "$dotfiles_dir" devcontainer
  install_pi_packages "$dotfiles_dir" devcontainer

  echo ""
  echo "[done] container profile complete"
}
