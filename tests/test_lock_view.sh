#!/bin/bash
# The lock layout, built by lib/patch-lock.py and run off-screen with
# stand-ins for Omarchy's style modules (tests/lock_harness): ours loads,
# values and signals pass through the generated LockView.qml, and a layout
# that fails to load falls back to Omarchy's.
source "$(dirname "$0")/lib.sh"
stock=/usr/share/omarchy/shell/plugins/lock
qml=/usr/lib/qt6/bin/qml
for source in "$stock" ${OMARCHY_LOCK_SOURCES//:/ }; do
  [[ -f $source/LockView.qml ]] && break
  source=""
done
[[ -n $source ]] || { echo "  skipped: no Omarchy lock plugin (set OMARCHY_LOCK_SOURCES)"; finish; exit; }
[[ -x $qml ]] || { echo "  skipped: no $qml"; finish; exit; }

build() {
  rm -rf "$TMP/lock" && cp -r "$source/." "$TMP/lock/" &&
    python3 -I "$REPO/lib/patch-lock.py" "$TMP/lock" "omarchy-greeter:primary-lock" "$REPO/lock" "$REPO/theme" &&
    cp "$REPO/tests/lock_harness/main.qml" "$TMP/lock/"
}
show() {
  (cd "$TMP/lock" && QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 60 \
    "$qml" -I "$REPO/tests/lock_harness" main.qml -- "$@" 2>&1) | sed -n 's/^qml: harness: //p'
}

check "builds" build
out=$(show "${LOCK_SHOT:-none}")
equal "our layout loads" "GreeterLockView.qml" "$(sed -n 's/^layout=//p' <<<"$out")"
equal "password passes in" "abc" "$(sed -n 's/^into-layout=//p' <<<"$out")"
equal "every account listed" "3" "$(sed -n 's/^rows=//p' <<<"$out")"
equal "form hidden while handing off" "false" "$(sed -n 's/^handoff-form=//p' <<<"$out")"
equal "form back after" "true" "$(sed -n 's/^after-form=//p' <<<"$out")"
equal "typing, submit and switch pass out" "edited:abcd,edited:,submit:abcd,switch:sam" "$(sed -n 's/^events=//p' <<<"$out")"

# A layout that does not load: Omarchy's (here a stand-in that only needs
# QtQuick) shows instead.
check "builds again" build
printf 'import QtQuick\nNoSuchType {}\n' > "$TMP/lock/GreeterLockView.qml"
printf 'import QtQuick\nItem {\n  property string passwordText: ""\n  signal submitPassword(string password)\n}\n' > "$TMP/lock/StockLockView.qml"
out=$(show none)
equal "falls back to Omarchy's layout" "StockLockView.qml" "$(sed -n 's/^layout=//p' <<<"$out")"
finish
