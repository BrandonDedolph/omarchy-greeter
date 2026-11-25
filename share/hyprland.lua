-- Compositor config for the omarchy-greeter login screen: Omarchy's own
-- greeter config, plus keeping keyboard focus on the primary monitor so
-- typing always reaches the visible password field.
dofile("/usr/share/sddm/hyprland.lua")

local function read_primary()
  local file = io.open("/etc/omarchy-greeter.conf", "r")
  if not file then return "" end
  local primary = ""
  for line in file:lines() do
    local value = line:match("^%s*primary%s*=%s*(%S*)")
    if value then primary = value end
  end
  file:close()
  return primary
end

local primary = read_primary()

local function primary_connected()
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name == primary then return true end
  end
  return false
end

if primary ~= "" then
  hl.config({
    input = { follow_mouse = 0 },
    cursor = { default_monitor = primary },
  })

  local function focus_primary()
    if not primary_connected() then return end
    local active = hl.get_active_monitor()
    if active and active.name == primary then return end
    hl.dispatch(hl.dsp.focus({ monitor = primary }))
  end

  hl.on("window.open", focus_primary)
  hl.on("monitor.focused", focus_primary)
  hl.on("monitor.added", focus_primary)
end
