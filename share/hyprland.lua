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

-- Drive the displays exactly as the desktop does, so moving between the
-- login screen and a session needs no mode change (which blanks monitors):
--  * SDR, like Omarchy's desktop (cm_auto_hdr = 0). Hyprland's default
--    switches HDR displays into HDR for a fullscreen window, and the login
--    screen is one, so every switch flipped the signal and both monitors
--    resynced.
--  * the same mode, position and scale per monitor as the last user's
--    desktop, published by omarchy-greeter-sync as "name WxH@R XxY scale".
hl.config({ render = { cm_auto_hdr = 0 } })

local function last_user()
  local file = io.open("/var/lib/sddm/state.conf", "r")
  if not file then return nil end
  local user
  for line in file:lines() do
    local value = line:match("^%s*User%s*=%s*([%w._-]+)")
    if value then user = value end
  end
  file:close()
  return user
end

local function apply_user_monitors(user)
  if not user then return end
  local file = io.open("/var/lib/omarchy-greeter/" .. user .. "/monitors", "r")
  if not file then return end
  for line in file:lines() do
    local name, mode, position, scale = line:match("^([%w._-]+) (%d+x%d+@[%d.]+) (%-?%d+x%-?%d+) ([%d.]+)$")
    local s = tonumber(scale)
    local w, h = (mode or ""):match("^(%d+)x(%d+)")
    w, h = tonumber(w), tonumber(h)
    -- Written by the account; only plausible values are applied.
    if name and s and s >= 0.5 and s <= 4 and w and h and w >= 640 and h >= 480 and w <= 15360 and h <= 8640 then
      hl.monitor({ output = name, mode = mode, position = position, scale = s })
    end
  end
  file:close()
end

apply_user_monitors(last_user())

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
