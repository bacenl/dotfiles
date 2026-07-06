# AGENTS.md

Guidance for AI agents and humans working in this dotfiles repository.

## Repository Purpose

This repo should contain only portable, reusable dotfiles and setup automation that are worth sharing across machines.

Track:
- Hand-written configuration files and scripts that define the desired environment.
- Small lockfiles or manifests that are needed to reproduce a tool setup.
- Documentation for installing, restoring, or operating these dotfiles.

Do not track:
- Secrets, tokens, credentials, private keys, OAuth/session files, or machine IDs.
- Caches, logs, histories, backups, crash reports, local databases, shell snapshots, or temporary files.
- Generated dependency/vendor directories such as `node_modules/`.
- Per-project AI transcripts, task state, tool results, or local runtime state.
- Large binary assets unless the user explicitly says they are intentional dotfile assets.

When adopting a new tool config, first decide which files are the true cross-machine source of truth. Ignore or leave untracked everything else.

## Layout Notes

Each top-level directory is generally a GNU Stow package rooted at `$HOME`:

- `fish/`, `nvim/`, `tmux/`, `ghostty/`, `kitty/`, `hypr/`, `waybar/`, `yazi/`, etc. contain real user config.
- `claude/`, `opencode/`, and `pi*/` contain AI-tool configuration. Be extra strict here: these tools generate lots of session state and often hold secrets.
- `scripts/` contains setup/profile/install helpers.
- `docs/` and top-level `*.md` files document setup and decisions.

## AI Tool Config Policy

For Claude-style config directories, keep only portable instructions and hand-written skills/config snippets:

- OK: `CLAUDE.md`, `AGENTS.md`, custom skill `SKILL.md` files, sanitized templates/examples.
- Not OK: `projects/`, `sessions/`, `session-env/`, `tasks/`, `file-history/`, `shell-snapshots/`, `history.jsonl`, plugin caches, marketplace checkouts, backup folders, auth caches, hook logs/state, or raw `settings.json` files containing tokens.

If a real settings file contains secrets or host-specific paths, do not commit it. Prefer a sanitized `*.example` or documented setup step.

## Workflow Expectations

Before editing:
- Run `git status --short --branch` and notice staged, unstaged, and untracked work.
- Do not overwrite or reformat unrelated user changes.
- Inspect the exact files you plan to touch.

While editing:
- Keep changes minimal and scoped.
- Preserve user-specific intent in existing configs.
- Update ignore rules when a new tool creates non-portable state.
- If unsure whether a file belongs in dotfiles, leave it untracked and ask.

Before committing:
- Review `git diff` for your files.
- Run a relevant lightweight validation when possible, e.g. `bash -n setup.sh scripts/**/*.sh` for shell changes or a config-specific smoke check.

## Git Practices

- Make atomic commits: one logical task per commit.
- Use conventional commit prefixes such as `docs:`, `chore:`, `fix:`, `feat:`, `refactor:`, or `meta:`.
- Never use `git add .`, `git add -A`, or `git commit -a`.
- Stage explicit paths only: `git add <file> <file>`.
- Always verify staged files before committing: `git diff --staged --name-only`.
- Review staged patches before committing: `git diff --staged`.
- Do not add AI bylines, co-author footers, or generated-agent signatures.
- Do not push, tag, reset, rebase, clean, or delete user files unless explicitly asked.

## Commit Message Style

Use a short imperative subject. Add bullets only when helpful:

```text
chore: tighten dotfile ignore policy

- Ignore generated AI-tool state and editor caches
- Keep only portable config files visible for staging
```

## When in Doubt

This repo should be boring, reproducible, and portable. A good default is: if a file was generated during tool usage rather than intentionally authored as configuration, it probably does not belong in Git.
