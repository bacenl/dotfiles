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
