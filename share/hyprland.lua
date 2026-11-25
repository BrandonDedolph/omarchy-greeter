-- Compositor config for the omarchy-greeter login screen: Omarchy's own
-- greeter config, plus keeping keyboard focus on the primary monitor so
-- typing always reaches the visible password field.
-- Everything below fails soft: if an Omarchy or Hyprland update moves a file
-- or changes the Lua API, that one piece is skipped (and logged) and the
-- login screen still comes up, at worst with Hyprland's defaults.
local function try(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then print("omarchy-greeter: " .. what .. " skipped: " .. tostring(err)) end
  return ok
end

-- Omarchy's own greeter config first (keyboard layout and the like).
try("Omarchy greeter config", dofile, "/usr/share/sddm/hyprland.lua")

local function read_setting(key)
  local file = io.open("/etc/omarchy-greeter.conf", "r")
  if not file then return "" end
  local found = ""
  for line in file:lines() do
    local value = line:match("^%s*" .. key .. "%s*=%s*(%S*)")
    if value then found = value end
  end
  file:close()
  return found
end

local primary = read_setting("primary")

-- Drive the displays exactly as the desktop does, so moving between the
-- login screen and a session needs no mode change (which blanks monitors):
--  * SDR, like Omarchy's desktop (cm_auto_hdr = 0). Hyprland's default
--    switches HDR displays into HDR for a fullscreen window, and the login
--    screen is one, so every switch flipped the signal and both monitors
--    resynced.
--  * the same mode, position and scale per monitor as the last user's
--    desktop, published by omarchy-greeter-sync and checked by publish-view
--    as "name WxH@R XxY scale transform".
try("SDR", function() hl.config({ render = { cm_auto_hdr = 0 } }) end)

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
  -- The root-checked copy (a regular, small, root-owned file), never the
  -- account's own folder.
  local file = io.open("/var/lib/omarchy-greeter/.view/" .. user .. "/monitors", "r")
  if not file then return end
  local count = 0
  for line in file:lines() do
    count = count + 1
    if count > 16 then break end
    local name, mode, position, scale, transform = line:match("^([%w._-]+) (%d+x%d+@[%d.]+) (%-?%d+x%-?%d+) ([%d.]+) ?(%d?)$")
    local s = tonumber(scale)
    local w, h = (mode or ""):match("^(%d+)x(%d+)")
    w, h = tonumber(w), tonumber(h)
    -- Written by the account; only plausible values are applied.
    if name and s and s >= 0.5 and s <= 4 and w and h and w >= 640 and h >= 480 and w <= 15360 and h <= 8640 then
      local t = tonumber(transform)
      local settings = { output = name, mode = mode, position = position, scale = s }
      if t and t >= 0 and t <= 7 then settings.transform = t end
      hl.monitor(settings)
    end
  end
  file:close()
end

try("monitor layout", function() apply_user_monitors(last_user()) end)

local function primary_connected()
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name == primary then return true end
  end
  return false
end

if primary ~= "" then try("primary monitor", function()
  hl.config({
    input = { follow_mouse = 0 },
    cursor = { default_monitor = primary },
  })

  local function focus_primary()
    pcall(function()
      if not primary_connected() then return end
      local active = hl.get_active_monitor()
      if active and active.name == primary then return end
      hl.dispatch(hl.dsp.focus({ monitor = primary }))
    end)
  end

  hl.on("window.open", focus_primary)
  hl.on("monitor.focused", focus_primary)
  hl.on("monitor.added", focus_primary)
end) end

-- Turn the displays off after screen_off seconds without typing (default
-- 120; 0: never). Locking opens this screen, so it has to blank the way the
-- lock does. A key press or mouse move turns them back on (Hyprland), and the
-- check below notices and starts counting again.
local screen_off = tonumber(read_setting("screen_off")) or 120
if screen_off > 0 then try("screen off", function()
  screen_off = math.min(math.max(screen_off, 15), 3600)
  hl.config({ misc = { key_press_enables_dpms = true, mouse_move_enables_dpms = true } })
  local last_input = os.time()
  local blanked = false
  hl.on("input.keyboard.key", function()
    last_input = os.time()
    blanked = false
  end)
  hl.timer(function()
    pcall(function()
      if blanked then
        -- Woken by the mouse (no event for that): count from now.
        for _, monitor in ipairs(hl.get_monitors()) do
          if monitor.dpms_status then
            blanked = false
            last_input = os.time()
            return
          end
        end
        return
      end
      if os.time() - last_input >= screen_off then
        hl.dispatch(hl.dsp.dpms({ action = "disable" }))
        blanked = true
      end
    end)
  end, { timeout = 5000, type = "repeat" })
end) end
