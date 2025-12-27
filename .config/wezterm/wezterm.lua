local wezterm = require("wezterm")
local act = wezterm.action
local font = wezterm.font
local config = wezterm.config_builder()

-- ====================== Appearance ======================
-- Hyprland
config.enable_wayland = false

-- Color scheme
config.color_scheme = "Dark+"

-- Window size
config.initial_cols = 120
config.initial_rows = 35

-- Transparency
config.window_background_opacity = 1

-- Font
config.font = font("JetBrainsMono Nerd Font")
config.font_size = 20
config.hide_mouse_cursor_when_typing = true

-- Font Anti-Aliasing
config.freetype_load_target = 'Normal'
config.freetype_render_target = 'HorizontalLcd'

-- Cursor
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 500

-- Scrollback
config.scrollback_lines = 100000

-- Window decorations
config.window_decorations = "NONE"

-- Spawn a fish shell in login mode
config.default_prog = { '/usr/bin/fish', '-l' }

-- ====================== Tab Bar ======================
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

-- ====================== Keybindings ======================
-- Refer to https://wezterm.org/config/lua/keyassignment/index.html
config.keys = {
  {
    key = 'w',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.CloseCurrentPane { confirm = false },
  },
  {
    key = '"',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.SplitHorizontal
  },
  {
    key = ':',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.SplitVertical
  },
  {
    key = 'h',
    mods = 'CTRL|SHIFT|ALT',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'l',
    mods = 'CTRL|SHIFT|ALT',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    key = 'k',
    mods = 'CTRL|SHIFT|ALT',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'j',
    mods = 'CTRL|SHIFT|ALT',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = 'w',
    mods = 'ALT',
    action = wezterm.action.CloseCurrentTab { confirm = false },
  },
  {
    key = 'n',
    mods = 'ALT',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
}

for i = 1, 9 do
  -- ALT + number to activate that tab
  table.insert(config.keys, {
    key = tostring(i),
    mods = 'ALT',
    action = act.ActivateTab(i - 1),
  })
end

return config
