return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    image = {
      enabled = true,
      doc = {
        inline = false,
        float = true,
        max_width = 50,
        max_height = 30,
        -- Apparently, all the images that you preview in neovim are converted
        -- to .png and they're cached, original image remains the same, but
        -- the preview you see is a png converted version of that image
        --
        -- Where are the cached images stored?
        -- This path is found in the docs
        -- :lua print(vim.fn.stdpath("cache") .. "/snacks/image")
        -- For me returns `~/.cache/neobean/snacks/image`
        -- Go 1 dir above and check `sudo du -sh ./* | sort -hr | head -n 5`
      },
    },
    terminal = {
      shell = "/usr/bin/fish",
      win = {
        position = "float",
        border = "rounded",
      },
    },
		picker = {
			hidden = true,
			ignored = true,
			sources = {
				files = {
					hidden = true,
					ignored = true,
				},
				buffers = {
					hidden = true,
					ignored = true,
				},
			},
		},
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    -- Set Snacks-specific highlights to be transparent
    vim.api.nvim_set_hl(0, "SnacksNormal", { bg = "NONE" })
    vim.api.nvim_set_hl(0, "SnacksNormalFloat", { bg = "NONE" })
  end,
}
