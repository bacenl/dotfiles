# Stowing

Create a directory in the `dotfile` folder.
1. The first folder will be the stow name
2. Following folders will be where 

## For example:
I want to stow `~/.config/nvim/`:
1. `mkdir ~/dotfiles/nvim/.config/`
2. `mv ~/.config/nvim ~/dotfiles/nvim/.config/`
3. `cd ~/dotfiles`
4. `stow nvim`

### From: ~/dotfiles, stow does this:

1. Goes into nvim/ directory
2. Looks for files/folders there
3. For each, creates a symlink in PARENT directory

### So from:
`~/dotfiles/nvim/.config/nvim`

### It creates symlink at:
`~/.config/nvim → ~/dotfiles/nvim/.config/nvim`

Hence, there will be a folder `~/.config/nvim` that will have a symlink to `~/dotfiles/nvim/.config/nvim/`

# Getting the stow
Clone the repo, then just use `stow <name>`
