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

# Run a command with sudo only when not root.
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

# _install_github_deb <tool> <repo>
# Resolves the latest amd64 .deb for a GitHub release and installs it.
_install_github_deb() {
  local tool="$1" repo="$2"
  local release_json
  release_json=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")
  local download_url
  download_url=$(echo "$release_json" \
    | grep -o '"browser_download_url": "[^"]*amd64.deb"' \
    | grep -v musl \
    | head -1 \
    | sed 's/.*: "\(.*\)"/\1/')
  if [ -z "$download_url" ]; then
    echo "[error] could not resolve $tool release URL" >&2
    return 1
  fi
  echo "[install] $tool from GitHub ($download_url)"
  local tmpdeb
  tmpdeb=$(mktemp /tmp/pkg-XXXXXX.deb)
  curl -fsSL "$download_url" -o "$tmpdeb" && _sudo dpkg -i "$tmpdeb" && rm -f "$tmpdeb"
}

# install_pkg <logical-name>
# Resolves and installs the package for the current $OS.
# Warns on failure but does not abort — individual packages are non-critical.
install_pkg() {
  local name="$1"
  local pkg
  pkg=$(resolve_pkg_name "$name" "$OS")

  if [ -z "$pkg" ]; then
    echo "[skip] $name not available on $OS"
    return 0
  fi

  echo "[install] $name ($pkg) on $OS"

  local ok=0
  case "$OS" in
    arch)
      _sudo pacman -S --noconfirm --needed "$pkg" || ok=1
      ;;
    debian)
      if [[ "$pkg" == __github__* ]]; then
        local tool="${pkg#__github__}"
        _install_github_deb "$tool" "sharkdp/${tool}" || ok=1
      else
        _sudo apt-get install -y "$pkg" || ok=1
      fi
      ;;
    macos)
      if [[ "$pkg" == __cask__* ]]; then
        brew install --cask "${pkg#__cask__}" || ok=1
      else
        brew install "$pkg" || ok=1
      fi
      ;;
    fedora)
      _sudo dnf install -y "$pkg" || ok=1
      ;;
    alpine)
      _sudo apk add --no-cache "$pkg" || ok=1
      ;;
    *)
      echo "[error] unsupported OS: $OS" >&2
      return 1
      ;;
  esac

  if [ "$ok" -ne 0 ]; then
    echo "[warn] failed to install $name — continuing without it" >&2
    # Log to failure summary if the global helper is available.
    if declare -f _log_setup_fail >/dev/null 2>&1; then
      _log_setup_fail "install $name"
    fi
    return 0
  fi
}
