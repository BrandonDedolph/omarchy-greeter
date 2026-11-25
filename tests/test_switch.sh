#!/bin/bash
# bin/omarchy-greeter-switch: an account signed in with its screen locked is
# switched to directly; anything else opens the login screen. Stand-ins for
# loginctl and busctl; nothing is switched.
source "$(dirname "$0")/lib.sh"
fake=$TMP/fake
calls=$TMP/calls
mkdir -p "$fake"
cat > "$fake/loginctl" <<S
#!/bin/bash
if [[ \$1 == list-sessions ]]; then cat "$TMP/sessions.json"; exit; fi
if [[ \$1 == show-session ]]; then cat "$TMP/props-\$2" 2>/dev/null || exit 1; exit; fi
exit 1
S
cat > "$fake/busctl" <<S
#!/bin/bash
echo "\$*" >> "$calls"
[[ \$* == *ActivateSession* && -e "$TMP/activate-fails" ]] && exit 1
exit 0
S
chmod +x "$fake/loginctl" "$fake/busctl"
switch() { : > "$calls"; LOGINCTL=$fake/loginctl BUSCTL=$fake/busctl "$REPO/bin/omarchy-greeter-switch" "$@"; cat "$calls"; }
activated() { grep -c 'ActivateSession s 7$' <<<"$1"; }
greeter() { grep -c 'SwitchToGreeter' <<<"$1"; }

cat > "$TMP/sessions.json" <<'J'
[{"session":"7","uid":1002,"user":"sam","seat":"seat0","class":"user","tty":"tty3"},
 {"session":"8","uid":1003,"user":"kim","seat":null,"class":"user","tty":"pts/1"}]
J
props() { printf 'Class=%s\nType=%s\nState=%s\nLockedHint=%s\n' "$@" > "$TMP/props-7"; }

props user wayland online yes
out=$(switch sam)
equal "signed in and locked: straight to its session" "1 0" "$(activated "$out") $(greeter "$out")"

props user wayland online no
out=$(switch sam)
equal "not locked: never revealed, login screen instead" "0 1" "$(activated "$out") $(greeter "$out")"

props user wayland closing yes
out=$(switch sam)
equal "closing session: login screen" "0 1" "$(activated "$out") $(greeter "$out")"

props user tty online yes
out=$(switch sam)
equal "text console session: login screen" "0 1" "$(activated "$out") $(greeter "$out")"

props greeter wayland online yes
out=$(switch sam)
equal "not a user session: login screen" "0 1" "$(activated "$out") $(greeter "$out")"

out=$(switch kim)
equal "remote session (no seat): login screen" "0 1" "$(activated "$out") $(greeter "$out")"

out=$(switch alex)
equal "not signed in: login screen" "0 1" "$(activated "$out") $(greeter "$out")"

props user wayland online yes
touch "$TMP/activate-fails"
out=$(switch sam)
equal "switch refused: login screen" "1 1" "$(activated "$out") $(greeter "$out")"
rm -f "$TMP/activate-fails"

out=$(switch 'sam;reboot')
equal "odd name: plain login screen" "0 1" "$(activated "$out") $(greeter "$out")"
out=$(switch)
equal "no account: login screen" "0 1" "$(activated "$out") $(greeter "$out")"
finish
