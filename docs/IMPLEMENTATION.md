# Implementation Log

## 2026-07-14 - Portable profiles and WSL setup

- [x] Replace machine-specific home paths in Fish and the personal Pi timer.
- [x] Install and stow Fish in the devcontainer profile without changing its Pi profile.
- [x] Add a WSL profile that stows into the WSL Linux home and uses the personal Pi profile.
- [x] Add regression tests and installation documentation.
- [x] Commit the validated changes and prepare the branch for push.

Notes:
- Work is isolated in a Git worktree so existing edits in `~/dotfiles` remain untouched.
- `bash tests/setup_profiles_test.sh` and Bash syntax validation pass.
- Independent review identified WSL/HOME guard bypasses; kernel-backed detection and canonical HOME validation were added before re-review.

## 2026-07-14 - Synchronize WSL profile with current master

- [x] Merge the current `origin/master` into `feat/wsl-profile` and resolve conflicts.
- [x] Add regression coverage for merged stow failure handling and WSL profile behavior.
- [x] Run the complete shell/profile validation suite until all checks pass.
- [x] Commit and push the synchronized branch.

Notes:
- `origin/master` merged cleanly; `INSTALL.md`, `README.md`, and `setup.sh` were auto-merged without conflict markers.
- A regression test reproduced a partial-adoption failure that left a tracked dotfile modified when GNU Stow exited unsuccessfully.
- Independent review also reproduced unsafe removal of an absolute parent-directory symlink and loss of an absolute leaf symlink after Stow failure.
- `do_stow` now considers only package leaf paths, never removes parent-directory symlinks, restores removed leaf symlinks on failure, and restores tracked package contents on both successful and failed Stow runs.
- Stow failures remain aggregated and later packages continue running; real GNU Stow tests cover conflict adoption, managed-link creation, and idempotent reruns.
- `bash -n setup.sh scripts/install/*.sh scripts/profile/*.sh scripts/stow.sh tests/*.sh` and every `tests/*.sh` script pass.

## 2026-07-14 - Actionable setup summaries and tool version fixes

- [x] Add a final deduplicated summary of every warning, error, and skip for all profiles.
- [x] Replace root-owned global npm Pi installation with the official user-local Pi installer.
- [x] Require and verify Neovim 0.11.2 or newer for LazyVim across all profiles.
- [x] Add regression tests for summary content, Pi installation, and Neovim version handling.
- [x] Run the complete regression suite, Bash syntax checks, diff checks, and independent review.
- [x] Commit and push the changes; follow-up pull request: [#2](https://github.com/bacenl/dotfiles/pull/2).

Validation:
- All five `tests/*.sh` scripts pass.
- `bash -n setup.sh scripts/install/*.sh scripts/profile/*.sh scripts/stow.sh tests/*.sh` passes.
- `git diff --check` passes.
- Final independent review found no blocking security or correctness issues.
- ShellCheck was unavailable on the review host.
