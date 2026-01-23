-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- vim.keymap.set('i', '<C-f>', '<C-y>', { noremap = true, silent = true, desc = 'Accept completion' })
-- vim.keymap.set('i', '<C-j>', '<C-n>', { noremap = true, silent = true, desc = 'Next completion' })
-- vim.keymap.set('i', '<C-k>', '<C-p>', { noremap = true, silent = true, desc = 'Previous completion' })

-- To swap <C-f> to complete (from blink.cmp) with the buffer creation from neovim
vim.keymap.set('c', '<C-y>', '<C-f>', { noremap = true, silent = true, desc = 'Open command-line window' })


-- Keymap to open TODO
local todo_path = '~/Documents/07_quick_notes/todo.md'

vim.keymap.set('n', '<leader>td', function()
  vim.cmd('edit ' .. todo_path)
end, { desc = 'Open Todo' })

-- Keymap to open programming diary
local year = tonumber(os.date("%Y"))
local month_abbr = os.date("%b"):lower()
local diary_path = string.format("~/Documents/07_quick_notes/programming_diary/%d/%s.md", year, month_abbr)

vim.keymap.set('n', '<leader>tp', function()
  vim.cmd('edit ' .. diary_path)
end, { desc = 'Open Programming Diary' })
