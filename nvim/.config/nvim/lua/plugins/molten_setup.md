## One-time Neovim setup

### 1. Create the neovim venv and install Molten's Python deps

The docs say to keep Molten's deps in a dedicated "global" venv, separate from any project. With `uv`:

```bash
uv venv ~/.virtualenvs/neovim
uv pip install --python ~/.virtualenvs/neovim/bin/python \
    pynvim jupyter_client cairosvg plotly kaleido pnglatex pyperclip
```

`pynvim` and `jupyter_client` are the only mandatory ones. The rest are optional — only needed if you want SVG, LaTeX, Plotly, or clipboard output support.

### 2. Point Neovim at that venv

At the **top** of your `init.lua`, before lazy loads:

```lua
vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/neovim/bin/python3")
```

### 3. Plugin spec (lazy.nvim)

Without image support (simpler):

```lua
{
  "benlubas/molten-nvim",
  version = "^1.0.0",
  build = ":UpdateRemotePlugins",
  init = function()
    vim.g.molten_output_win_max_height = 20
    vim.g.molten_auto_open_output = false
    vim.g.molten_wrap_output = true
    vim.g.molten_virt_text_output = true
    vim.g.molten_virt_lines_off_by_1 = true
  end,
},
```

With image support (requires a compatible terminal — Kitty is best):

```lua
{
  "benlubas/molten-nvim",
  version = "^1.0.0",
  dependencies = { "3rd/image.nvim" },
  build = ":UpdateRemotePlugins",
  init = function()
    vim.g.molten_image_provider = "image.nvim"
    vim.g.molten_output_win_max_height = 20
    vim.g.molten_auto_open_output = false
    vim.g.molten_wrap_output = true
    vim.g.molten_virt_text_output = true
    vim.g.molten_virt_lines_off_by_1 = true
  end,
},
{
  "3rd/image.nvim",
  version = "1.1.0", -- pin it, it breaks frequently
  opts = {
    backend = "kitty",
    integrations = {},
    max_width = 100,
    max_height = 12,
    max_height_window_percentage = math.huge, -- required, do not omit
    max_width_window_percentage = math.huge,
    window_overlap_clear_enabled = true,
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
  },
},
```

The `max_height_window_percentage = math.huge` is specifically called out in the docs as necessary — without it, Molten's output windows render at wrong dimensions.

### 4. Auto-init keymap

This reads `$VIRTUAL_ENV` from your shell, extracts the venv name, and runs `:MoltenInit <name>`:

```lua
vim.keymap.set("n", "<localleader>mi", function()
  local venv = os.getenv("VIRTUAL_ENV")
  if venv ~= nil then
    local name = string.match(venv, "/.+/(.+)")
    vim.cmd(("MoltenInit %s"):format(name))
  else
    vim.cmd("MoltenInit python3")
  end
end, { desc = "MoltenInit: auto venv kernel", silent = true })
```

This only works when the kernel `--name` matches the venv directory name — which the per-project workflow below enforces.

### 5. After installing — critical step

Run inside Neovim:
```
:UpdateRemotePlugins
```
Then **restart Neovim**. You must do this after first install and after every Molten update. If commands like `:MoltenInit` don't exist, this is why.

> The docs warn: many Neovim distros disable remote plugins for performance. If Molten commands simply don't exist after `:UpdateRemotePlugins`, check whether your distro has remote plugins disabled.

---

## Per-project setup (repeat for every new project)

```bash
cd ~/projects/my-project

# 1. Create project venv and install your deps as normal
uv venv
uv add numpy pandas matplotlib   # or whatever your project needs

# 2. Install ipykernel into the project venv
uv add --dev ipykernel

# 3. Register the kernel — name MUST match the venv directory name
#    uv's .venv is just called ".venv", so name it after your project instead
uv run python -m ipykernel install --user --name my-project --display-name "my-project"

# 4. Confirm registration
jupyter kernelspec list
```

### One gotcha with uv's `.venv`

uv names its venv folder `.venv`, so `$VIRTUAL_ENV` will be something like `/home/you/projects/my-project/.venv`. The auto-init keymap would extract `.venv` as the name, which won't match the kernel. Two ways to handle this:

**Option A** — override the kernel name check with a smarter keymap:

```lua
vim.keymap.set("n", "<localleader>mi", function()
  local venv = os.getenv("VIRTUAL_ENV")
  if venv ~= nil then
    -- try project dir name first, fall back to venv dir name
    local project = string.match(venv, "/.+/(.+)/%.venv$")
              or string.match(venv, "/.+/(.+)$")
    vim.cmd(("MoltenInit %s"):format(project))
  else
    vim.cmd("MoltenInit python3")
  end
end, { desc = "MoltenInit: auto venv kernel", silent = true })
```

**Option B** (simpler) — just always name your kernel after the project, and call `:MoltenInit my-project` explicitly when the auto keymap doesn't fit.

### Starting a session day-to-day

```bash
cd ~/projects/my-project
source .venv/bin/activate    # sets $VIRTUAL_ENV
nvim my_script.py
```

Then `<localleader>mi` in Neovim to start the kernel.

Or use `direnv` to auto-activate: put `source .venv/bin/activate` in a `.envrc` and run `direnv allow` once.

---

## Quick reference

| Task | Command |
|---|---|
| Verify setup | `:checkhealth molten` |
| List available kernels | `jupyter kernelspec list` |
| Remove a kernel | `jupyter kernelspec remove <name>` |
| Start kernel in nvim | `:MoltenInit <name>` or `<localleader>mi` |
| Evaluate line | `:MoltenEvaluateLine` |
| Evaluate visual selection | `:MoltenEvaluateVisual` |
| Restart kernel | `:MoltenRestart` |
| After updating molten | `:UpdateRemotePlugins` then restart |
