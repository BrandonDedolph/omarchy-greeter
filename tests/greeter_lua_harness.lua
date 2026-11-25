-- Runs share/hyprland.lua against a stand-in Hyprland and fixture files.
-- usage: lua greeter_lua_harness.lua <repo> <fixtures dir>
local repo, fixtures = arg[1], arg[2]
local real_open = io.open
local map = {
  ["/etc/omarchy-greeter.conf"] = fixtures .. "/omarchy-greeter.conf",
  ["/var/lib/sddm/state.conf"] = fixtures .. "/state.conf",
}
io.open = function(path, mode)
  local mapped = map[path]
  if not mapped and path:match("^/var/lib/omarchy%-greeter/") then
    mapped = fixtures .. path:gsub("^/var/lib/omarchy%-greeter", "")
  end
  if not mapped and path:match("^/") then return nil, "not in fixtures" end
  return real_open(mapped or path, mode)
end
-- Omarchy's own greeter config is not part of this test.
dofile = function() end

local calls = {}
local handlers, timers = {}, {}
local now = 1000
os.time = function() return now end
hl = {
  config = function(t) table.insert(calls, "config") end,
  monitor = function(t)
    table.insert(calls, string.format("monitor %s %s %s %s %s", t.output, t.mode, t.position, t.scale, tostring(t.transform)))
  end,
  on = function(event, cb)
    table.insert(calls, "on " .. event)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], cb)
  end,
  timer = function(cb, opts)
    table.insert(calls, string.format("timer %d %s", opts.timeout, opts.type))
    table.insert(timers, cb)
  end,
  get_monitors = function() return {} end,
  get_active_monitor = function() return nil end,
  dispatch = function(d) if d then table.insert(calls, d) end end,
  dsp = {
    focus = function() return nil end,
    dpms = function(t) return "dpms " .. t.action end,
  },
}
local chunk = assert(loadfile(repo .. "/share/hyprland.lua"))
chunk()
-- Idle simulation: "at <seconds>" lines mark the stand-in clock.
local function tick(seconds)
  now = 1000 + seconds
  table.insert(calls, "at " .. seconds)
  for _, cb in ipairs(timers) do cb() end
end
local function key()
  for _, cb in ipairs(handlers["input.keyboard.key"] or {}) do cb() end
end
tick(119)
tick(121)
key()
tick(200)
tick(330)
for _, call in ipairs(calls) do print(call) end
