local wezterm = require 'wezterm'

local config = wezterm.config_builder()
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

if not wezterm.GLOBAL.resurrect_timer_started then
  resurrect.state_manager.periodic_save({
    interval_seconds = 15 * 60,
    save_workspaces = true,
    save_windows = true,
    save_tabs = true,
  })
  wezterm.GLOBAL.resurrect_timer_started = true
end

config.inactive_pane_hsb = {
  saturation = 0.8,  -- Keep original colors
  brightness = 0.5,  -- Dim inactive panes
}

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 14.0
config.window_decorations = "RESIZE"

config.keys = {
    -- pane navigtation stuff
    { key = ';', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Right") },
    { key = 'j', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Left") },
    { key = 'k', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Up") },
    { key = 'l', mods = 'CMD|SHIFT', action = wezterm.action.ActivatePaneDirection("Down") },
    { key = '1', mods = 'CMD|SHIFT|ALT|CTRL', action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
    { key = '2', mods = 'CMD|SHIFT|ALT|CTRL', action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },

    -- resurrect stuff
    {
      key = 's',
      mods = 'CMD|SHIFT',
      action = wezterm.action_callback(function(window)
        wezterm.log_info "resurrect: saving current workspace state"
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
      end),
    },
    {
      key = 't',
      mods = 'CMD|SHIFT',
      action = wezterm.action_callback(function(window, pane)
        resurrect.fuzzy_loader.fuzzy_load(window, pane, function(id, label)
          local type = string.match(id, "^([^/]+)") -- match before '/'
          id = string.match(id, "([^/]+)$")         -- match after '/'
          id = string.match(id, "(.+)%..+$")        -- remove file extension
          if type == "workspace" then
            local state = resurrect.state_manager.load_state("default", "workspace")
            if state and state.window_states and #state.window_states > 0 then
              local last_window = state.window_states[1]
              local restore_opts = {
                window = pane:window(),
                close_open_tabs = true,
                relative = true,
                restore_text = true,
                on_pane_restore = resurrect.tab_state.default_on_pane_restore,
              }
              resurrect.window_state.restore_window(pane:window(), last_window, restore_opts)
            else
              wezterm.log_error("resurrect: Last session file found, but it contained no windows.")
            end
          end
        end)
      end),
    }
  }
  
-- << Nixie Clock

-- Image dimensions and layout
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
  local time_str = wezterm.strftime('%H%M')
  local time_parts = {
    time_str:sub(1, 1),
    time_str:sub(2, 2),
    time_str:sub(3, 3),
    time_str:sub(4, 4),
  }
  
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

-- Update clock every minute using update-status event (no config reload needed)
config.status_update_interval = 60000  -- 60 seconds in milliseconds

wezterm.on('update-status', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  overrides.background = build_nixie_background()
  window:set_config_overrides(overrides)
end)

-- Nixie Clock code >>

return config
