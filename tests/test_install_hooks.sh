#!/bin/bash
# omarchy-greeter.install: the PAM edits, on a copy of a stock sddm PAM file.
source "$(dirname "$0")/lib.sh"
# shellcheck source=omarchy-greeter.install
source "$REPO/omarchy-greeter.install"
chown() { :; }   # the real one needs root
PAM_FILE=$TMP/sddm
cat > "$PAM_FILE" <<'PAM'
#%PAM-1.0

auth        include     system-login
-auth       optional    pam_kwallet5.so

account     include     system-login

password    include     system-login

session     optional    pam_keyinit.so          force revoke
session     include     system-login
PAM
original=$(cat "$PAM_FILE")

add_pam_line
equal "auth line first" "$PAM_LINE" "$(grep -m1 '^-\?auth' "$PAM_FILE")"
equal "session line last" "$SESSION_LINE" "$(tail -n1 "$PAM_FILE")"
equal "mode" "644" "$(stat -c %a "$PAM_FILE")"
once=$(cat "$PAM_FILE")
add_pam_line
equal "adding twice changes nothing" "$once" "$(cat "$PAM_FILE")"
# An upgrade from a version that only had the auth line gets the session line.
grep -v 'session.*boot-unlock-auth' "$PAM_FILE" > "$TMP/old" && cp "$TMP/old" "$PAM_FILE"
add_pam_line
equal "upgrade adds the session line" "$once" "$(cat "$PAM_FILE")"
equal "no temp files left" "sddm" "$(cd "$TMP" && ls sddm* | paste -sd' ')"
remove_pam_line
equal "removal restores the file" "$original" "$(cat "$PAM_FILE")"
PAM_FILE=$TMP/missing
check "no PAM file: nothing to do" add_pam_line
check_not "and nothing created" test -e "$TMP/missing"
finish
