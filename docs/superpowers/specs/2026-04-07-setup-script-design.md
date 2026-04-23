# Setup Script Design

**Date:** 2026-04-07
**Status:** Approved

## Overview

A master setup script that installs tools and stows dotfile configs across different environments (containers and personal laptops) and operating systems (macOS, Arch, Ubuntu, Debian, Fedora, Alpine).

---

## File Structure

```
dotfiles/
  setup.sh                        ← entry point: parses flags, clones repo, delegates
  INSTALL.md                      ← user-facing usage documentation
  scripts/
    install/
      pkgs.sh                     ← OS detection + install_pkg() + package name maps
      nvim.sh                     ← nvim version-aware installer
    profile/
      container.sh                ← install + stow for container profile
      personal.sh                 ← install + stow for personal profile
    stow.sh                       ← shared idempotent stow helper
```

---

## Profiles

### Container

Minimal environment. Installs and stows only what's needed for terminal work.

**Installs:** nvim (0.11.x), tmux, yazi*, fzf, ripgrep, bat, zoxide
**Stows:** `nvim`, `tmux`, `yazi`*

*yazi skipped with a warning on OSes that don't package it (Ubuntu, Debian, Alpine)

### Personal

Full developer setup for a personal laptop.

**Installs:** nvim (0.11.x), tmux, yazi, fzf, ripgrep, bat, zoxide, fish, kitty, node, python, go, gcc/g++
**Stows:** `nvim`, `tmux`, `yazi`, `fish`, `kitty`, `scripts`

**Optional flags (personal only):**

| Flag | Effect |
|------|--------|
| `--omarchy` | Stows `omarchy`, `hypr`, `waybar` — assumes already on an omarchy device, no installation |
| `--hypr` | Stows `hypr`, `waybar` — assumes hyprland is already installed, no omarchy |

---

## OS Support

| OS | Package manager | Notes |
|----|----------------|-------|
| Arch Linux | `pacman -S` | |
| Ubuntu / Debian | `apt-get install` | `bat` → `batcat`; nvim from GitHub releases (see below); yazi skipped |
| macOS | `brew install` | Homebrew installed automatically if missing |
| Fedora / RHEL | `dnf install` | |
| Alpine | `apk add` | common in containers; yazi skipped |

`pkgs.sh` exposes a single `install_pkg <name>` function. It detects the OS once, selects the right package manager, and handles cross-OS name differences internally.

---

## Neovim Version Handling

Target version: **0.11.x**

Neovim is handled by a dedicated `scripts/install/nvim.sh` rather than `install_pkg`, because version requirements vary by OS:

| OS | Method |
|----|--------|
| Arch | `pacman -S neovim` (ships current) |
| macOS | `brew install neovim` (ships current) |
| Fedora | `dnf install neovim` (ships current) |
| Ubuntu / Debian | Download prebuilt tarball from GitHub releases (`nvim-linux-x86_64.tar.gz`) and install to `/usr/local` and setup bin|
| Alpine | `apk add neovim` + version check; warn if below 0.11 |

---

## Dotfiles Repo Bootstrapping

`setup.sh` must bootstrap its own dependencies before doing anything else. On a completely empty container (bash only), the following must be installed via the native OS package manager first: `git` or `curl`/`wget` (depending on bootstrap mode), `stow`. On macOS, also `brew`.

Two bootstrap modes are supported via `--bootstrap`:

### `--bootstrap curl` (default)
Fetches and runs the script directly — no git required upfront.
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh) --profile container
```
The script then installs `git` and `stow` via the OS package manager, clones the repo, and continues.

### `--bootstrap git`
Installs `git`, `gh` (GitHub CLI), and `stow` via the OS package manager first, then clones the repo:
```bash
gh repo clone bacenl/dotfiles ~/dotfiles
```
Useful when authenticated access is needed (private repo or SSH preference).

In both modes: if `~/dotfiles` already exists, cloning is skipped.
The `--dotfiles-dir` flag overrides the clone target path.

---

## TMux Plugin Installation

Both profiles automatically install tmux plugins headlessly after stowing the tmux config:

1. Clone TPM to `~/.config/tmux/plugins/tpm` (skipped if already present)
2. Run `~/.config/tmux/plugins/tpm/bin/install_plugins` (no running tmux server required)

---

## CLI Usage

```bash
# Container (curl bootstrap — works from a bare system)
bash <(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh) --profile container

# Container (git bootstrap — installs git + gh first)
bash <(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh) --profile container --bootstrap git

# Personal laptop (base)
bash setup.sh --profile personal

# Personal + full omarchy setup (stows omarchy + hypr + waybar)
bash setup.sh --profile personal --omarchy

# Personal + hyprland only (stows hypr + waybar, no omarchy)
bash setup.sh --profile personal --hypr

# Override dotfiles location
bash setup.sh --profile personal --dotfiles-dir /custom/path
```

---

## Constraints

- Install method: package manager where possible; GitHub releases tarball for nvim on Ubuntu/Debian only
- Rust excluded — use rustup separately
- `--omarchy` and `--hypr` only stow configs; they do not install anything — assumes the environment is already set up
- `--omarchy` and `--hypr` are only valid with `--profile personal`
- `stow.sh` must be idempotent — safe to run multiple times
- Scripts use `#!/usr/bin/env bash` — bash is the minimum assumed shell
- yazi skipped (with warning) on Ubuntu, Debian, Alpine
