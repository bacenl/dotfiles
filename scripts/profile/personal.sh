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

  local pkgs=(tmux fzf ripgrep bat zoxide fish kitty node python go gcc)
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  install_pkg yazi

  if command -v yay &>/dev/null; then
    yay -S --noconfirm gazelle-tui
  fi

  echo ""
  echo "==> [personal] Stowing configs"

  local stow_targets=(nvim tmux fish kitty scripts claude ssh)
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

  # Desktop environment setup (stow configs + omarchy-specific installs)
  case "$desktop_flag" in
    omarchy)
      echo ""
      echo "==> [personal] Stowing omarchy desktop configs"
      do_stow omarchy "$dotfiles_dir"
      do_stow hypr    "$dotfiles_dir"
      do_stow waybar  "$dotfiles_dir"

      echo ""
      echo "==> [personal] Setting up NetworkManager (replacing iwd for 802.1X support)"
      install_pkg networkmanager
      install_pkg wpa_supplicant
      install_pkg network-manager-applet
      install_pkg nm-connection-editor
      sudo systemctl stop iwd systemd-networkd 2>/dev/null || true
      sudo systemctl disable iwd systemd-networkd 2>/dev/null || true
      sudo systemctl enable --now NetworkManager
      local waybar_cfg="$HOME/.config/waybar/config.jsonc"
      if [ -f "$waybar_cfg" ]; then
        sed -i 's|"on-click": "omarchy-launch-wifi"|"on-click": "nm-applet --indicator"|g' "$waybar_cfg"
      fi

      echo ""
      echo "==> [personal] Installing interception tools (caps2esc)"
      install_pkg interception-tools
      install_pkg interception-caps2esc
      local caps2esc_conf="/etc/interception/udevmon.d/caps2esc.yaml"
      if [ ! -f "$caps2esc_conf" ]; then
        sudo mkdir -p "$(dirname "$caps2esc_conf")"
        sudo tee "$caps2esc_conf" > /dev/null <<'CAPS2ESC'
- JOB: "intercept -g $DEVNODE | caps2esc -m 1 | uinput -d $DEVNODE"
  DEVICE:
    EVENTS:
      EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
CAPS2ESC
      fi
      sudo systemctl enable --now udevmon.service

      echo ""
      echo "==> [personal] Installing Japanese and Chinese language support"
      local lang_pkgs=(
        noto-fonts-cjk noto-fonts-emoji
        fcitx5 fcitx5-mozc fcitx5-chinese-addons
        fcitx5-gtk fcitx5-qt fcitx5-configtool
      )
      for pkg in "${lang_pkgs[@]}"; do
        install_pkg "$pkg"
      done
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
  echo "==> [personal] Enabling ssh-agent user service"
  systemctl --user enable --now ssh-agent

  echo ""
  echo "[done] personal profile complete"
}
