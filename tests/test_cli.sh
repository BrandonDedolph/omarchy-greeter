#!/bin/bash
# bin/omarchy-greeter: menu entries, settings and what it asks root to do.
# Root steps are never run: a stand-in pkexec records what would be asked.
source "$(dirname "$0")/lib.sh"
cfg=$TMP/config fake=$TMP/bin conf=$TMP/omarchy-greeter.conf asked=$TMP/asked
mkdir -p "$cfg" "$fake"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> %q\n' "$asked" > "$fake/pkexec"
printf '#!/bin/bash\nexit 0\n' > "$fake/notify-send"
chmod +x "$fake"/*
og() { HOME=$TMP XDG_CONFIG_HOME=$cfg OMARCHY_GREETER_CONF=$conf OMARCHY_GREETER_BOOT_STATUS=$TMP/no-boot-status PATH=$fake:$PATH "$REPO/bin/omarchy-greeter" "$@" < /dev/null; }
menu=$cfg/omarchy/extensions/omarchy-menu.jsonc
me=$(id -un)

# ---- menu ---------------------------------------------------------------
mkdir -p "${menu%/*}"
printf '{\n  // my own entry\n  "mine": {"label": "Mine"},\n}\n' > "$menu"
chmod 640 "$menu"
check "menu install" og menu install
check "block added" grep -q 'omarchy-greeter (managed' "$menu"
check "own entries kept" grep -q '"mine"' "$menu"
equal "file mode kept" "640" "$(stat -c %a "$menu")"
before=$(cat "$menu")
og menu ensure >/dev/null
equal "ensure leaves an up-to-date block alone" "$before" "$(cat "$menu")"
check "menu remove" og menu remove
check_not "block removed" grep -q 'omarchy-greeter' "$menu"
check "own entries still there" grep -q '"mine"' "$menu"
og menu ensure >/dev/null
check_not "ensure respects removal" grep -q 'omarchy-greeter' "$menu"
og menu install >/dev/null && og menu purge >/dev/null && og menu ensure >/dev/null
check "purge forgets the removal (reinstall gets the menu)" grep -q 'omarchy-greeter (managed' "$menu"
printf '{}\n' > "$menu"
check "one-line {} file" og menu install
check "block added to {}" grep -q 'omarchy-greeter (managed' "$menu"
# Every entry is valid JSONC once comments are stripped.
check "menu is valid JSON" bash -c "sed 's|^[[:space:]]*//.*||' '$menu' | tr -d '\n' | sed 's/,[[:space:]]*}/}/g' | jq -e . >/dev/null"

# ---- settings -----------------------------------------------------------
printf 'primary=DP-2\nboot_unlock=yes\n' > "$conf"
equal "monitor read" "DP-2" "$(og monitor)"
equal "legacy boot_unlock=yes reads as off" "off" "$(og boot-pass)"
: > "$asked"
og boot-pass on >/dev/null
equal "boot-pass on asks for this account" "/usr/bin/omarchy-greeter _set boot_unlock $me" "$(cat "$asked")"
printf 'boot_unlock=root,%s\n' "$me" > "$conf"
equal "listed account reads as on" "on" "$(og boot-pass)"
: > "$asked"
og boot-pass off >/dev/null
equal "boot-pass off keeps the others" "/usr/bin/omarchy-greeter _set boot_unlock root" "$(cat "$asked")"
: > "$asked"
og boot-pass off no-such-account-xyz >/dev/null
equal "off works for a deleted account" "/usr/bin/omarchy-greeter _set boot_unlock root,$me" "$(cat "$asked")"
check_not "on refuses a deleted account" og boot-pass on no-such-account-xyz
check_not "bad account names refused" og boot-pass on 'x;rm -rf'
: > "$asked"
og video on >/dev/null
equal "video asks once" "/usr/bin/omarchy-greeter _video yes" "$(cat "$asked")"
: > "$asked"
og monitor 'DP-1' >/dev/null
equal "monitor by name" "/usr/bin/omarchy-greeter _set primary DP-1" "$(cat "$asked")"

: > "$asked"
og screen-off 5 >/dev/null
equal "screen-off has a floor" "/usr/bin/omarchy-greeter _set screen_off 15" "$(cat "$asked")"
check_not "screen-off takes a number" og screen-off soon
printf 'screen_off=0\n' > "$conf"
equal "status: screen never off" "Login screen display off:    never" "$(og status | grep 'display off')"
: > "$conf"
equal "screen off after 120s by default" "120" "$(og screen-off)"

# ---- root steps refuse to run unprivileged -------------------------------
for step in "_set primary DP-1" "_video yes" "_install /dev/null /dev/null 1.0.0-1" "_user-admin root on"; do
  # shellcheck disable=SC2086
  check_not "$step needs root" og $step
done

printf 'primary=\nboot_unlock=alex,sam\n' > "$conf"
equal "status: boot pass" "One password at boot:        on for alex, sam" "$(og status | grep 'One password')"
printf 'boot_unlock=no\n' > "$conf"
equal "status: boot pass off" "One password at boot:        off" "$(og status | grep 'One password')"
equal "status: monitor" "Login and lock forms on:     all" "$(og status | grep 'forms on')"
check "help" og --help
check "version" og --version
check "status" og status
finish
