# Setup Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single `setup.sh` entry point that bootstraps, installs, and stows dotfile configs for two profiles (container, personal) across macOS, Arch, Ubuntu/Debian, Fedora, and Alpine.

**Architecture:** `setup.sh` parses flags, bootstraps minimal OS deps, clones the dotfiles repo if needed, sources `scripts/install/pkgs.sh` for OS-aware package installation, then delegates to the appropriate profile script. `stow.sh` provides an idempotent stow helper used by both profiles.

**Tech Stack:** Bash, GNU Stow, OS package managers (pacman/apt/brew/dnf/apk), TPM (tmux plugin manager)

---

## File Map

| File | Responsibility |
|------|---------------|
| `setup.sh` | Entry point: arg parsing, bootstrapping, clone, delegate to profile |
| `scripts/install/pkgs.sh` | OS detection, `install_pkg`, `resolve_pkg_name` |
| `scripts/install/nvim.sh` | Version-aware neovim installer |
| `scripts/stow.sh` | Idempotent `do_stow` helper + `setup_tmux_plugins` |
| `scripts/profile/container.sh` | Container profile: installs + stows |
| `scripts/profile/personal.sh` | Personal profile: installs + stows + optional flags |
| `INSTALL.md` | User-facing usage documentation |

---

## Task 1: Scaffold file structure

**Files:**
- Create: `setup.sh`
- Create: `scripts/install/pkgs.sh`
- Create: `scripts/install/nvim.sh`
- Create: `scripts/stow.sh`
- Create: `scripts/profile/container.sh`
- Create: `scripts/profile/personal.sh`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p scripts/install scripts/profile
```

- [ ] **Step 2: Create all files with shebangs**

`setup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

`scripts/install/pkgs.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

`scripts/install/nvim.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

`scripts/stow.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

`scripts/profile/container.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

`scripts/profile/personal.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

- [ ] **Step 3: Make all scripts executable**

```bash
chmod +x setup.sh scripts/install/pkgs.sh scripts/install/nvim.sh \
         scripts/stow.sh scripts/profile/container.sh scripts/profile/personal.sh
```

- [ ] **Step 4: Commit**

```bash
git add setup.sh scripts/
git commit -m "feat: scaffold setup script structure"
```

---

## Task 2: Implement `scripts/install/pkgs.sh`

**Files:**
- Modify: `scripts/install/pkgs.sh`

This file exposes two functions: `detect_os` and `install_pkg`. It is `source`d by `setup.sh` before anything else — `OS` is set as a global variable after sourcing.

- [ ] **Step 1: Write `detect_os`**

```bash
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
```

- [ ] **Step 2: Write `_sudo` helper (handles root in containers)**

Append to `scripts/install/pkgs.sh`:

```bash
# Run a command with sudo only when not already root.
_sudo() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  else
    sudo "$@"
  fi
}
```

- [ ] **Step 3: Write `resolve_pkg_name`**

Append to `scripts/install/pkgs.sh`:

```bash
# resolve_pkg_name <logical-name> <os>
# Prints the distro-specific package name, or empty string to skip.
resolve_pkg_name() {
  local name="$1" os="$2"
  case "${name}:${os}" in
    # bat is renamed on Debian/Ubuntu
    bat:debian)         echo "batcat" ;;
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
```

- [ ] **Step 4: Write `install_pkg`**

Append to `scripts/install/pkgs.sh`:

```bash
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
      _sudo apt-get install -y "$pkg"
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
```

- [ ] **Step 5: Verify syntax**

```bash
bash -n scripts/install/pkgs.sh
```
Expected: no output (no syntax errors).

- [ ] **Step 6: Commit**

```bash
git add scripts/install/pkgs.sh
git commit -m "feat: add OS-aware package installer (pkgs.sh)"
```

---

## Task 3: Implement `scripts/install/nvim.sh`

**Files:**
- Modify: `scripts/install/nvim.sh`

Neovim is installed via package manager on Arch/macOS/Fedora, and via GitHub releases tarball on Ubuntu/Debian (to get a modern version). Alpine uses the package manager with a version warning.

- [ ] **Step 1: Write `install_nvim`**

Replace contents of `scripts/install/nvim.sh`:

```bash
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n scripts/install/nvim.sh
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/install/nvim.sh
git commit -m "feat: add version-aware neovim installer (nvim.sh)"
```

---

## Task 4: Implement `scripts/stow.sh`

**Files:**
- Modify: `scripts/stow.sh`

Provides `do_stow` (idempotent, skips if target dir missing) and `setup_tmux_plugins` (headless TPM install).

- [ ] **Step 1: Write `do_stow`**

Replace contents of `scripts/stow.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# do_stow <pkg> <dotfiles_dir>
# Stows <pkg> from <dotfiles_dir> into $HOME. Idempotent.
# Skips with a warning if the stow target directory doesn't exist.
do_stow() {
  local pkg="$1"
  local dotfiles_dir="$2"

  if [ ! -d "$dotfiles_dir/$pkg" ]; then
    echo "[skip] stow: no directory $dotfiles_dir/$pkg"
    return 0
  fi

  echo "[stow] $pkg"
  stow --dir="$dotfiles_dir" --target="$HOME" --restow "$pkg"
}
```

- [ ] **Step 2: Write `setup_tmux_plugins`**

Append to `scripts/stow.sh`:

```bash
# setup_tmux_plugins
# Clones TPM if not present, then installs all plugins headlessly.
setup_tmux_plugins() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

  if [ ! -d "$tpm_dir" ]; then
    echo "[install] TPM (tmux plugin manager)"
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  else
    echo "[skip] TPM already installed"
  fi

  echo "[install] tmux plugins (headless)"
  "$tpm_dir/bin/install_plugins"
}
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n scripts/stow.sh
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/stow.sh
git commit -m "feat: add idempotent stow helper and tmux plugin setup (stow.sh)"
```

---

## Task 5: Implement `scripts/profile/container.sh`

**Files:**
- Modify: `scripts/profile/container.sh`

Installs the container toolset and stows nvim, tmux, yazi (yazi skipped on unsupported OSes).

- [ ] **Step 1: Write container profile**

Replace contents of `scripts/profile/container.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Requires: $OS, install_pkg, install_nvim, do_stow, setup_tmux_plugins
# already defined (sourced by setup.sh before calling this).

run_container_profile() {
  local dotfiles_dir="$1"

  echo ""
  echo "==> [container] Installing packages"

  install_nvim

  local pkgs=(tmux fzf ripgrep bat zoxide)
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  # yazi: install if available, skip otherwise (handled by resolve_pkg_name)
  install_pkg yazi

  echo ""
  echo "==> [container] Stowing configs"

  do_stow nvim "$dotfiles_dir"
  do_stow tmux "$dotfiles_dir"

  # Only stow yazi if it was installed (not skipped)
  local yazi_pkg
  yazi_pkg=$(resolve_pkg_name yazi "$OS")
  if [ -n "$yazi_pkg" ]; then
    do_stow yazi "$dotfiles_dir"
  else
    echo "[skip] stow: yazi not installed on $OS"
  fi

  echo ""
  echo "==> [container] Setting up tmux plugins"
  setup_tmux_plugins

  echo ""
  echo "[done] container profile complete"
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n scripts/profile/container.sh
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/profile/container.sh
git commit -m "feat: add container profile (container.sh)"
```

---

## Task 6: Implement `scripts/profile/personal.sh`

**Files:**
- Modify: `scripts/profile/personal.sh`

Installs the full personal toolset and stows configs. Handles `--omarchy` and `--hypr` flags.

- [ ] **Step 1: Write personal profile**

Replace contents of `scripts/profile/personal.sh`:

```bash
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

  local pkgs=(tmux fzf ripgrep bat zoxide fish kitty node python go gcc "g++")
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done

  install_pkg yazi

  echo ""
  echo "==> [personal] Stowing configs"

  local stow_targets=(nvim tmux fish kitty scripts)
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

  # Desktop environment stowing (no installation — assumes already set up)
  case "$desktop_flag" in
    omarchy)
      echo ""
      echo "==> [personal] Stowing omarchy desktop configs"
      do_stow omarchy "$dotfiles_dir"
      do_stow hypr    "$dotfiles_dir"
      do_stow waybar  "$dotfiles_dir"
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
  echo "[done] personal profile complete"
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n scripts/profile/personal.sh
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/profile/personal.sh
git commit -m "feat: add personal profile with --omarchy/--hypr support (personal.sh)"
```

---

## Task 7: Implement `setup.sh` (entry point)

**Files:**
- Modify: `setup.sh`

Parses all flags, bootstraps minimal deps, clones dotfiles if needed, sources helpers, and delegates to the right profile.

- [ ] **Step 1: Write full `setup.sh`**

Replace contents of `setup.sh`:

```bash
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
        # Official gh install for Debian/Ubuntu
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n setup.sh
```
Expected: no output.

- [ ] **Step 3: Dry-run check (no OS, no install)**

```bash
bash setup.sh --help
```
Expected: usage text printed, exit 0.

```bash
bash setup.sh 2>&1 || true
```
Expected: `[error] --profile is required`

```bash
bash setup.sh --profile personal --omarchy --profile container 2>&1 || true
```
Expected: `[error] --omarchy and --hypr are only valid with --profile personal`

- [ ] **Step 4: Commit**

```bash
git add setup.sh
git commit -m "feat: implement setup.sh entry point with bootstrap, clone, and profile delegation"
```

---

## Task 8: Write `INSTALL.md`

**Files:**
- Create: `INSTALL.md`

- [ ] **Step 1: Write `INSTALL.md`**

```markdown
# Installation

## Requirements

Only `bash` and internet access are required on a fresh system. Everything else is bootstrapped automatically.

---

## Quick Start

### Container (bare Ubuntu/Debian/Alpine/Arch — bash only)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh) --profile container
```

### Container via git (authenticated clone)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh) --profile container --bootstrap git
```

> `--bootstrap git` installs `git` and `gh` first, then clones via `gh repo clone`. You will be prompted to authenticate with GitHub.

---

## Personal Laptop

```bash
# Base setup (nvim, tmux, yazi, fzf, ripgrep, bat, zoxide, fish, kitty, node, python, go, gcc)
bash setup.sh --profile personal

# + omarchy desktop (stows omarchy + hypr + waybar — assumes omarchy already installed)
bash setup.sh --profile personal --omarchy

# + hyprland only (stows hypr + waybar — no omarchy)
bash setup.sh --profile personal --hypr
```

> Run `setup.sh` directly if the dotfiles repo is already cloned. Use the `curl` one-liner otherwise.

---

## Options

| Flag | Description |
|------|-------------|
| `--profile container\|personal` | **Required.** Which profile to install. |
| `--omarchy` | Personal only. Stow omarchy + hypr + waybar configs. |
| `--hypr` | Personal only. Stow hypr + waybar configs (no omarchy). |
| `--bootstrap curl\|git` | Clone method. Default: `curl` (HTTPS). Use `git` for authenticated access via `gh`. |
| `--dotfiles-dir <path>` | Override clone target. Default: `~/dotfiles`. |
| `--nvim-version <version>` | Neovim version for Ubuntu/Debian tarball install. Default: `0.11.0`. |

---

## What Gets Installed

### Container profile

| Tool | Notes |
|------|-------|
| neovim 0.11.x | Via tarball on Ubuntu/Debian; package manager elsewhere |
| tmux | + TPM plugins installed headlessly |
| yazi | Skipped on Ubuntu, Debian, Alpine (not packaged) |
| fzf, ripgrep, bat, zoxide | — |

**Stowed configs:** `nvim`, `tmux`, `yazi` (if installed)

### Personal profile

Everything in container, plus:

| Tool | Notes |
|------|-------|
| fish | — |
| kitty | — |
| node, python, go | — |
| gcc, g++ | On macOS: install Xcode Command Line Tools separately |

**Stowed configs:** `nvim`, `tmux`, `yazi`, `fish`, `kitty`, `scripts`

With `--omarchy`: also stows `omarchy`, `hypr`, `waybar`
With `--hypr`: also stows `hypr`, `waybar`

---

## Notes

- **Rust:** Not installed. Use [rustup](https://rustup.rs) separately.
- **macOS gcc/g++:** Not installed via brew. Install Xcode CLI tools: `xcode-select --install`
- **bat on Ubuntu/Debian:** Installed as `batcat`. Add `alias bat=batcat` to your shell config if needed.
- **Idempotent:** Safe to re-run. Existing dotfiles directory is never overwritten; stow uses `--restow`.
- **tmux plugins:** Installed headlessly via TPM — no running tmux session required.
```

- [ ] **Step 2: Commit**

```bash
git add INSTALL.md
git commit -m "docs: add INSTALL.md with usage instructions"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered in |
|-----------------|-----------|
| OS detection (arch/debian/macos/fedora/alpine) | Task 2 (`pkgs.sh`) |
| `install_pkg` with name remapping | Task 2 (`pkgs.sh`) |
| nvim 0.11.x via tarball on Ubuntu/Debian | Task 3 (`nvim.sh`) |
| yazi skip on debian/alpine | Task 2 (`resolve_pkg_name`) + Tasks 5/6 |
| Idempotent stow | Task 4 (`stow.sh`) |
| TPM headless install | Task 4 (`stow.sh`) |
| Container profile installs + stows | Task 5 |
| Personal profile installs + stows | Task 6 |
| `--omarchy` stow-only flag | Task 6 |
| `--hypr` stow-only flag | Task 6 |
| Bootstrap minimal deps (git, curl, stow) | Task 7 (`setup.sh`) |
| Clone dotfiles if not present | Task 7 (`setup.sh`) |
| `--bootstrap curl` / `--bootstrap git` | Task 7 (`setup.sh`) |
| `--dotfiles-dir` override | Task 7 (`setup.sh`) |
| Root-in-container support (`_sudo`) | Tasks 2 + 7 |
| INSTALL.md docs | Task 8 |
