#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS and _sudo already defined (source pkgs.sh first).

NVIM_VERSION="${NVIM_VERSION:-0.11.0}"

install_nvim() {
  echo "[install] neovim $NVIM_VERSION on $OS"
  local ok=0
  case "$OS" in
    arch)
      _sudo pacman -S --noconfirm --needed neovim || ok=1
      ;;
    macos)
      brew install neovim || ok=1
      ;;
    fedora)
      _sudo dnf install -y neovim || ok=1
      ;;
    alpine)
      _sudo apk add --no-cache neovim || ok=1
      local installed_ver
      installed_ver=$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
      if [ -n "$installed_ver" ]; then
        local major minor
        major=$(echo "$installed_ver" | cut -d. -f1)
        minor=$(echo "$installed_ver" | cut -d. -f2)
        if [ "$major" -eq 0 ] && [ "$minor" -lt 11 ]; then
          echo "[warn] Alpine neovim is $installed_ver — expected 0.11+. Config may not work." >&2
        fi
      fi
      ;;
    debian)
      ( _install_nvim_debian ) || ok=1
      ;;
    *)
      echo "[error] unsupported OS for neovim install: $OS" >&2
      return 1
      ;;
  esac

  if [ "$ok" -ne 0 ]; then
    echo "[warn] neovim install failed — continuing" >&2
    if declare -f _log_setup_fail >/dev/null 2>&1; then
      _log_setup_fail "install neovim"
    fi
    return 0
  fi
}

_install_nvim_debian() {
  local tmp
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT

  local arch
  arch=$(uname -m)
  local tarball
  case "$arch" in
    x86_64)  tarball="nvim-linux-x86_64.tar.gz" ;;
    aarch64) tarball="nvim-linux-arm64.tar.gz" ;;
    *)
      echo "[error] unsupported arch for nvim tarball: $arch" >&2
      return 1
      ;;
  esac

  local url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${tarball}"

  echo "[download] $url"
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  # The extracted dir is e.g. nvim-linux-x86_64/
  local extracted_dir="${tarball%.tar.gz}"

  _sudo cp -r "$tmp/$extracted_dir/." /usr/local/

  echo "[ok] neovim installed to /usr/local/bin/nvim"
}
