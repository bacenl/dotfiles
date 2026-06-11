local theme_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")

if vim.fn.filereadable(theme_file) == 1 then
  local ok, theme = pcall(dofile, theme_file)
  if ok and type(theme) == "table" then
    return theme
  end
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "habamax",
    },
  },
}
