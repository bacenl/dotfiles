#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS and _sudo already defined (source pkgs.sh first).

NVIM_MIN_VERSION="${NVIM_MIN_VERSION:-0.11.2}"
NVIM_VERSION="${NVIM_VERSION:-0.11.2}"

_nvim_version_at_least() {
  local actual="${1#v}"
  local required="${2#v}"
  local -a actual_parts required_parts
  local i actual_part required_part

  [[ "$actual" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || return 1
  [[ "$required" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || return 1

  IFS=. read -r -a actual_parts <<< "$actual"
  IFS=. read -r -a required_parts <<< "$required"

  for i in 0 1 2; do
    actual_part="${actual_parts[$i]:-0}"
    required_part="${required_parts[$i]:-0}"
    if (( 10#$actual_part > 10#$required_part )); then
      return 0
    fi
    if (( 10#$actual_part < 10#$required_part )); then
      return 1
    fi
  done
  return 0
}

_nvim_installed_version() {
  nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

install_nvim() {
  echo "[install] neovim $NVIM_VERSION on $OS"
  local ok=0

  if ! _nvim_version_at_least "$NVIM_VERSION" "$NVIM_MIN_VERSION"; then
    echo "[error] requested Neovim $NVIM_VERSION is below LazyVim minimum $NVIM_MIN_VERSION" >&2
    ok=1
  fi

  if [ "$ok" -ne 0 ]; then
    _nvim_report_install_failure
    return 0
  fi

  local existing_ver
  existing_ver=$(_nvim_installed_version || true)
  if [ -n "$existing_ver" ] && _nvim_version_at_least "$existing_ver" "$NVIM_MIN_VERSION"; then
    echo "[skip] neovim $existing_ver already satisfies LazyVim minimum $NVIM_MIN_VERSION"
    return 0
  fi

  case "$OS" in
    arch)
      if ! _sudo pacman -S --noconfirm --needed neovim; then
        echo "[warn] Arch package install failed; trying upstream Neovim $NVIM_VERSION" >&2
        ( _install_nvim_release ) || ok=1
        hash -r 2>/dev/null || true
      fi
      ;;
    macos)
      brew install neovim || ok=1
      ;;
    fedora)
      if ! _sudo dnf install -y neovim; then
        echo "[warn] Fedora package install failed; trying upstream Neovim $NVIM_VERSION" >&2
        ( _install_nvim_release ) || ok=1
        hash -r 2>/dev/null || true
      fi
      ;;
    alpine)
      _sudo apk add --no-cache neovim || ok=1
      ;;
    debian)
      ( _install_nvim_release ) || ok=1
      ;;
    *)
      echo "[error] unsupported OS for neovim install: $OS" >&2
      return 1
      ;;
  esac

  if [ "$ok" -eq 0 ]; then
    local installed_ver
    installed_ver=$(_nvim_installed_version || true)
    if [ -z "$installed_ver" ] || ! _nvim_version_at_least "$installed_ver" "$NVIM_MIN_VERSION"; then
      echo "[warn] installed Neovim ${installed_ver:-unknown} is below LazyVim minimum $NVIM_MIN_VERSION" >&2
      case "$OS" in
        arch|fedora)
          echo "[install] replacing stale distro Neovim with upstream release $NVIM_VERSION"
          ( _install_nvim_release ) || ok=1
          hash -r 2>/dev/null || true
          ;;
        macos)
          echo "[install] upgrading Neovim with Homebrew"
          brew upgrade neovim || ok=1
          ;;
        alpine)
          echo "[error] Alpine's Neovim package is too old; enable a repository providing $NVIM_MIN_VERSION or newer and rerun setup" >&2
          ok=1
          ;;
        *) ok=1 ;;
      esac
    fi
  fi

  local final_ver
  final_ver=$(_nvim_installed_version || true)
  if [ "$ok" -ne 0 ] || [ -z "$final_ver" ] || ! _nvim_version_at_least "$final_ver" "$NVIM_MIN_VERSION"; then
    _nvim_report_install_failure
    return 0
  fi

  echo "[ok] neovim $final_ver satisfies LazyVim minimum $NVIM_MIN_VERSION"
}

_nvim_report_install_failure() {
  echo "[error] neovim $NVIM_MIN_VERSION or newer is required; fix the install and rerun setup" >&2
  if declare -f _log_setup_fail >/dev/null 2>&1; then
    _log_setup_fail "install neovim >= $NVIM_MIN_VERSION"
  fi
}

_install_nvim_release() {
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
