#!/bin/bash
# lib/greeter-compositor: starts Hyprland for the login screen with core dumps
# skipped (limit of exactly 1 byte) and the arguments passed through.
source "$(dirname "$0")/lib.sh"
fake=$TMP/bin
mkdir -p "$fake"
cat > "$fake/start-hyprland" <<'S'
#!/bin/bash
echo "args=$*"
echo "core=$(awk '/^Max core file size/ {print $5}' /proc/self/limits)"
S
chmod +x "$fake/start-hyprland"
out=$(PATH=$fake:$PATH "$REPO/lib/greeter-compositor" --config /x/hyprland.lua)
equal "arguments reach Hyprland" "args=-- --config /x/hyprland.lua" "$(grep '^args=' <<<"$out")"
equal "core dumps skipped" "core=1" "$(grep '^core=' <<<"$out")"
check "SDDM starts it" grep -qx 'CompositorCommand=/usr/lib/omarchy-greeter/greeter-compositor --config /usr/share/omarchy-greeter/hyprland.lua' "$REPO/sddm/zzz-omarchy-greeter.conf"
finish
