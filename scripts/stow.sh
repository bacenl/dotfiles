#!/usr/bin/env bash
set -euo pipefail

# do_stow <pkg> <dotfiles_dir>
# Stows <pkg> from <dotfiles_dir> into $HOME. Idempotent.
# Skips with a warning if the stow target directory doesn't exist.
do_stow() {
  local pkg="$1"
  local dotfiles_dir="$2"
  local pkg_path="$dotfiles_dir/$pkg"

  if [ ! -d "$pkg_path" ]; then
    echo "[skip] stow: no directory $pkg_path"
    return 0
  fi

  echo "[stow] $pkg"

  if ! git -C "$dotfiles_dir" diff --quiet -- "$pkg" ||
     ! git -C "$dotfiles_dir" diff --cached --quiet -- "$pkg"; then
    echo "[error] refusing to stow $pkg because $pkg_path has tracked changes" >&2
    echo "        commit, stash, or restore those changes before running setup again" >&2
    return 1
  fi

  # Adopt existing files into the package, then restore tracked dotfiles so the
  # home directory points at the repository's versions without deleting data.
  stow --dir="$dotfiles_dir" --target="$HOME" --adopt --restow "$pkg"
  git -C "$dotfiles_dir" restore --worktree -- "$pkg"

  local adopted
  adopted=$(git -C "$dotfiles_dir" ls-files --others --exclude-standard -- "$pkg")
  if [ -n "$adopted" ]; then
    echo "[warn] existing untracked files were adopted into $pkg_path:"
    while IFS= read -r path; do
      printf '  %s\n' "$path"
    done <<< "$adopted"
    echo "       review and commit or remove them manually"
  fi
}

# setup_tmux_plugins
# Clones TPM if not present, then installs all plugins headlessly.
setup_tmux_plugins() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

  if [ ! -d "$tpm_dir" ]; then
    echo "[install] TPM (tmux plugin manager)"
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir" \
      || { echo "[error] failed to clone TPM" >&2; return 1; }
  else
    echo "[skip] TPM already installed"
  fi

  echo "[sync] tmux plugins (headless)"
  "$tpm_dir/bin/install_plugins"
}

# reload_tmux_config
# Reloads the stowed config when a tmux server is already running.
reload_tmux_config() {
  if tmux has-session 2>/dev/null; then
    echo "[reload] tmux config"
    tmux source-file "$HOME/.config/tmux/tmux.conf"
  else
    echo "[skip] tmux reload: no running tmux server"
  fi
}
