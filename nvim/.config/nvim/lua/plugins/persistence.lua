return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {
    dir = vim.fn.stdpath("state") .. "/sessions/",
    need = 1,
    branch = true,
  },
  config = function(_, opts)
    require("persistence").setup(opts)
    -- auto-restore on startup
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        require("persistence").load()
      end,
      nested = true,
    })
  end,
}
