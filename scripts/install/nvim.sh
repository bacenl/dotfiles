#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS and _sudo already defined (source pkgs.sh first).

NVIM_VERSION="${NVIM_VERSION:-0.11.0}"

install_nvim() {
  echo "[install] neovim $NVIM_VERSION on $OS"
  case "$OS" in
    arch)
      _sudo pacman -S --noconfirm --needed neovim
      ;;
    macos)
      brew install neovim
      ;;
    fedora)
      _sudo dnf install -y neovim
      ;;
    alpine)
      _sudo apk add --no-cache neovim
      local installed_ver
      installed_ver=$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+')
      local major minor
      major=$(echo "$installed_ver" | cut -d. -f1)
      minor=$(echo "$installed_ver" | cut -d. -f2)
      if [ "$major" -lt 1 ] && [ "$minor" -lt 11 ]; then
        echo "[warn] Alpine neovim is $installed_ver — expected 0.11+. Config may not work." >&2
      fi
      ;;
    debian)
      _install_nvim_debian
      ;;
    *)
      echo "[error] unsupported OS for neovim install: $OS" >&2
      return 1
      ;;
  esac
}

_install_nvim_debian() {
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
  local tmp
  tmp=$(mktemp -d)

  echo "[download] $url"
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  # The extracted dir is e.g. nvim-linux-x86_64/
  local extracted_dir
  extracted_dir=$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)

  _sudo cp -r "$extracted_dir/." /usr/local/
  rm -rf "$tmp"

  echo "[ok] neovim installed to /usr/local/bin/nvim"
}
