#!/bin/bash
# share/hyprland.lua: which monitor settings the login screen's compositor applies.
source "$(dirname "$0")/lib.sh"
lua=$(command -v lua5.4 || command -v lua) || { echo "  skipped: no lua"; finish; exit; }
fx=$TMP/fixtures
mkdir -p "$fx/.view/alex"
printf 'primary=DP-2\n' > "$fx/omarchy-greeter.conf"
printf '[Last]\nUser=alex\nSession=/usr/share/wayland-sessions/omarchy.desktop\n' > "$fx/state.conf"
cat > "$fx/.view/alex/monitors" <<'M'
DP-1 3840x2160@120 0x0 1 0
DP-2 2560x1440@144 3840x0 1.25 1
eDP-1 2880x1800@120 0x0 1.5
tiny 320x200@60 0x0 1 0
huge 3840x2160@60 0x0 9 0
bad;name 1920x1080@60 0x0 1 0
M
out=$("$lua" "$REPO/tests/greeter_lua_harness.lua" "$REPO" "$fx" 2>&1)
check "valid monitor applied" grep -qx 'monitor DP-1 3840x2160@120 0x0 1 0' <<<"$out"
check "rotation applied" grep -qx 'monitor DP-2 2560x1440@144 3840x0 1.25 1' <<<"$out"
check "older 5-field line still works" grep -qx 'monitor eDP-1 2880x1800@120 0x0 1.5 nil' <<<"$out"
check_not "too small refused" grep -q 'monitor tiny' <<<"$out"
check_not "absurd scale refused" grep -q 'monitor huge' <<<"$out"
check_not "odd name refused" grep -q 'bad;name' <<<"$out"
check "primary focus wired up" grep -qx 'on monitor.added' <<<"$out"
check_not "no Lua errors" grep -q 'skipped' <<<"$out"

# Only the root-checked copy is read, never the account's own folder.
mkdir -p "$fx/alex" && cp "$fx/.view/alex/monitors" "$fx/alex/monitors" && rm "$fx/.view/alex/monitors"
out=$("$lua" "$REPO/tests/greeter_lua_harness.lua" "$REPO" "$fx" 2>&1)
check_not "account folder ignored" grep -q '^monitor' <<<"$out"

# More than 16 lines: the rest is ignored.
for i in $(seq 1 20); do echo "M$i 1920x1080@60 0x0 1 0"; done > "$fx/.view/alex/monitors"
out=$("$lua" "$REPO/tests/greeter_lua_harness.lua" "$REPO" "$fx" 2>&1)
equal "at most 16 monitors" "16" "$(grep -c '^monitor' <<<"$out")"

# A missing state file or view: still loads, applies nothing.
rm -f "$fx/state.conf"
out=$("$lua" "$REPO/tests/greeter_lua_harness.lua" "$REPO" "$fx" 2>&1)
check_not "no last user: no monitors" grep -q '^monitor' <<<"$out"
check_not "and no errors" grep -q 'skipped' <<<"$out"
finish
