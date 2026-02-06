return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = false,
  ft = "markdown",
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    legacy_commands = false, -- this will be removed in the next major release
    ui = { enable = false },
    completion = { blink = true },
    disable_frontmatter = true,
    mappings = {}, -- disable default mappings
    workspaces = {
      {
        name = "Obsidian",
        path = "~/Documents/obsidian/",
      },
    },

    -- see below for full list of options 👇
  },
}
