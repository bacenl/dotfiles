# Implementation Log

## 2026-07-14 - Portable profiles and WSL setup

- [x] Replace machine-specific home paths in Fish and the personal Pi timer.
- [x] Install and stow Fish in the devcontainer profile without changing its Pi profile.
- [x] Add a WSL profile that stows into the WSL Linux home and uses the personal Pi profile.
- [x] Add regression tests and installation documentation.
- [ ] Commit and push the validated changes.

Notes:
- Work is isolated in a Git worktree so existing edits in `~/dotfiles` remain untouched.
- `bash tests/setup_profiles_test.sh` and Bash syntax validation pass.
- Independent review identified WSL/HOME guard bypasses; kernel-backed detection and canonical HOME validation were added before re-review.
