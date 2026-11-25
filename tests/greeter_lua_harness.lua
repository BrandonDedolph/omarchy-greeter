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
hl = {
  config = function(t) table.insert(calls, "config") end,
  monitor = function(t)
    table.insert(calls, string.format("monitor %s %s %s %s %s", t.output, t.mode, t.position, t.scale, tostring(t.transform)))
  end,
  on = function(event) table.insert(calls, "on " .. event) end,
  get_monitors = function() return {} end,
  get_active_monitor = function() return nil end,
  dispatch = function() end,
  dsp = { focus = function() end },
}
local chunk = assert(loadfile(repo .. "/share/hyprland.lua"))
chunk()
for _, call in ipairs(calls) do print(call) end
