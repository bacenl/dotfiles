# tmux Config Setup

## Personal Machine

Assumes fish shell and ssh-agent are present. The config detects these automatically.

```bash
# Clone dotfiles (if not already)
git clone https://github.com/bacenl/dotfiles ~/dotfiles

# Stow tmux config
cd ~/dotfiles
stow tmux

# Clone TPM
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# Start tmux, then install plugins
tmux
# Inside tmux: press Ctrl-A + I to install all plugins
```

After `Ctrl-A + I`, TPM will install all plugins. The config will automatically:
- Set `fish` as the default shell (if available)
- Set `SSH_AUTH_SOCK` (if `$XDG_RUNTIME_DIR/ssh-agent.socket` exists)

---

## Container / Minimal Environment

Only copies the config files and TPM — plugins are installed fresh so they adapt to the container's environment (no kitty dependency issues).

### What to copy

```
~/.config/tmux/tmux.conf
~/.config/tmux/tmux.reset.conf
~/.config/tmux/plugins/tpm/   <-- TPM only, not other plugins
```

### One-liner setup script

```bash
# Run inside the container
DOTFILES_HOST=user@your-machine

# Copy only the config files and TPM
ssh $DOTFILES_HOST "tar -czf - \
  ~/.config/tmux/tmux.conf \
  ~/.config/tmux/tmux.reset.conf \
  ~/.config/tmux/plugins/tpm" \
  | tar -xzf - -C /

# Install plugins fresh (no tmux server needed)
~/.config/tmux/plugins/tpm/bin/install_plugins
```

Or manually:

```bash
# 1. Copy config files
scp user@host:~/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf
scp user@host:~/.config/tmux/tmux.reset.conf ~/.config/tmux/tmux.reset.conf

# 2. Clone TPM
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# 3. Install all plugins headlessly
~/.config/tmux/plugins/tpm/bin/install_plugins
```

### Container-specific notes

- **No fish?** The config skips `default-command fish` if fish is not found.
- **No ssh-agent?** The config skips setting `SSH_AUTH_SOCK` if the socket doesn't exist.
- **No GPU/display?** `tmux-yank` will fall back to `xclip`/`xsel`/`wl-copy` depending on what's available — install whichever is present.
- If you don't need session persistence, you can remove `tmux-resurrect` and `tmux-continuum` from the plugin list for a lighter install.

---

## Updating Plugins

```bash
# Inside tmux: Ctrl-A + U
# Or headlessly:
~/.config/tmux/plugins/tpm/bin/update_plugins all
```
