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
        name = "Academic",
        path = "~/Documents/01_academic/",
      },
      {
        name = "Programming",
        path = "~/Documents/02_programming/",
      },
      {
        name = "Projects",
        path = "~/Documents/03_projects/",
      },
      {
        name = "Life",
        path = "~/Documents/04_life/",
      },
      {
        name = "Misc",
        path = "~/Documents/05_misc/",
      },
      {
        name = "Quick Notes",
        path = "~/Documents/07_quick_notes/",
      },
    },

    -- see below for full list of options 👇
  },
}
