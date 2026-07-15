# Dotfiles

Personal dotfiles and setup automation for terminal containers, WSL, and
Arch/Omarchy machines.

See [INSTALL.md](INSTALL.md) for installation instructions,
[ARCH_INSTALL_GUIDE.md](ARCH_INSTALL_GUIDE.md) for a fresh Arch installation,
and [dual_boot.md](dual_boot.md) for Windows dual boot.

## Stow behavior

The setup script uses GNU Stow to link each package into `$HOME`. When an
existing file conflicts with a dotfile, the helper uses `stow --adopt` and then
`git restore` to put the repository version back in place.

The helper refuses to operate on a package that already has tracked staged or
unstaged changes. Files adopted into the package that are not tracked by Git
are retained and listed for manual review. It never deletes a conflicting
directory. If a target path is an absolute symlink, the helper removes only the
symlink before stowing because GNU Stow cannot adopt absolute symlinks.

If one stow package fails, setup continues with the remaining packages. Every
profile finishes with a deduplicated end-of-run summary of all errors, warnings,
and skipped steps so follow-up work is not buried in the full install log.

To perform the same process manually:

```bash
cd ~/dotfiles
stow --adopt nvim
git restore -- nvim
git status --short -- nvim
```

## Container / devcontainer

Install a minimal dev environment (Neovim, tmux, Fish, ripgrep, fzf, bat,
zoxide, Node, npm, Yazi, and Pi) in a container:

```bash
# Quick bootstrap
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh)" \
  -- --profile devcontainer

# From a local clone
./setup.sh --profile devcontainer
```

Supported OSes: Arch, Debian/Ubuntu, macOS, Fedora, Alpine (detected automatically).

### Options

| Flag | Description |
|---|---|
| `--dotfiles-ref <ref>` | Tag, branch, or commit (default: `master`) |
| `--dotfiles-dir <path>` | Clone location (default: `~/dotfiles`) |
| `--nvim-version <ver>` | Upstream Neovim fallback release (default: `0.11.2`) |
| `--bootstrap git` | Install `gh` first and clone via GitHub CLI |

The `devcontainer` profile is rerunnable — stow is idempotent and refuses packages with uncommitted changes.

All profiles require Neovim 0.11.2 or newer for LazyVim. Compatible existing
versions are preserved; Debian/Ubuntu installs the official upstream tarball,
and stale Arch/Fedora packages fall back to that release.

## WSL

Run the WSL profile from inside an Ubuntu WSL distribution:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bacenl/dotfiles/master/setup.sh)" \
  -- --profile wsl
```

The profile installs the portable terminal stack—including Fish, eza, fzf,
ripgrep, bat, zoxide, Neovim, tmux, Node, Python, Go, GitHub CLI, Yazi where
available, and Pi—stows Linux configuration into the WSL user's `$HOME`, and
selects the personal Pi settings profile. It does not install Kitty, Hyprland,
Omarchy, or other Linux desktop components.

Keep both `~/dotfiles` and `$HOME` in WSL's Linux filesystem. Windows-hosted
projects can remain on NTFS and be opened from paths such as
`/mnt/c/dev/MyGame`. The installer rejects a WSL profile whose `$HOME` is under
`/mnt` so GNU Stow does not create Linux configuration links on a Windows
drive.
