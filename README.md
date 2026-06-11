# Dotfiles

Personal dotfiles and setup automation for terminal containers and Arch/Omarchy
machines.

See [INSTALL.md](INSTALL.md) for installation instructions,
[ARCH_INSTALL_GUIDE.md](ARCH_INSTALL_GUIDE.md) for a fresh Arch installation,
and [dual_boot.md](dual_boot.md) for Windows dual boot.

## Stow behavior

The setup script uses GNU Stow to link each package into `$HOME`. When an
existing file conflicts with a dotfile, the helper uses `stow --adopt` and then
`git restore` to put the repository version back in place.

The helper refuses to operate on a package that already has tracked staged or
unstaged changes. Files adopted into the package that are not tracked by Git
are retained and listed for manual review. It never deletes a conflicting
directory.

To perform the same process manually:

```bash
cd ~/dotfiles
stow --adopt nvim
git restore -- nvim
git status --short -- nvim
```
