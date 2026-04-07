vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/neovim/bin/python3")
-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
