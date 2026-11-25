#!/bin/bash
# Install the latest omarchy-greeter release on an Omarchy machine.
#
#   curl -fsSL https://github.com/BrandonDedolph/omarchy-greeter/releases/latest/download/install.sh | bash
#
# Downloads the package from the latest GitHub release, checks its signature
# against the release key below, and installs it with pacman (asks for your
# password). Nothing is installed if the signature does not verify.

set -euo pipefail

REPO=BrandonDedolph/omarchy-greeter
# The project's release signing key (also shipped in the package, which uses
# it to verify later updates).
ALLOWED_SIGNERS='@ALLOWED_SIGNERS@'

die() { echo "omarchy-greeter install: $*" >&2; exit 1; }

command -v pacman >/dev/null || die "this needs an Arch-based system (pacman)"
[[ -d /usr/share/omarchy || -n ${OMARCHY_PATH:-} ]] || die "Omarchy does not seem to be installed"
for tool in curl jq ssh-keygen bsdtar; do
  command -v "$tool" >/dev/null || die "missing $tool"
done
[[ $ALLOWED_SIGNERS == omarchy-greeter-release* ]] || die "this installer has no release key; download it from the releases page"

json=$(curl -fsSL --proto '=https' --max-time 20 -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/releases/latest") || die "could not reach GitHub"
tag=$(jq -r .tag_name <<<"$json")
name=$(jq -r '[.assets[].name | select(test("^omarchy-greeter-[0-9][0-9.]*-[0-9]+-any\\.pkg\\.tar\\.zst$"))][0] // empty' <<<"$json")
[[ $tag =~ ^v[0-9.]+$ && -n $name ]] || die "the latest release has no package"
version=${name#omarchy-greeter-}
version=${version%-any.pkg.tar.zst}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
file="$work/$name"
echo "Downloading omarchy-greeter $version"
curl -fsSL --proto '=https' --max-time 300 -o "$file" "https://github.com/$REPO/releases/download/$tag/$name"
# .sshsig, not .sig: pacman would take a <package>.sig beside the package
# for a PGP signature and refuse it.
curl -fsSL --proto '=https' --max-time 60 -o "$work/signature.sshsig" "https://github.com/$REPO/releases/download/$tag/$name.sshsig"

printf '%s\n' "$ALLOWED_SIGNERS" > "$work/allowed_signers"
ssh-keygen -Y verify -f "$work/allowed_signers" -I omarchy-greeter-release -n omarchy-greeter-release \
  -s "$work/signature.sshsig" < "$file" >/dev/null 2>&1 || die "the package signature does not verify; not installing"
info=$(bsdtar -xOf "$file" .PKGINFO)
[[ $(sed -n 's/^pkgname = //p' <<<"$info") == "omarchy-greeter" && $(sed -n 's/^pkgver = //p' <<<"$info") == "$version" ]] ||
  die "the signed package is not omarchy-greeter $version; not installing"
echo "Signature verified."

# The terminal, not the pipe this script arrived on, answers sudo. Without
# a terminal (run from a launcher or another program), Omarchy's password
# dialog asks instead.
if (exec 3</dev/tty) 2>/dev/null; then
  # shellcheck disable=SC2024
  sudo pacman -U --noconfirm "$file" < /dev/tty
elif command -v pkexec >/dev/null; then
  pkexec pacman -U --noconfirm "$file"
else
  die "no terminal to ask for your password; run this in a terminal"
fi
cat <<'EOF'

omarchy-greeter is installed. Log out (or reboot) to see the new login screen.
After your next login, find its settings in the Omarchy menu under Setup > Login & Lock,
or run: omarchy-greeter status
EOF
