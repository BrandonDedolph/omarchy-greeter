#!/bin/bash
# Release signatures: the shipped key file is usable, and verification
# accepts only the right key, namespace and bytes (same calls as
# scripts/release, scripts/install.sh and omarchy-greeter update).
source "$(dirname "$0")/lib.sh"
ns=omarchy-greeter-release
verify() { ssh-keygen -Y verify -f "$1" -I "$ns" -n "$ns" -s "$2" < "$3"; }

line=$(grep -v '^#' "$REPO/keys/allowed_signers" | head -n1)
check "shipped key line names the release principal and namespace" \
  grep -qE '^omarchy-greeter-release namespaces="omarchy-greeter-release" ssh-ed25519 [A-Za-z0-9+/=]+$' <<<"$line"

ssh-keygen -q -t ed25519 -N '' -f "$TMP/key" -C test
ssh-keygen -q -t ed25519 -N '' -f "$TMP/other" -C other
printf '%s namespaces="%s" %s\n' "$ns" "$ns" "$(cut -d' ' -f1,2 "$TMP/key.pub")" > "$TMP/signers"
echo "package bytes" > "$TMP/pkg"
ssh-keygen -q -Y sign -f "$TMP/key" -n "$ns" "$TMP/pkg" && mv "$TMP/pkg.sig" "$TMP/pkg.sshsig"
check "good signature" verify "$TMP/signers" "$TMP/pkg.sshsig" "$TMP/pkg"
# The release signs the package and install.sh in one run (one approval).
echo "a" > "$TMP/one"; echo "b" > "$TMP/two"
ssh-keygen -q -Y sign -f "$TMP/key" -n "$ns" "$TMP/one" "$TMP/two" && mv "$TMP/one.sig" "$TMP/one.sshsig" && mv "$TMP/two.sig" "$TMP/two.sshsig"
check "one run signs every file" verify "$TMP/signers" "$TMP/two.sshsig" "$TMP/two"
cp "$TMP/pkg" "$TMP/tampered" && echo x >> "$TMP/tampered"
check_not "tampered bytes" verify "$TMP/signers" "$TMP/pkg.sshsig" "$TMP/tampered"
ssh-keygen -q -Y sign -f "$TMP/other" -n "$ns" "$TMP/pkg" && mv "$TMP/pkg.sig" "$TMP/rogue.sshsig"
check_not "another key" verify "$TMP/signers" "$TMP/rogue.sshsig" "$TMP/pkg"
ssh-keygen -q -Y sign -f "$TMP/key" -n file "$TMP/pkg" && mv "$TMP/pkg.sig" "$TMP/ns.sshsig"
check_not "another namespace" verify "$TMP/signers" "$TMP/ns.sshsig" "$TMP/pkg"

# The installer has the key filled in only by scripts/release.
check "installer template has the placeholder" grep -q "^ALLOWED_SIGNERS='@ALLOWED_SIGNERS@'$" "$REPO/scripts/install.sh"
check_not "no .sig next to packages anywhere (pacman reads it as PGP)" \
  grep -nE '\$(file|pkg|name)\.sig\b|\.pkg\.tar\.zst\.sig\b' "$REPO/scripts/release" "$REPO/scripts/install.sh" "$REPO/bin/omarchy-greeter"
finish
