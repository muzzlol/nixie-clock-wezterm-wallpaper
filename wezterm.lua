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
local function get_time_parts()
  if wezterm.strftime then
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
  local now = os.date('*t')
  return {
    string.format('%02d', now.hour):sub(1, 1),
    string.format('%02d', now.hour):sub(2, 2),
    string.format('%02d', now.min):sub(1, 1),
    string.format('%02d', now.min):sub(2, 2),
    string.format('%02d', now.sec):sub(1, 1),
    string.format('%02d', now.sec):sub(2, 2),
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
  wezterm.GLOBAL.last_time_parts = { '', '', '', '', '', '' }
end

init_nixie_layers()

wezterm.on('update-status', function(window, pane)
  init_nixie_layers()

  local time_parts = get_time_parts()

  wezterm.GLOBAL.separator_state = (wezterm.GLOBAL.separator_state + 1) % 2
  local sep_idx = wezterm.GLOBAL.separator_state + 1 -- 1 or 2

  local desired_sources = {
    digit_sources[time_parts[1]],
    digit_sources[time_parts[2]],
    separator_sources[sep_idx],
    digit_sources[time_parts[3]],
    digit_sources[time_parts[4]],
    separator_sources[sep_idx],
    digit_sources[time_parts[5]],
    digit_sources[time_parts[6]],
  }

  local layers = wezterm.GLOBAL.nixie_layers
  local changed = false

  for i, src in ipairs(desired_sources) do
    local layer = layers[i + 1]

    if layer.source ~= src then
      layer.source = src
      changed = true
    end
  end

  if changed then
    local overrides = window:get_config_overrides() or {}
    overrides.background = layers
    window:set_config_overrides(overrides)
  end
end)

-- Clock updates every second.
config.status_update_interval = 1000

-- Nixie clock >

return config
