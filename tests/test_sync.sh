#!/bin/bash
# bin/omarchy-greeter-sync, publishing into a temporary folder.
source "$(dirname "$0")/lib.sh"
home=$TMP/home pub=$TMP/pub me=$(id -un)
mkdir -p "$home/.local/state/omarchy/current/theme" "$home/.config/hypr" "$home/.config/omarchy" "$pub/$me"
state=$home/.local/state/omarchy/current
printf 'background = "#112233"\naccent = "#445566"\n' > "$state/theme/colors.toml"
echo "Test Theme" > "$state/theme.name"
sync() { HOME=$home XDG_CONFIG_HOME=$home/.config OMARCHY_GREETER_DIR=$pub "$REPO/bin/omarchy-greeter-sync" "$@"; }

# A video background is published, and survives the next (unchanged) run.
if command -v ffmpeg >/dev/null; then
  ffmpeg -v error -f lavfi -i color=red:s=320x240:d=1 -c:v mpeg4 "$home/bg.mp4"
  ln -sf "$home/bg.mp4" "$state/background"
  check "first sync" sync --offline
  equal "video named" "background.mp4" "$(cat "$pub/$me/video")"
  check "second sync" sync --offline
  equal "video kept on resync" "background.mp4" "$(cat "$pub/$me/video")"
  check "video file kept" test -s "$pub/$me/background.mp4"
  check "still made from the video" test -s "$pub/$me/background.jpg"
  check "blurred copy made" test -s "$pub/$me/background-blur.jpg"
fi

# A still background: the blurred copy is made once and kept while unchanged.
if command -v magick >/dev/null; then
  magick -size 800x450 gradient:'#203040-#a0b0c0' "$home/bg.png"
  ln -sf "$home/bg.png" "$state/background"
  check "sync with a still background" sync --offline
  check "blurred copy of the still" test -s "$pub/$me/background-blur.jpg"
  equal "blurred copy scaled to fit 1920" "1920x1080" "$(magick identify -format %wx%h "$pub/$me/background-blur.jpg")"
  before=$(md5sum < "$pub/$me/background-blur.jpg")
  sync --offline >/dev/null 2>&1
  equal "blurred copy kept while unchanged" "$before" "$(md5sum < "$pub/$me/background-blur.jpg")"
fi

# Files are private to the account.
equal "published files are 0600" "600" "$(stat -c %a "$pub/$me/colors.toml")"

# Monitors from monitors.lua at boot, rotation included.
rm -f "$pub/$me/display.json"
echo 'hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x0", scale = 1.5, transform = 3 })' > "$home/.config/hypr/monitors.lua"
check "sync with monitors.lua" sync --offline
equal "monitor line" "eDP-1 2880x1800@120 0x0 1.5 3" "$(cat "$pub/$me/monitors")"

# A monitors.lua without hl.monitor lines must not stop the sync.
echo '-- nothing here' > "$home/.config/hypr/monitors.lua"
touch -d '+1 minute' "$home/.config/hypr/monitors.lua"
check "sync with an empty monitors.lua" sync --offline

# The shell font size, with or without spaces around =.
for line in 'base-size = 14' 'base-size=14' '  base-size =14'; do
  printf '[font]\n%s\n' "$line" > "$home/.config/omarchy/shell.toml"
  sync --offline >/dev/null 2>&1
  equal "font size from [$line]" "14" "$(jq -r .fontBaseSize "$pub/$me/display.json")"
done

# Opted out: nothing published.
rm -rf "${pub:?}/$me"/* && mkdir -p "$home/.config/omarchy-greeter" && touch "$home/.config/omarchy-greeter/no-publish"
check "opted-out sync succeeds" sync --offline
equal "nothing published when opted out" "" "$(ls "$pub/$me")"
finish
