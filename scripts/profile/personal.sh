#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins,
# reload_tmux_config
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

  local pkgs=(tmux fzf ripgrep bat zoxide fish kitty node npm python go gcc gh)
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  install_pkg yazi


  echo ""
  echo "==> [personal] Stowing configs"

  local stow_targets=(nvim tmux fish kitty scripts claude ssh pi pi-personal-tools npm)
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
      echo "==> [personal] Installing desktop applications"
      install_pkg vivaldi
      install_pkg syncthing
      systemctl --user enable --now syncthing.service
      omarchy default terminal kitty || echo "[warn] Kitty was installed but could not be selected automatically"

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
  reload_tmux_config

  echo ""
  echo "==> [personal] Installing pi packages"
  select_pi_settings_profile "$dotfiles_dir" personal
  install_pi_packages "$dotfiles_dir" personal

  echo ""
  echo "==> [personal] Enabling ssh-agent user socket"
  if command -v systemctl >/dev/null 2>&1 &&
     systemctl --user cat ssh-agent.socket >/dev/null 2>&1; then
    systemctl --user enable --now ssh-agent.socket
  else
    echo "[skip] ssh-agent socket: packaged user unit unavailable"
  fi

  if [ "$desktop_flag" = "omarchy" ]; then
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

    echo ""
    echo "==> [personal] Setting up NetworkManager (final automated step)"

    install_pkg networkmanager
    install_pkg wpa_supplicant
    install_pkg network-manager-applet
    install_pkg nm-connection-editor
    sudo systemctl stop iwd systemd-networkd 2>/dev/null || true
    sudo systemctl disable iwd systemd-networkd 2>/dev/null || true
    sudo systemctl enable --now NetworkManager

    if command -v yay &>/dev/null; then
      yay -S --noconfirm gazelle-tui
    fi
  fi

  echo ""
  echo "[done] personal profile complete"

  if [ "$desktop_flag" = "omarchy" ]; then
    cat <<'EOF'

Final interactive setup:
  1. Run: gh auth login
  2. Open http://127.0.0.1:8384, pair Syncthing, and add your Obsidian and private folders.
  3. Run: fcitx5-config-qt
     Add the Japanese and Chinese input methods you use.
  4. Reboot.

After reboot, verify Vivaldi, Kitty, tmux plugins, Syncthing, and SSH access.
See INSTALL.md for details.
EOF
  fi
}
