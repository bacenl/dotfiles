return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    terminal = {
      shell = "/usr/bin/fish",
      win = {
        position = "float",
        border = "rounded",
      },
    }
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    -- Set Snacks-specific highlights to be transparent
    vim.api.nvim_set_hl(0, "SnacksNormal", { bg = "NONE" })
    vim.api.nvim_set_hl(0, "SnacksNormalFloat", { bg = "NONE" })
  end,
}
