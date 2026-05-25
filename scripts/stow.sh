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

  # Detect directories that conflict with stow's folding and remove them
  local sim_out
  sim_out=$(stow --dir="$dotfiles_dir" --target="$HOME" --simulate --restow "$pkg" 2>&1 || true)
  while IFS= read -r line; do
    if [[ "$line" =~ existing\ target\ is\ not\ owned\ by\ stow:\ (.+) ]]; then
      local conflict="$HOME/${BASH_REMATCH[1]}"
      if [ -d "$conflict" ] && [ ! -L "$conflict" ]; then
        echo "[clean] removing conflicting directory: $conflict"
        rm -rf "$conflict"
      fi
    fi
  done <<< "$sim_out"

  stow --dir="$dotfiles_dir" --target="$HOME" --restow "$pkg"
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
