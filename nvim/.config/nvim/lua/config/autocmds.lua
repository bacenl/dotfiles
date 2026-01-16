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

-- vim.fn.serverstart('/tmp/godothost')

-- For Godot using Neovim
-- Must use `nvim .` or `nvim PROJECT_PATH`
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        -- If opened with directory, cd to it
        local arg = vim.fn.argv(0)
        if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
            vim.cmd.cd(vim.fn.fnamemodify(arg, ':p'))
        end

        local gdproject = io.open(vim.fn.getcwd()..'/project.godot', 'r')
        if gdproject then
            io.close(gdproject)
            vim.fn.serverstart('/tmp/godothost')
        end
    end,
})

