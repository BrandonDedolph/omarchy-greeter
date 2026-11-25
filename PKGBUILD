# Local package: build with `makepkg -si` from this folder.
pkgname=omarchy-greeter
pkgver=2.0.0
pkgrel=1
pkgdesc="Multi-user Omarchy login screen that follows each user's background, theme and display scale"
arch=(any)
license=(MIT)
depends=(sddm qt6-declarative qt6-multimedia imagemagick ffmpeg jq)
install=omarchy-greeter.install
source=()

package() {
  cd "$startdir"
  install -Dm755 bin/omarchy-greeter-sync "$pkgdir/usr/bin/omarchy-greeter-sync"
  install -Dm755 lib/prepare-dirs "$pkgdir/usr/lib/omarchy-greeter/prepare-dirs"
  install -Dm644 systemd/system/omarchy-greeter-dirs.service "$pkgdir/usr/lib/systemd/system/omarchy-greeter-dirs.service"
  install -Dm644 systemd/user/omarchy-greeter-sync.service "$pkgdir/usr/lib/systemd/user/omarchy-greeter-sync.service"
  install -Dm644 systemd/user/omarchy-greeter-sync.path "$pkgdir/usr/lib/systemd/user/omarchy-greeter-sync.path"
  install -Dm644 sddm/zzz-omarchy-greeter.conf "$pkgdir/etc/sddm.conf.d/zzz-omarchy-greeter.conf"
  for f in theme/*.qml theme/metadata.desktop theme/theme.conf; do
    install -Dm644 "$f" "$pkgdir/usr/share/sddm/themes/omarchy-greeter/$(basename "$f")"
  done
}
