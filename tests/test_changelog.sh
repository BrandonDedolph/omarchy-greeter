#!/bin/bash
# CHANGELOG.md: every released version has its own section (the release
# notes come from it), and there is a place for the next one.
source "$(dirname "$0")/lib.sh"
log=$REPO/CHANGELOG.md
check "an Unreleased section or the current version's" \
  grep -qE "^## (Unreleased|$(sed -n 's/^pkgver=//p' "$REPO/PKGBUILD"))( |$)" "$log"
for tag in $(git -C "$REPO" tag -l 'v[0-9]*' 2>/dev/null); do
  check "notes for $tag" grep -qE "^## ${tag#v} \(" "$log"
done
check_not "no duplicate versions" bash -c "grep '^## ' '$log' | sort | uniq -d | grep -q ."
finish
