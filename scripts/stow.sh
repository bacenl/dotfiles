#!/usr/bin/env bash
set -euo pipefail

STOW_FAILURES=()
_STOW_REMOVED_LINKS=()
_STOW_REMOVED_DESTS=()

record_stow_failure() {
  local pkg="$1"
  local reason="$2"

  STOW_FAILURES+=("$pkg: $reason")
}

report_stow_failures() {
  if [ "${#STOW_FAILURES[@]}" -eq 0 ]; then
    return 0
  fi

  echo ""
  echo "[error] one or more stow operations failed:" >&2
  local failure
  for failure in "${STOW_FAILURES[@]}"; do
    printf '  * %s\n' "$failure" >&2
  done
  echo "        setup continued after these failures; review the stow output above" >&2
  return 1
}

# remove_absolute_target_symlink_conflicts <pkg> <dotfiles_dir>
# GNU Stow refuses to adopt absolute target symlinks. If one blocks a leaf path
# this package owns, remove only that symlink so Stow can create the managed
# link. Parent-directory symlinks are never removed: they may represent an
# entire external configuration tree.
remove_absolute_target_symlink_conflicts() {
  local pkg="$1"
  local dotfiles_dir="$2"
  local pkg_path="$dotfiles_dir/$pkg"
  local rel target link_dest

  _STOW_REMOVED_LINKS=()
  _STOW_REMOVED_DESTS=()

  while IFS= read -r rel; do
    rel="${rel#./}"
    target="$HOME/$rel"

    if [ ! -L "$target" ]; then
      continue
    fi

    link_dest=$(readlink "$target")
    case "$link_dest" in
      /*) ;;
      *) continue ;;
    esac

    case "$link_dest" in
      "$pkg_path"|"$pkg_path"/*) continue ;;
    esac

    echo "[stow] replacing absolute target symlink: $target -> $link_dest"
    if ! rm "$target"; then
      record_stow_failure "$pkg" "could not remove absolute target symlink $target"
      return 1
    fi
    _STOW_REMOVED_LINKS+=("$target")
    _STOW_REMOVED_DESTS+=("$link_dest")
  done < <(cd "$pkg_path" && find . -mindepth 1 \( -type f -o -type l \) -print)
}

# restore_removed_target_symlinks
# Rolls back leaf symlinks removed before a failed Stow operation. It removes
# only symlinks created during the partial operation and never overwrites a real
# file or directory.
restore_removed_target_symlinks() {
  local i=0 target link_dest current_dest status=0

  while [ "$i" -lt "${#_STOW_REMOVED_LINKS[@]}" ]; do
    target="${_STOW_REMOVED_LINKS[$i]}"
    link_dest="${_STOW_REMOVED_DESTS[$i]}"

    if [ -L "$target" ]; then
      current_dest=$(readlink "$target")
      if [ "$current_dest" = "$link_dest" ]; then
        i=$((i + 1))
        continue
      fi
      if ! rm "$target"; then
        status=1
        i=$((i + 1))
        continue
      fi
    elif [ -e "$target" ]; then
      echo "[error] cannot restore absolute symlink because a real path now exists: $target" >&2
      status=1
      i=$((i + 1))
      continue
    fi

    if ! ln -s "$link_dest" "$target"; then
      status=1
    fi
    i=$((i + 1))
  done

  return "$status"
}

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
    record_stow_failure "$pkg" "package has tracked changes"
    return 0
  fi

  if ! remove_absolute_target_symlink_conflicts "$pkg" "$dotfiles_dir"; then
    if ! restore_removed_target_symlinks; then
      record_stow_failure "$pkg" "removed target symlinks could not be restored"
    fi
    return 0
  fi

  # Adopt existing files into the package, then restore tracked dotfiles so the
  # home directory points at the repository's versions without deleting data.
  if ! stow --dir="$dotfiles_dir" --target="$HOME" --adopt --restow "$pkg"; then
    # Stow may adopt some files before failing. Roll back both the tracked
    # checkout contents and any absolute HOME symlinks removed before Stow.
    record_stow_failure "$pkg" "stow command failed"
    if ! git -C "$dotfiles_dir" restore --worktree -- "$pkg"; then
      record_stow_failure "$pkg" "tracked files could not be restored after failed stow"
    fi
    if ! restore_removed_target_symlinks; then
      record_stow_failure "$pkg" "removed target symlinks could not be restored after failed stow"
    fi
    return 0
  fi
  if ! git -C "$dotfiles_dir" restore --worktree -- "$pkg"; then
    record_stow_failure "$pkg" "tracked files could not be restored after stow"
    return 0
  fi

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
