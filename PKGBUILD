# Local package: build with `makepkg -si` from this folder.
pkgname=omarchy-greeter
pkgver=2.5.1
pkgrel=1
pkgdesc="Multi-user Omarchy login screen that follows each user's background, theme and display scale"
arch=(any)
license=(MIT)
depends=(sddm qt6-declarative qt6-multimedia imagemagick ffmpeg jq cryptsetup util-linux glib2 python)
backup=(etc/omarchy-greeter.conf)
install=omarchy-greeter.install
source=()

package() {
  cd "$startdir"
  install -Dm755 bin/omarchy-greeter-sync "$pkgdir/usr/bin/omarchy-greeter-sync"
  install -Dm755 bin/omarchy-greeter-lock-setup "$pkgdir/usr/bin/omarchy-greeter-lock-setup"
  install -Dm755 bin/omarchy-greeter-presence "$pkgdir/usr/bin/omarchy-greeter-presence"
  install -Dm644 systemd/user/omarchy-greeter-presence.service "$pkgdir/usr/lib/systemd/user/omarchy-greeter-presence.service"
  install -Dm755 bin/omarchy-greeter-guard "$pkgdir/usr/bin/omarchy-greeter-guard"
  install -Dm644 systemd/user/omarchy-greeter-guard.service "$pkgdir/usr/lib/systemd/user/omarchy-greeter-guard.service"
  install -Dm755 bin/omarchy-greeter-sessions "$pkgdir/usr/bin/omarchy-greeter-sessions"
  install -Dm755 bin/omarchy-greeter-switch "$pkgdir/usr/bin/omarchy-greeter-switch"
  install -Dm755 bin/omarchy-greeter-session-watch "$pkgdir/usr/bin/omarchy-greeter-session-watch"
  install -Dm644 lib/patch-lock.py "$pkgdir/usr/lib/omarchy-greeter/patch-lock.py"
  install -Dm755 lib/prepare-dirs "$pkgdir/usr/lib/omarchy-greeter/prepare-dirs"
  install -Dm755 lib/boot-unlock-mark "$pkgdir/usr/lib/omarchy-greeter/boot-unlock-mark"
  install -Dm755 lib/boot-unlock-auth "$pkgdir/usr/lib/omarchy-greeter/boot-unlock-auth"
  install -Dm644 systemd/system/omarchy-greeter-boot-unlock.service "$pkgdir/usr/lib/systemd/system/omarchy-greeter-boot-unlock.service"
  install -Dm644 polkit/40-omarchy-self-admin.rules "$pkgdir/usr/share/polkit-1/rules.d/40-omarchy-self-admin.rules"
  install -Dm644 etc/omarchy-greeter.conf "$pkgdir/etc/omarchy-greeter.conf"
  install -Dm644 share/hyprland.lua "$pkgdir/usr/share/omarchy-greeter/hyprland.lua"
  install -Dm755 hooks/post-update "$pkgdir/usr/share/omarchy-greeter/hooks/post-update"
  install -Dm644 systemd/system/omarchy-greeter-dirs.service "$pkgdir/usr/lib/systemd/system/omarchy-greeter-dirs.service"
  install -Dm644 systemd/user/omarchy-greeter-sync.service "$pkgdir/usr/lib/systemd/user/omarchy-greeter-sync.service"
  install -Dm644 systemd/user/omarchy-greeter-sync.path "$pkgdir/usr/lib/systemd/user/omarchy-greeter-sync.path"
  install -Dm644 sddm/zzz-omarchy-greeter.conf "$pkgdir/etc/sddm.conf.d/zzz-omarchy-greeter.conf"
  for f in theme/*.qml theme/metadata.desktop theme/theme.conf; do
    install -Dm644 "$f" "$pkgdir/usr/share/sddm/themes/omarchy-greeter/$(basename "$f")"
  done
}
