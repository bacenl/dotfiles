#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins
# already defined (sourced by setup.sh before calling this).
#
# Arguments:
#   $1 - dotfiles_dir
#   $2 - desktop flag: "omarchy" | "hypr" | ""

run_personal_profile() {
  local dotfiles_dir="$1"
  local desktop_flag="${2:-}"

  echo ""
  echo "==> [personal] Installing packages"

  install_nvim

  local pkgs=(tmux fzf ripgrep bat zoxide fish kitty node python go gcc "g++")
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  install_pkg yazi

  echo ""
  echo "==> [personal] Stowing configs"

  local stow_targets=(nvim tmux fish kitty scripts)
  for target in "${stow_targets[@]}"; do
    do_stow "$target" "$dotfiles_dir"
  done

  # stow yazi only if it was installed
  local yazi_pkg
  yazi_pkg=$(resolve_pkg_name yazi "$OS")
  if [ -n "$yazi_pkg" ]; then
    do_stow yazi "$dotfiles_dir"
  else
    echo "[skip] stow: yazi not installed on $OS"
  fi

  # Desktop environment stowing (no installation — assumes already set up)
  case "$desktop_flag" in
    omarchy)
      echo ""
      echo "==> [personal] Stowing omarchy desktop configs"
      do_stow omarchy "$dotfiles_dir"
      do_stow hypr    "$dotfiles_dir"
      do_stow waybar  "$dotfiles_dir"
      ;;
    hypr)
      echo ""
      echo "==> [personal] Stowing hyprland configs"
      do_stow hypr   "$dotfiles_dir"
      do_stow waybar "$dotfiles_dir"
      ;;
  esac

  echo ""
  echo "==> [personal] Setting up tmux plugins"
  setup_tmux_plugins

  echo ""
  echo "[done] personal profile complete"
}
