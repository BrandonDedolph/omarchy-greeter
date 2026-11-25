#!/bin/bash
# lib/boot-unlock-auth refuses everything without the root-owned boot mark
# (which a test cannot create in /run), whatever PAM says. The positive
# path is exercised on a real boot.
source "$(dirname "$0")/lib.sh"
auth() { env -i PATH=/usr/bin "$@" bash "$REPO/lib/boot-unlock-auth"; }
[[ -e /run/omarchy-greeter/boot-unlocked ]] && { echo "  skipped: a real boot mark is armed"; finish; exit; }
check_not "no mark" auth PAM_TYPE=auth PAM_SERVICE=sddm PAM_USER="$(id -un)"
check_not "other PAM service" auth PAM_TYPE=auth PAM_SERVICE=login PAM_USER="$(id -un)"
check_not "sddm-autologin" auth PAM_TYPE=auth PAM_SERVICE=sddm-autologin PAM_USER="$(id -un)"
check_not "no user" auth PAM_TYPE=auth PAM_SERVICE=sddm
check_not "odd user name" auth PAM_TYPE=auth PAM_SERVICE=sddm PAM_USER='../root'
check_not "nothing set" auth
check "session open always succeeds" auth PAM_TYPE=open_session PAM_SERVICE=sddm PAM_USER="$(id -un)"
check "session close ignored" auth PAM_TYPE=close_session PAM_SERVICE=sddm PAM_USER="$(id -un)"
finish
