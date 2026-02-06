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
local todo_path = '~/Documents/obsidian/07_quick_notes/todo.md'
vim.keymap.set('n', '<leader>td', function()
  vim.cmd('edit ' .. todo_path)
end, { desc = 'Open Todo' })

-- Keymap to open programming diary
local year = tonumber(os.date("%Y"))
local month_abbr = os.date("%b"):lower()
local diary_path = string.format("~/Documents/obsidian/07_quick_notes/programming_diary/%d/%s.md", year, month_abbr)
vim.keymap.set('n', '<leader>tp', function()
  vim.cmd('edit ' .. diary_path)
end, { desc = 'Open Programming Diary' })

local chinese_path = '~/Documents/obsidian/03_projects/chinese/io/input.txt'
vim.keymap.set('n', '<leader>tm', function()
  vim.cmd('edit ' .. chinese_path)
end, { desc = 'Open Chinese' })

local current_path = '~/Documents/obsidian/01_academic/!current/!current.md'
vim.keymap.set('n', '<leader>tc', function()
  vim.cmd('edit ' .. current_path)
end, { desc = 'Open Current' })

local anki_path = '~/Documents/obsidian/07_quick_notes/anki.md'
vim.keymap.set('n', '<leader>ta', function()
  vim.cmd('edit ' .. anki_path)
end, { desc = 'Open Anki' })

