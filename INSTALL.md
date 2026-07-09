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

## Supply chain security

The `npm` stow package tracks `~/.npmrc` with hardened defaults:

```ini
min-release-age=7       # reject packages published in the last 7 days
ignore-scripts=true     # block postinstall/preinstall execution vectors
save-exact=true         # pin exact versions, no ^ or ~ ranges
```

`fish/config.fish` sets `UV_EXCLUDE_NEWER` at shell startup so `uv` only resolves packages published more than 7 days ago.

If `~/.npmrc` already exists before running setup, `do_stow` will adopt it automatically (via `--adopt`). If the adopted file differs from the tracked version, review with `git diff` and commit or restore as appropriate.

Additional manual hardening (not managed by stow):

- **pnpm**: add `blockExoticSubdeps: true` and `minimumReleaseAge: 10080` to `pnpm-workspace.yaml` per project
- **bun**: add `[install] minimumReleaseAge = 604800` to `bunfig.toml` per project
- **GitHub Actions**: pin third-party actions to full commit SHAs (not version tags)
- **CI installs**: use `npm ci`, `pnpm install --frozen-lockfile`, or `uv sync --frozen` — never bare `npm install`

See [~/Projects/supply-chain-security](https://github.com/shisaai/supply-chain-security) for the full org standard and per-repo audit templates.

## Pi coding agent

There are two Pi setup entry points:

```bash
./setup.sh --profile devcontainer
./setup.sh --profile personal
```

The shared `pi` stow package tracks:

- `~/.pi/agent/keybindings.json` — local TUI keybindings
- `~/.pi/agent/pi-vcc-config.json` — pi-vcc extension preferences
- `~/.pi/agent/extensions/` — custom extensions (clear-on-ctrl-c, custom-status-footer, omarchy-system-theme, toggle-security)
- `~/.pi/agent/skills/` — local skills (omarchy, braindump)
- `~/.pi/agent/security/*.json` — pi-secured-setup guard configuration and skill approvals
- `~/.pi/agent/patches/` — local package patches reapplied by setup

Profile-specific settings are split so the package list differs by entry point:

- `pi-personal/.pi/agent/settings.json` includes `git:github.com/mwolff44/pi-secured-setup@v1.0.3`; setup reapplies the peon approval-sound patch after installing packages.
- `pi-personal-tools/.pi/agent/pi_daily_capture/` installs the personal-computer-only internship learning capture workflow. Run it with `python ~/.pi/agent/pi_daily_capture/capture.py`; it writes only to `/home/ubuntu/obsidian/internship/braindump/week_N/YYYY-MM-DD/pi-capture.md`.
- `pi-devcontainer/.pi/agent/settings.json` omits `pi-secured-setup`; setup also skips local security patches for this profile. Devcontainer setup does not stow `pi-personal-tools`.
- `/toggle-security [on|off|status]` switches `~/.pi/agent/settings.json` between the personal profile and a generated security-off profile, then reloads Pi.

These are intentionally **not** tracked:

- `auth.json` — API keys and OAuth tokens (set these after install)
- `models.json` — custom providers may contain API keys or bearer tokens; recreate locally or use `$ENV_VAR` placeholders
- `sessions/` — conversation history
- `git/`, `npm/` — installed package caches (reinstalled by setup)
- `security/audit*.jsonl*` — local security audit logs
- `vstack/` — runtime state

Both profiles install the pi CLI if needed and run `pi install` for every package
listed in the active profile's `settings.json`. After setup completes, set
credentials via `/login` or by exporting the relevant API key environment
variable before starting pi. Peon sound packs are not tracked; install them
interactively with `/peon install` if needed.
