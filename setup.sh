#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────
DOTFILES_REPO="https://github.com/bacenl/dotfiles"
DOTFILES_DIR="$HOME/dotfiles"
PROFILE=""
DESKTOP_FLAG=""
BOOTSTRAP="curl"
DOTFILES_REF="${DOTFILES_REF:-master}"
NVIM_VERSION="${NVIM_VERSION:-0.11.0}"

# ──────────────────────────────────────────────
# Arg parsing
# ──────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: setup.sh --profile <container|personal> [OPTIONS]

Options:
  --profile <container|personal>   Required. Which profile to install.
  --omarchy                        (personal only) Stow omarchy + hypr + waybar.
  --hypr                           (personal only) Stow hypr + waybar only.
  --bootstrap <curl|git>           How to clone dotfiles. Default: curl.
                                   curl: clone via HTTPS (no auth needed).
                                   git:  install git + gh first, then clone.
  --dotfiles-ref <ref>             Git tag, branch, or commit to check out.
                                   Default: master.
  --dotfiles-dir <path>            Where to clone dotfiles. Default: ~/dotfiles.
  --nvim-version <version>         Neovim version for Debian/Ubuntu. Default: 0.11.0.
  -h, --help                       Show this help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)        PROFILE="$2";        shift 2 ;;
    --omarchy)        DESKTOP_FLAG="omarchy"; shift ;;
    --hypr)           DESKTOP_FLAG="hypr";    shift ;;
    --bootstrap)      BOOTSTRAP="$2";      shift 2 ;;
    --dotfiles-ref)   DOTFILES_REF="$2";   shift 2 ;;
    --dotfiles-dir)   DOTFILES_DIR="$2";   shift 2 ;;
    --nvim-version)   NVIM_VERSION="$2";   shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "[error] unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────
# Validation
# ──────────────────────────────────────────────
if [ -z "$PROFILE" ]; then
  echo "[error] --profile is required" >&2
  usage
  exit 1
fi

if [ "$PROFILE" != "container" ] && [ "$PROFILE" != "personal" ]; then
  echo "[error] --profile must be 'container' or 'personal'" >&2
  exit 1
fi

if [ -n "$DESKTOP_FLAG" ] && [ "$PROFILE" != "personal" ]; then
  echo "[error] --omarchy and --hypr are only valid with --profile personal" >&2
  exit 1
fi

# ──────────────────────────────────────────────
# OS detection (inline — pkgs.sh not sourced yet)
# ──────────────────────────────────────────────
_detect_os_early() {
  if [ "$(uname)" = "Darwin" ]; then echo "macos"; return; fi
  if [ -f /etc/os-release ]; then
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

OS=$(_detect_os_early)

_sudo() {
  if [ "$(id -u)" = "0" ]; then "$@"; else sudo "$@"; fi
}

# ──────────────────────────────────────────────
# Bootstrap: install minimal deps before anything else
# ──────────────────────────────────────────────
_install_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "[bootstrap] installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

bootstrap_deps() {
  echo "[bootstrap] installing minimal dependencies on $OS"
  case "$OS" in
    arch)
      _sudo pacman -Sy --noconfirm --needed git curl stow
      ;;
    debian)
      _sudo apt-get update -qq
      _sudo apt-get install -y git curl stow
      ;;
    macos)
      _install_brew
      brew install stow git
      ;;
    fedora)
      _sudo dnf install -y git curl stow
      ;;
    alpine)
      _sudo apk add --no-cache git curl stow bash
      ;;
    *)
      echo "[warn] unknown OS — attempting to continue without bootstrapping" >&2
      ;;
  esac

  if [ "$BOOTSTRAP" = "git" ]; then
    echo "[bootstrap] installing gh (GitHub CLI)"
    case "$OS" in
      arch)    _sudo pacman -S --noconfirm --needed github-cli ;;
      debian)
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          | _sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | _sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        _sudo apt-get update -qq
        _sudo apt-get install -y gh
        ;;
      macos)   brew install gh ;;
      fedora)  _sudo dnf install -y gh ;;
      alpine)  _sudo apk add --no-cache github-cli ;;
    esac
  fi
}

# ──────────────────────────────────────────────
# Clone dotfiles repo
# ──────────────────────────────────────────────
clone_dotfiles() {
  if [ -d "$DOTFILES_DIR" ]; then
    echo "[skip] dotfiles already at $DOTFILES_DIR"
    return 0
  fi

  if [ "$BOOTSTRAP" = "git" ]; then
    echo "[clone] gh repo clone bacenl/dotfiles $DOTFILES_DIR"
    gh repo clone bacenl/dotfiles "$DOTFILES_DIR"
  else
    echo "[clone] git clone $DOTFILES_REPO $DOTFILES_DIR"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  echo "[clone] checking out $DOTFILES_REF"
  git -C "$DOTFILES_DIR" checkout --detach "$DOTFILES_REF"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
main() {
  echo "================================================"
  echo " dotfiles setup — profile: $PROFILE  OS: $OS"
  echo "================================================"

  bootstrap_deps
  clone_dotfiles

  # Source helpers (now that repo is present)
  # shellcheck source=scripts/install/pkgs.sh
  source "$DOTFILES_DIR/scripts/install/pkgs.sh"
  # shellcheck source=scripts/install/nvim.sh
  source "$DOTFILES_DIR/scripts/install/nvim.sh"
  # shellcheck source=scripts/stow.sh
  source "$DOTFILES_DIR/scripts/stow.sh"

  case "$PROFILE" in
    container)
      # shellcheck source=scripts/profile/container.sh
      source "$DOTFILES_DIR/scripts/profile/container.sh"
      run_container_profile "$DOTFILES_DIR"
      ;;
    personal)
      # shellcheck source=scripts/profile/personal.sh
      source "$DOTFILES_DIR/scripts/profile/personal.sh"
      run_personal_profile "$DOTFILES_DIR" "$DESKTOP_FLAG"
      ;;
  esac
}

main
