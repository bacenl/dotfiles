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
      installed_ver=$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
      if [ -z "$installed_ver" ]; then
        echo "[warn] Could not determine installed neovim version." >&2
      else
        local major minor
        major=$(echo "$installed_ver" | cut -d. -f1)
        minor=$(echo "$installed_ver" | cut -d. -f2)
        if [ "$major" -eq 0 ] && [ "$minor" -lt 11 ]; then
          echo "[warn] Alpine neovim is $installed_ver — expected 0.11+. Config may not work." >&2
        fi
      fi
      ;;
    debian)
      ( _install_nvim_debian )
      ;;
    *)
      echo "[error] unsupported OS for neovim install: $OS" >&2
      return 1
      ;;
  esac
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
