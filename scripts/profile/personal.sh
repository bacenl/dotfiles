#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins,
# reload_tmux_config, _log_setup_fail, _report_setup_failures
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
    _step "stow $target" do_stow "$target" "$dotfiles_dir"
  done

  # stow yazi only if it was installed
  local yazi_pkg
  yazi_pkg=$(resolve_pkg_name yazi "$OS")
  if [ -n "$yazi_pkg" ]; then
    _step "stow yazi" do_stow yazi "$dotfiles_dir"
  else
    echo "[skip] stow: yazi not installed on $OS"
  fi

  # ── pi daily capture timer (23:00 JST, before Hermes ingest at 23:30) ──
  echo ""
  echo "==> [personal] Setting up pi daily capture timer"
  local timer_dir="$HOME/.config/systemd/user"
  mkdir -p "$timer_dir"

  cat > "$timer_dir/pi-daily-capture.timer" <<'TIMER'
[Unit]
Description=Daily pi internship capture at 23:00 JST

[Timer]
OnCalendar=*-*-* 23:00:00
Persistent=true
TIMER

  cat > "$timer_dir/pi-daily-capture.service" <<'SERVICE'
[Unit]
Description=pi daily internship capture

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 %h/.pi/agent/pi_daily_capture/capture.py
StandardOutput=append:%h/.pi/agent/pi_daily_capture/cron.log
StandardError=append:%h/.pi/agent/pi_daily_capture/cron.log
SERVICE

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload
    if ! systemctl --user enable --now pi-daily-capture.timer 2>/dev/null; then
      echo "[warn] pi-daily-capture.timer could not be enabled" >&2
      _log_setup_fail "pi-daily-capture.timer"
    else
      echo "[timer] pi-daily-capture.timer enabled (23:00 JST)"
    fi
  else
    echo "[warn] systemctl not available; timer files written to $timer_dir"
  fi

  # Desktop environment setup (stow configs + omarchy-specific installs)
  case "$desktop_flag" in
    omarchy)
      echo ""
      echo "==> [personal] Stowing omarchy desktop configs"
      _step "stow omarchy" do_stow omarchy "$dotfiles_dir"
      _step "stow hypr" do_stow hypr    "$dotfiles_dir"
      _step "stow waybar" do_stow waybar  "$dotfiles_dir"

      echo ""
      echo "==> [personal] Installing desktop applications"
      install_pkg vivaldi
      install_pkg syncthing
      if ! systemctl --user enable --now syncthing.service 2>/dev/null; then
        echo "[warn] syncthing service could not be enabled" >&2
        _log_setup_fail "syncthing.service"
      fi
      omarchy default terminal kitty 2>/dev/null \
        || echo "[warn] Kitty was installed but could not be selected automatically"

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
      if ! sudo systemctl enable --now udevmon.service 2>/dev/null; then
        echo "[warn] udevmon service could not be enabled" >&2
        _log_setup_fail "udevmon.service"
      fi

      ;;
    hypr)
      echo ""
      echo "==> [personal] Stowing hyprland configs"
      _step "stow hypr" do_stow hypr   "$dotfiles_dir"
      _step "stow waybar" do_stow waybar "$dotfiles_dir"
      ;;
  esac

  echo ""
  echo "==> [personal] Setting up tmux plugins"
  _step "tmux plugins" setup_tmux_plugins
  reload_tmux_config

  echo ""
  echo "==> [personal] Installing pi packages"
  _step "pi settings profile" select_pi_settings_profile "$dotfiles_dir" personal
  _step "pi packages" install_pi_packages "$dotfiles_dir" personal

  # Copy security configs from pi-personal to ~/.pi/agent/security/
  # (pi-personal is not stowed — it lives alongside pi/ for settings.json)
  local security_src="$dotfiles_dir/pi-personal/.pi/agent/security"
  local security_dest="$HOME/.pi/agent/security"
  if [ -d "$security_src" ]; then
    mkdir -p "$security_dest"
    cp -n "$security_src"/*.json "$security_dest/"
    echo "[sync] pi security configs -> $security_dest"
  fi

  echo ""
  echo "==> [personal] Enabling ssh-agent user socket"
  if command -v systemctl >/dev/null 2>&1 &&
     systemctl --user cat ssh-agent.socket >/dev/null 2>&1; then
    if ! systemctl --user enable --now ssh-agent.socket 2>/dev/null; then
      echo "[warn] ssh-agent.socket could not be enabled" >&2
      _log_setup_fail "ssh-agent.socket"
    fi
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
    if ! sudo systemctl enable --now NetworkManager 2>/dev/null; then
      echo "[warn] NetworkManager could not be enabled" >&2
      _log_setup_fail "NetworkManager"
    fi

    if command -v yay &>/dev/null; then
      yay -S --noconfirm gazelle-tui 2>/dev/null \
        || echo "[warn] gazelle-tui could not be installed" >&2
    fi
  fi

  _report_setup_failures "personal"

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
