# Dotfiles Installation

## Fresh Omarchy machine

This setup does not require a browser, an existing GitHub login, or a
pre-installed copy of the repository. The repository must remain public for
this bootstrap path.

### Recommended: download and inspect

Use a published tag for `REF` after creating a release:

```bash
REF=v1.0.0
curl -fsSLo /tmp/dotfiles-setup.sh \
  "https://raw.githubusercontent.com/bacenl/dotfiles/${REF}/setup.sh"
less /tmp/dotfiles-setup.sh
bash /tmp/dotfiles-setup.sh \
  --profile personal \
  --omarchy \
  --dotfiles-ref "$REF"
```

Pinning both the downloaded script and `--dotfiles-ref` ensures all installer
files come from the same immutable release.

### Direct pipe

This is convenient but does not provide an inspection step:

```bash
REF=v1.0.0
curl -fsSL "https://raw.githubusercontent.com/bacenl/dotfiles/${REF}/setup.sh" |
  bash -s -- --profile personal --omarchy --dotfiles-ref "$REF"
```

Do not copy an example tag until that tag exists in the repository. For
development before the first release, replace `v1.0.0` with `master`; this is
functional but mutable and therefore less safe.

## What the personal Omarchy profile does

The script:

1. Installs Git, curl, Stow, Neovim, tmux, Fish, Kitty, development tools, and
   GitHub CLI.
2. Clones the public dotfiles repository over HTTPS.
3. Installs and configures Vivaldi, Syncthing, Kitty, Hyprland, Waybar, TPM,
   tmux, Caps/Escape handling, and the packaged SSH agent socket.
4. Installs Japanese and Chinese input support as the second-last automated
   operation.
5. Replaces iwd/systemd-networkd with NetworkManager as the final automated
   operation.

NetworkManager is deliberately last because changing the active network stack
can interrupt the installer connection.

## Final interactive steps

Complete these after the script prints `[done] personal profile complete`.

### 1. Authenticate GitHub CLI

```bash
gh auth login
```

Choose GitHub.com and the authentication method you prefer. This login is not
required to download or run the setup.

### 2. Pair Syncthing and add folders

Open <http://127.0.0.1:8384>. Add the other device, then add and share:

- Your Obsidian vault directory.
- Your private directory.

Use the existing paths on each device rather than hard-coding paths in the
installer. Confirm both folders report `Up to Date` before deleting or moving
any original copies.

### 3. Select input methods

```bash
fcitx5-config-qt
```

Add Mozc for Japanese and the desired Chinese input method, then apply the
configuration.

### 4. Reboot and verify

```bash
systemctl reboot
```

After reboot:

```bash
omarchy default terminal
systemctl --user is-active syncthing.service ssh-agent.socket
tmux source-file ~/.config/tmux/tmux.conf
ssh-add -l
```

Also launch Vivaldi and confirm the Syncthing folders are connected.

## Other profiles

```bash
# Existing local clone, personal terminal setup only
bash setup.sh --profile personal

# Container setup
bash setup.sh --profile container

# Hyprland configs without Omarchy-specific setup
bash setup.sh --profile personal --hypr
```

Available options:

| Flag | Description |
|---|---|
| `--profile container\|personal` | Required installation profile |
| `--omarchy` | Personal profile with Omarchy desktop setup |
| `--hypr` | Personal profile with Hyprland and Waybar configs |
| `--bootstrap curl\|git` | Public HTTPS clone or authenticated `gh` clone |
| `--dotfiles-ref <ref>` | Tag, branch, or commit checked out after cloning |
| `--dotfiles-dir <path>` | Clone location; defaults to `~/dotfiles` |
| `--nvim-version <version>` | Neovim tarball version for Debian/Ubuntu |

The installer is designed to be rerunnable. Stow refuses packages with tracked
repository changes and preserves adopted untracked files for review.

## Pi coding agent

The `pi` stow package tracks:

- `~/.pi/agent/settings.json` — packages list, default model/provider, and preferences
- `~/.pi/agent/models.json` — custom Bedrock/Anthropic model definitions
- `~/.pi/agent/extensions/` — custom extensions (clear-on-ctrl-c, custom-status-footer, omarchy-system-theme)
- `~/.pi/agent/skills/omarchy/` — omarchy skill

These are intentionally **not** tracked:

- `auth.json` — API keys and OAuth tokens (set these after install)
- `sessions/` — conversation history
- `git/`, `npm/` — installed package caches (reinstalled by setup)
- `security/`, `vstack/`, `pi-vcc-config.json` — runtime state

The personal profile `setup.sh` stows the `pi` package and then runs
`pi install` for every package listed in `settings.json`. Pi itself must be
installed separately before setup runs:

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

After `setup.sh` completes, set credentials via `/login` or by exporting the
relevant API key environment variable before starting pi.
