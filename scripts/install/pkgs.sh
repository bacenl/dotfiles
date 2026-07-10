#!/usr/bin/env bash
set -euo pipefail

# Usage: source this file. Sets global $OS to one of:
#   arch | debian | macos | fedora | alpine | unknown

detect_os() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "macos"
    return
  fi
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
      arch)                    echo "arch" ;;
      ubuntu|debian|raspbian)  echo "debian" ;;
      fedora|rhel|centos)      echo "fedora" ;;
      alpine)                  echo "alpine" ;;
      *)                       echo "unknown" ;;
    esac
    return
  fi
  echo "unknown"
}

OS=$(detect_os)

# Run a command with sudo only when not already root.
_sudo() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# resolve_pkg_name <logical-name> <os>
# Prints the distro-specific package name, or empty string to skip.
resolve_pkg_name() {
  local name="$1" os="$2"
  case "${name}:${os}" in
    # bat: Debian/Ubuntu — not reliably in apt; install from GitHub release
    bat:debian)        echo "__github__bat" ;;
    # node package name varies
    node:arch)          echo "nodejs" ;;
    node:debian)        echo "nodejs" ;;
    node:fedora)        echo "nodejs" ;;
    node:alpine)        echo "nodejs" ;;
    # python package name varies
    python:debian)      echo "python3" ;;
    python:fedora)      echo "python3" ;;
    python:alpine)      echo "python3" ;;
    # go package name varies
    go:debian)          echo "golang" ;;
    go:fedora)          echo "golang" ;;
    # yazi not available on Debian/Alpine
    yazi:debian)        echo "" ;;
    yazi:alpine)        echo "" ;;
    # gh CLI package name on Arch
    gh:arch)            echo "github-cli" ;;
    # gcc/g++ on macOS handled by Xcode CLI — skip via brew
    gcc:macos)          echo "" ;;
    "g++:macos")        echo "" ;;
    # g++ package name on Fedora and Alpine
    "g++:fedora")       echo "gcc-c++" ;;
    "g++:alpine")       echo "g++" ;;
    # kitty on macOS is a cask
    kitty:macos)        echo "__cask__kitty" ;;
    # Default: package name == logical name
    *)                  echo "$name" ;;
  esac
}

# install_pkg <logical-name>
# Resolves and installs the package for the current $OS.
install_pkg() {
  local name="$1"
  local pkg
  pkg=$(resolve_pkg_name "$name" "$OS")

  if [ -z "$pkg" ]; then
    echo "[skip] $name not available on $OS"
    return 0
  fi

  echo "[install] $name ($pkg) on $OS"

  case "$OS" in
    arch)
      _sudo pacman -S --noconfirm --needed "$pkg"
      ;;
    debian)
      if [[ "$pkg" == __github__* ]]; then
        local tool="${pkg#__github__}"
        local url="https://github.com/sharkdp/${tool}/releases/latest/download/${tool}_x86_64.deb"
        echo "[install] $name from GitHub ($url)"
        local tmpdeb
        tmpdeb=$(mktemp /tmp/bat-XXXXXX.deb)
        curl -fsSL "$url" -o "$tmpdeb" && _sudo dpkg -i "$tmpdeb" && rm -f "$tmpdeb"
      else
        _sudo apt-get install -y "$pkg"
      fi
      ;;
    macos)
      if [[ "$pkg" == __cask__* ]]; then
        brew install --cask "${pkg#__cask__}"
      else
        brew install "$pkg"
      fi
      ;;
    fedora)
      _sudo dnf install -y "$pkg"
      ;;
    alpine)
      _sudo apk add --no-cache "$pkg"
      ;;
    *)
      echo "[error] unsupported OS: $OS" >&2
      return 1
      ;;
  esac
}
