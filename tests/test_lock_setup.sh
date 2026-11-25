#!/bin/bash
# bin/omarchy-greeter-lock-setup with stand-ins for the omarchy commands
# (no shell is running, so it never restarts anything).
source "$(dirname "$0")/lib.sh"
stock=/usr/share/omarchy/shell/plugins/lock
[[ -f $stock/Service.qml ]] || { echo "  skipped: no Omarchy lock plugin at $stock"; finish; exit; }
home=$TMP/home fake=$TMP/bin me=tester
mkdir -p "$home/.config/omarchy" "$fake"
notes=$TMP/notifications
cat > "$fake/omarchy" <<SH
#!/bin/bash
# omarchy plugin clone omarchy.lock -> ~/.config/omarchy/plugins/<user>.lock
if [[ \$1 == plugin && \$2 == clone ]]; then mkdir -p "\$HOME/.config/omarchy/plugins/$me.lock" && cp -r $stock/. "\$HOME/.config/omarchy/plugins/$me.lock/"; fi
if [[ \$1 == plugin && \$2 == remove ]]; then rm -rf "\$HOME/.config/omarchy/plugins/$me.lock"; fi
exit 0
SH
printf '#!/bin/bash\nexit 1\n' > "$fake/omarchy-shell"        # no shell running
printf '#!/bin/bash\necho "$*" >> %q\n' "$notes" > "$fake/notify-send"
printf '#!/bin/bash\nexit 0\n' > "$fake/logger"   # never into the real journal
chmod +x "$fake"/*
setup() { env HOME="$home" USER=$me PATH="$fake:$PATH" "$@" "$REPO/bin/omarchy-greeter-lock-setup" "${args[@]}"; }
run() { args=("$@"); setup env OMARCHY_GREETER_LOCK_UI="$REPO/lock:$REPO/theme" OMARCHY_GREETER_PATCH="$REPO/lib/patch-lock.py"; }
clone=$home/.config/omarchy/plugins/$me.lock

check "first setup" run --ensure
check "clone patched" grep -q 'omarchy-greeter:primary-lock' "$clone/Service.qml"
check "stamp written" test -s "$clone/.omarchy-greeter-stamp"
before=$(stat -c %Y "$clone/Service.qml")
sleep 1; run --ensure; run --at-login
equal "nothing rebuilt when up to date" "$before" "$(stat -c %Y "$clone/Service.qml")"

# A patch that no longer fits: back to the built-in lock, said once.
printf 'import sys\nsys.exit("does not fit")\n' > "$TMP/bad-patch.py"
echo "x y" > "$clone/.omarchy-greeter-stamp"   # pretend the stock lock changed
bad() { args=("$@"); setup env OMARCHY_GREETER_LOCK_UI="$REPO/lock:$REPO/theme" OMARCHY_GREETER_PATCH="$TMP/bad-patch.py"; }
check_not "failing patch reports failure" bad --at-login
check_not "clone removed without a shell" test -d "$clone"
check "failure remembered" test -s "$home/.config/omarchy-greeter/lock-failed"
: > "$notes"
bad --ensure; bad --ensure
equal "no repeated warnings" "" "$(cat "$notes")"

# Back to a working patch: --ensure sets it up again and forgets the failure.
check "recovers" run --ensure
check "clone back" test -d "$clone"
check_not "failure forgotten" test -e "$home/.config/omarchy-greeter/lock-failed"

# --verify: once the shell is up, the lock must answer, or the built-in one
# comes back. A stand-in shell: pings when $TMP/shell-up exists; the clone
# answers `lock owner` when $TMP/clone-loads exists; with the clone gone, the
# built-in lock answers `lock status`.
cat > "$fake/omarchy-shell" <<SH
#!/bin/bash
[[ -e $TMP/shell-up ]] || exit 1
case "\$*" in
  "shell ping") exit 0 ;;
  "lock owner") [[ -d "$clone" && -e $TMP/clone-loads ]] && { echo "omarchy-greeter 1"; exit 0; }; exit 1 ;;
  "lock status") [[ -d "$clone" ]] && exit 1; echo '{"locked":false}' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$fake/omarchy-shell"
verify() { args=(--verify); setup env VERIFY_INTERVAL=0 OMARCHY_GREETER_LOCK_UI="$REPO/lock:$REPO/theme" OMARCHY_GREETER_PATCH="$REPO/lib/patch-lock.py"; }
check "verify: no shell yet, nothing judged" verify
check "verify: clone kept without a shell" test -d "$clone"
touch "$TMP/shell-up" "$TMP/clone-loads"
check "verify: lock answers" verify
check "verify: clone kept" test -d "$clone"
rm -f "$TMP/clone-loads"; : > "$notes"
check_not "verify: lock does not load" verify
check_not "verify: clone removed" test -d "$clone"
check "verify: failure remembered" test -s "$home/.config/omarchy-greeter/lock-failed"
check "verify: told the built-in lock is back" grep -q "Omarchy's own lock screen is back" "$notes"
check "verify: not retried at login" run --at-login
check_not "verify: still on the built-in lock" test -d "$clone"
rm -f "$TMP/shell-up"
run >/dev/null   # explicit setup clears the failure and rebuilds

# Package removal: clone gone, shell.json cleaned, its mode kept.
printf '{"plugins":["omarchy.clock","%s.lock"],"disabledPlugins":["omarchy.lock"],"cloneSourceRestores":["%s.lock"]}\n' $me $me > "$home/.config/omarchy/shell.json"
chmod 644 "$home/.config/omarchy/shell.json"
check "uninstall" run --uninstall
check_not "clone removed" test -d "$clone"
equal "shell.json cleaned" '{"plugins":["omarchy.clock"],"disabledPlugins":[],"cloneSourceRestores":[]}' "$(jq -c . "$home/.config/omarchy/shell.json")"
equal "shell.json mode kept" "644" "$(stat -c %a "$home/.config/omarchy/shell.json")"

# Someone else's folder by that name is left alone.
mkdir -p "$clone" && echo "mine" > "$clone/Service.qml"
check_not "foreign clone refused" run --remove
equal "foreign clone untouched" "mine" "$(cat "$clone/Service.qml")"
finish
