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

  if [ "$pkg" = "claude" ]; then
    enforce_claude_permissions "$dotfiles_dir"
  fi
}

# enforce_claude_permissions <dotfiles_dir>
# Keeps ~/.claude/settings.json local/ignored, but applies the tracked portable
# permission policy after stowing Claude config.
enforce_claude_permissions() {
  local dotfiles_dir="$1"
  local policy_file="$dotfiles_dir/claude/.claude/settings.permissions.json"
  local settings_file="$HOME/.claude/settings.json"

  if [ ! -f "$policy_file" ]; then
    echo "[skip] claude permissions: no policy file at $policy_file"
    return 0
  fi

  mkdir -p "$(dirname "$settings_file")"

  POLICY_FILE="$policy_file" SETTINGS_FILE="$settings_file" python3 <<'PY'
import json
import os
from pathlib import Path

policy_path = Path(os.environ["POLICY_FILE"])
settings_path = Path(os.environ["SETTINGS_FILE"])

with policy_path.open() as f:
    policy = json.load(f)

if settings_path.exists():
    with settings_path.open() as f:
        settings = json.load(f)
else:
    settings = {}

settings["permissions"] = policy["permissions"]

new_text = json.dumps(settings, indent=2, ensure_ascii=False) + "\n"
old_text = settings_path.read_text() if settings_path.exists() else None
if old_text != new_text:
    settings_path.write_text(new_text)
    print(f"[sync] claude permissions -> {settings_path}")
else:
    print(f"[skip] claude permissions already current: {settings_path}")
PY
}

# setup_tmux_plugins
# Clones TPM if not present, then installs all plugins headlessly.
# Warns on failure but does not abort — plugins are non-critical.
setup_tmux_plugins() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

  if [ ! -d "$tpm_dir" ]; then
    echo "[install] TPM (tmux plugin manager)"
    if ! git clone https://github.com/tmux-plugins/tpm "$tpm_dir" 2>/dev/null; then
      echo "[warn] failed to clone TPM — tmux plugins will be skipped" >&2
      return 0
    fi
  else
    echo "[skip] TPM already installed"
  fi

  if [ -f "$tpm_dir/bin/install_plugins" ]; then
    echo "[sync] tmux plugins (headless)"
    "$tpm_dir/bin/install_plugins" 2>/dev/null || echo "[warn] tmux plugin install failed — skipping" >&2
  else
    echo "[warn] TPM install_plugins binary missing — skipping plugin install" >&2
  fi
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
