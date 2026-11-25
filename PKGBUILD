# Development build from this working tree: makepkg -si
# Releases are built from aur/PKGBUILD (a tagged GitHub release).
pkgname=omarchy-greeter
pkgver=3.0.0
pkgrel=1
pkgdesc="Multi-user Omarchy login screen that follows each user's background, theme and display scale"
url="https://github.com/BrandonDedolph/omarchy-greeter"
arch=(any)
license=(MIT)
# omarchy: omarchy-shell, the plugin and menu commands, /usr/share/sddm/hyprland.lua
depends=('omarchy>=4.5' hyprland sddm qt6-declarative qt6-multimedia imagemagick ffmpeg jq
         cryptsetup util-linux glib2 python gum polkit libnotify fontconfig sudo
         curl openssh libarchive pacman)
backup=(etc/omarchy-greeter.conf)
install=omarchy-greeter.install
source=()

package() {
  make -C "$startdir" DESTDIR="$pkgdir" install
}
