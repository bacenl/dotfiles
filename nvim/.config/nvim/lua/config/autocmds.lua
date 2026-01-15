-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- To fix snacks not setting the file type properly, and hence render-markdown and LSPs
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    -- Force filetype detection if not set
    if vim.bo.filetype == '' then
      vim.cmd('filetype detect')
    end
  end,
})
