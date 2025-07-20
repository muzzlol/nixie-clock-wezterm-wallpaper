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
  
-- << Nixie Clock
local function get_time_parts()
    local time_str = wezterm.strftime('%H%M')
    return {
      time_str:sub(1, 1),
      time_str:sub(2, 2),
      time_str:sub(3, 3),
      time_str:sub(4, 4),
    }
end

local image_width = 110
local image_height = 280
local slot_width = 115
local total_width = 5 * slot_width  -- 4 digits + 1 separator
local start_offset = -total_width / 2 + slot_width / 2

local clock_part_offsets = {}
for i = 1, 5 do
  table.insert(clock_part_offsets, start_offset + (i - 1) * slot_width)
end

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

-- Build the background layers based on current time
local function build_nixie_background()
  local layers = { background_layer }
  local time_parts = get_time_parts()
  
  -- Calculate separator state based on current minute for blinking effect
  local current_minute = tonumber(time_parts[3] .. time_parts[4])
  local separator_state = current_minute % 2
  local separator_source = separator_sources[separator_state + 1]
  
  -- Add layers for HH:MM format
  for i, offset in ipairs(clock_part_offsets) do
    if i == 3 then
      -- Add separator at position 3
      table.insert(layers, make_layer(separator_source, offset))
    else
      -- Map positions to time parts: 1->H1, 2->H2, 4->M1, 5->M2
      local time_part_idx = (i <= 2) and i or (i - 1)
      local digit = time_parts[time_part_idx]
      table.insert(layers, make_layer(digit_sources[digit], offset))
    end
  end
  
  return layers
end

-- Set initial background
config.background = build_nixie_background()

-- Schedule updates every minute
local function schedule_next_update()
  local current_seconds = tonumber(wezterm.strftime('%S'))
  local seconds_until_next_minute = (60 - current_seconds) % 60
  if seconds_until_next_minute == 0 then
    seconds_until_next_minute = 60
  end
  
  wezterm.time.call_after(seconds_until_next_minute, function()
    wezterm.reload_configuration()
  end)
end

-- Start the update cycle
schedule_next_update()

-- Nixie Clock code >>

return config


