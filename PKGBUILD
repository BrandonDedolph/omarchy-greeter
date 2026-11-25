# Development build from this working tree: makepkg -si
# Releases are built from aur/PKGBUILD (a tagged GitHub release).
pkgname=omarchy-greeter
pkgver=3.0.0
pkgrel=1
pkgdesc="Multi-user Omarchy login screen that follows each user's background, theme and display scale"
url="https://github.com/BrandonDedolph/omarchy-greeter"
arch=(any)
license=(MIT)
depends=(sddm qt6-declarative qt6-multimedia imagemagick ffmpeg jq cryptsetup util-linux glib2 python gum polkit)
backup=(etc/omarchy-greeter.conf)
install=omarchy-greeter.install
source=()

package() {
  make -C "$startdir" DESTDIR="$pkgdir" install
}
