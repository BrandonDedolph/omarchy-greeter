# Installs omarchy-greeter into $(DESTDIR); both PKGBUILDs call this, so
# the list of files lives in one place.
DESTDIR ?=

.PHONY: install check

install:
	install -Dm755 bin/omarchy-greeter-sync "$(DESTDIR)/usr/bin/omarchy-greeter-sync"
	install -Dm755 bin/omarchy-greeter-lock-setup "$(DESTDIR)/usr/bin/omarchy-greeter-lock-setup"
	install -Dm755 bin/omarchy-greeter-presence "$(DESTDIR)/usr/bin/omarchy-greeter-presence"
	install -Dm644 systemd/user/omarchy-greeter-presence.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-presence.service"
	install -Dm755 bin/omarchy-greeter-guard "$(DESTDIR)/usr/bin/omarchy-greeter-guard"
	install -Dm755 bin/omarchy-greeter "$(DESTDIR)/usr/bin/omarchy-greeter"
	install -Dm644 systemd/user/omarchy-greeter-guard.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-guard.service"
	install -Dm644 systemd/user/omarchy-greeter-lock-update.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-lock-update.service"
	install -Dm755 bin/omarchy-greeter-sessions "$(DESTDIR)/usr/bin/omarchy-greeter-sessions"
	install -Dm755 bin/omarchy-greeter-switch "$(DESTDIR)/usr/bin/omarchy-greeter-switch"
	install -Dm755 bin/omarchy-greeter-session-watch "$(DESTDIR)/usr/bin/omarchy-greeter-session-watch"
	install -Dm644 lib/patch-lock.py "$(DESTDIR)/usr/lib/omarchy-greeter/patch-lock.py"
	install -Dm755 lib/prepare-dirs "$(DESTDIR)/usr/lib/omarchy-greeter/prepare-dirs"
	install -Dm755 lib/boot-unlock-mark "$(DESTDIR)/usr/lib/omarchy-greeter/boot-unlock-mark"
	install -Dm755 lib/boot-unlock-auth "$(DESTDIR)/usr/lib/omarchy-greeter/boot-unlock-auth"
	install -Dm644 systemd/system/omarchy-greeter-boot-unlock.service "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-boot-unlock.service"
	install -Dm644 polkit/40-omarchy-self-admin.rules "$(DESTDIR)/usr/share/polkit-1/rules.d/40-omarchy-self-admin.rules"
	install -Dm644 etc/omarchy-greeter.conf "$(DESTDIR)/etc/omarchy-greeter.conf"
	install -Dm644 share/hyprland.lua "$(DESTDIR)/usr/share/omarchy-greeter/hyprland.lua"
	install -Dm755 hooks/post-update "$(DESTDIR)/usr/share/omarchy-greeter/hooks/post-update"
	install -Dm644 systemd/system/omarchy-greeter-dirs.service "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-dirs.service"
	install -Dm644 systemd/user/omarchy-greeter-sync.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-sync.service"
	install -Dm644 systemd/user/omarchy-greeter-sync.path "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-sync.path"
	install -Dm644 sddm/zzz-omarchy-greeter.conf "$(DESTDIR)/etc/sddm.conf.d/zzz-omarchy-greeter.conf"
	for f in theme/*.qml theme/metadata.desktop theme/theme.conf; do \
		install -Dm644 "$$f" "$(DESTDIR)/usr/share/sddm/themes/omarchy-greeter/$$(basename "$$f")"; \
	done
	install -Dm644 LICENSE "$(DESTDIR)/usr/share/licenses/omarchy-greeter/LICENSE"

# Syntax checks for the scripts and QML.
check:
	bash -n bin/* lib/boot-unlock-mark lib/boot-unlock-auth lib/prepare-dirs hooks/post-update omarchy-greeter.install
	python3 -m py_compile lib/patch-lock.py
	! /usr/lib/qt6/bin/qmllint theme/*.qml 2>&1 | grep -E '\[syntax\]'
