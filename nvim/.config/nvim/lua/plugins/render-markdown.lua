-- Filename: ~/github/dotfiles-latest/neovim/neobean/lua/plugins/render-markdown.lua
-- ~/github/dotfiles-latest/neovim/neobean/lua/plugins/render-markdown.lua

return {
  "MeanderingProgrammer/render-markdown.nvim",
  enabled = true,
  -- Moved highlight creation out of opts as suggested by plugin maintainer
  -- There was no issue, but it was creating unnecessary noise when ran
  -- :checkhealth render-markdown
  -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/138#issuecomment-2295422741
  config = function()
    vim.api.nvim_set_hl(0, "RenderMarkdownCodeBlack", { bg = "#151c38" })
    require("render-markdown").setup({
      -- Add custom icons lamw26wmal
      link = {
        image = "󰥶 ",
        custom = {
          youtu = { pattern = "youtu%.be", icon = "󰗃 " },
        },
      },
      heading = {
        sign = false,
        icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
        backgrounds = {
          "Search",
          "DiffText",
          "DiffAdd",
          "DiffDelete",
          "IncSearch",
          "PmenuThumb"
        },
        foregrounds = {
          "Search",
          "DiffText",
          "DiffAdd",
          "DiffDelete",
          "IncSearch",
          "PmenuThumb"
        },
      },
      code = {
        border = "thick",
        highlight = "RenderMarkdownCodeBlack",
      },
    })
  end,
}
