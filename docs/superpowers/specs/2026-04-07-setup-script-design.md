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
    profile/
      container.sh                ← install + stow for container profile
      personal.sh                 ← install + stow for personal profile
    stow.sh                       ← shared idempotent stow helper
```

---

## Profiles

### Container

Minimal environment. Installs and stows only what's needed for terminal work.

**Installs:** nvim, tmux, yazi, fzf, ripgrep, bat, zoxide
**Stows:** `nvim`, `tmux`, `yazi`

### Personal

Full developer setup for a personal laptop.

**Installs:** nvim, tmux, yazi, fzf, ripgrep, bat, zoxide, fish, kitty, node, python, rust, go, gcc/g++
**Stows:** `nvim`, `tmux`, `yazi`, `fish`, `kitty`, `scripts`

**Optional flags (personal only):**

| Flag | Installs & stows |
|------|-----------------|
| `--omarchy` | omarchy + hypr + waybar |
| `--hypr` | hypr + waybar (no omarchy) |

---

## OS Support

| OS | Package manager | Notes |
|----|----------------|-------|
| Arch Linux | `pacman -S` | |
| Ubuntu / Debian | `apt-get install` | some packages renamed (e.g. `bat` → `batcat`) |
| macOS | `brew install` | Homebrew installed automatically if missing |
| Fedora / RHEL | `dnf install` | |
| Alpine | `apk add` | common in containers |

`pkgs.sh` exposes a single `install_pkg <name>` function. It detects the OS once, selects the right package manager, and handles cross-OS name differences internally (e.g. `bat` is `batcat` on Ubuntu/Debian).

---

## Dotfiles Repo Bootstrapping

`setup.sh` clones `https://github.com/bacenl/dotfiles` to `~/dotfiles` if not already present. If the directory exists, it skips cloning. The `--dotfiles-dir` flag overrides the target path.

---

## CLI Usage

```bash
# Container
bash setup.sh --profile container

# Personal laptop (base)
bash setup.sh --profile personal

# Personal + full omarchy desktop (omarchy + hypr + waybar)
bash setup.sh --profile personal --omarchy

# Personal + hyprland only (hypr + waybar, no omarchy)
bash setup.sh --profile personal --hypr

# Override dotfiles location
bash setup.sh --profile personal --dotfiles-dir /custom/path
```

---

## Constraints

- Install method: package manager only (no compiling from source, no AppImages)
- `--omarchy` and `--hypr` are only valid with `--profile personal`
- `stow.sh` must be idempotent — safe to run multiple times
- No assumptions about shell (container may not have fish/bash — use `#!/bin/sh` compatible syntax where possible, or explicitly invoke `bash`)
