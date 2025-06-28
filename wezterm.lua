local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.max_fps = 120
config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 14.0
config.window_decorations = "RESIZE"

-- Key Bindings for Pane Navigation
config.keys = {
    { key = 'RightArrow', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Right") },
    { key = 'LeftArrow', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Left") },
    { key = 'UpArrow', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Up") },
    { key = 'DownArrow', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Down") },
    { key = '5', mods = 'CMD|SHIFT|ALT|CTRL', action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
    { key = ';', mods = 'CMD|SHIFT|ALT|CTRL', action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
  }
  
  -- < Nixie Clock code
  
  -- Clock updates every second.
  config.status_update_interval = 1000
  
local function get_time_parts()
    local time_str = wezterm.strftime('%H%M%S')
    return {
      time_str:sub(1, 1),
      time_str:sub(2, 2),
      time_str:sub(3, 3),
      time_str:sub(4, 4),
      time_str:sub(5, 5),
      time_str:sub(6, 6),
    }
end

local image_width = 110
local image_height = 280
local slot_width = 115
local total_width = 8 * slot_width
local start_offset = -total_width / 2 + slot_width / 2

local clock_part_offsets = {}
for i = 1, 8 do
  table.insert(clock_part_offsets, start_offset + (i - 1) * slot_width)
end

wezterm.GLOBAL.separator_state = wezterm.GLOBAL.separator_state or 0

local background_layer = {
  source = { Color = 'black' },
  width = '100%',
  height = '100%',
}

local digit_sources = {}
for i = 0, 9 do
  digit_sources[tostring(i)] = { File = wezterm.config_dir .. '/' .. i .. '.png' }
end

local separator_sources = {
  { File = wezterm.config_dir .. '/11.png' },
  { File = wezterm.config_dir .. '/12.png' },
}

local function make_layer(src, offset)
  return {
    source = src,
    opacity = 0.5,
    width = image_width,
    height = image_height,
    repeat_x = 'NoRepeat',
    repeat_y = 'NoRepeat',
    horizontal_align = 'Center',
    vertical_align = 'Middle',
    horizontal_offset = offset,
  }
end

local function init_nixie_layers()
  if wezterm.GLOBAL.nixie_layers then
    return
  end

  local layers = { background_layer }

  for i, offset in ipairs(clock_part_offsets) do
    table.insert(layers, make_layer(digit_sources['0'], offset))
  end

  wezterm.GLOBAL.nixie_layers = layers
  wezterm.GLOBAL.last_time_parts = { 'x', 'x', 'x', 'x', 'x', 'x' } -- Force update on first run
end

init_nixie_layers()

local time_part_to_layer_idx = {
  [1] = 2, -- H1
  [2] = 3, -- H2
  [3] = 5, -- M1
  [4] = 6, -- M2
  [5] = 8, -- s1
  [6] = 9, -- s2
}

wezterm.on('update-status', function(window, pane)
  init_nixie_layers()

  local current_time_parts = get_time_parts()
  local last_time_parts = wezterm.GLOBAL.last_time_parts
  local layers = wezterm.GLOBAL.nixie_layers
  local changed = false

  -- Loop over the time parts, from seconds to hours, as seconds are
  -- most likely to have changed.
  for i = 6, 1, -1 do
    if current_time_parts[i] ~= last_time_parts[i] then
      local layer_idx = time_part_to_layer_idx[i]
      local new_digit_source = digit_sources[current_time_parts[i]]
      if layers[layer_idx].source ~= new_digit_source then
        layers[layer_idx].source = new_digit_source
        changed = true
      end
    end
  end

  -- Update the blinking separators, which change every second
  wezterm.GLOBAL.separator_state = (wezterm.GLOBAL.separator_state + 1) % 2
  local sep_idx = wezterm.GLOBAL.separator_state + 1 -- will be 1 or 2
  local new_separator_source = separator_sources[sep_idx]

  -- Separator between HH and MM is at layer index 4
  if layers[4].source ~= new_separator_source then
    layers[4].source = new_separator_source
    changed = true
  end
  -- Separator between MM and SS is at layer index 7
  if layers[7].source ~= new_separator_source then
    layers[7].source = new_separator_source
    changed = true
  end

  if changed then
    -- Store the new time for the next comparison
    wezterm.GLOBAL.last_time_parts = current_time_parts
    -- Apply the configuration changes
    local overrides = window:get_config_overrides() or {}
    overrides.background = layers
    window:set_config_overrides(overrides)
  end
end)


-- Nixie clock >

return config
