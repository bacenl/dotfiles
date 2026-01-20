return {
  {
    "bjarneo/ethereal.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("ethereal")

      local function set_custom_highlights()
        -- Transparent floats
        vim.api.nvim_set_hl(0, "SnacksNormal", { bg = "NONE" })
        vim.api.nvim_set_hl(0, "SnacksNormalFloat", { bg = "NONE" })

        -- Visual selection color
        vim.api.nvim_set_hl(0, "Visual", { bg = "#24487d" })
      end

      set_custom_highlights()

      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = set_custom_highlights,
      })

      vim.api.nvim_create_autocmd("UIEnter", {
        callback = set_custom_highlights,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "ethereal",
    },
  },
}
