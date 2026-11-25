# Installs omarchy-greeter into $(DESTDIR). The PKGBUILD (and the AUR one
# scripts/release generates) call this, so the list of files lives in one place.
DESTDIR ?=

.PHONY: install check test

install:
	install -Dm755 bin/omarchy-greeter-sync "$(DESTDIR)/usr/bin/omarchy-greeter-sync"
	install -Dm755 bin/omarchy-greeter-lock-setup "$(DESTDIR)/usr/bin/omarchy-greeter-lock-setup"
	install -Dm755 bin/omarchy-greeter-guard "$(DESTDIR)/usr/bin/omarchy-greeter-guard"
	install -Dm755 bin/omarchy-greeter "$(DESTDIR)/usr/bin/omarchy-greeter"
	install -Dm644 systemd/user/omarchy-greeter-guard.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-guard.service"
	install -Dm644 systemd/user/omarchy-greeter-lock-check.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-lock-check.service"
	install -Dm644 systemd/user/omarchy-greeter-lock-update.service "$(DESTDIR)/usr/lib/systemd/user/omarchy-greeter-lock-update.service"
	install -Dm755 bin/omarchy-greeter-sessions "$(DESTDIR)/usr/bin/omarchy-greeter-sessions"
	install -Dm755 bin/omarchy-greeter-switch "$(DESTDIR)/usr/bin/omarchy-greeter-switch"
	install -Dm755 bin/omarchy-greeter-session-watch "$(DESTDIR)/usr/bin/omarchy-greeter-session-watch"
	install -Dm644 lib/patch-lock.py "$(DESTDIR)/usr/lib/omarchy-greeter/patch-lock.py"
	install -Dm644 lock/GreeterLockView.qml "$(DESTDIR)/usr/lib/omarchy-greeter/lock-ui/GreeterLockView.qml"
	for f in AccountForm AccountList PasswordBox FocusRing FormStyle UserAvatar; do \
		install -Dm644 "theme/$$f.qml" "$(DESTDIR)/usr/lib/omarchy-greeter/lock-ui/$$f.qml"; \
	done
	install -Dm755 lib/prepare-dirs "$(DESTDIR)/usr/lib/omarchy-greeter/prepare-dirs"
	install -Dm755 lib/publish-view "$(DESTDIR)/usr/lib/omarchy-greeter/publish-view"
	install -Dm644 systemd/system/omarchy-greeter-view@.service "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-view@.service"
	install -Dm644 systemd/system/omarchy-greeter-view@.path "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-view@.path"
	install -Dm644 systemd/system/omarchy-greeter-sessions.path "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-sessions.path"
	install -Dm644 systemd/system/omarchy-greeter-sessions.service "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-sessions.service"
	install -Dm755 lib/boot-unlock-mark "$(DESTDIR)/usr/lib/omarchy-greeter/boot-unlock-mark"
	install -Dm755 lib/boot-unlock-auth "$(DESTDIR)/usr/lib/omarchy-greeter/boot-unlock-auth"
	install -Dm644 systemd/system/omarchy-greeter-boot-unlock.service "$(DESTDIR)/usr/lib/systemd/system/omarchy-greeter-boot-unlock.service"
	install -Dm644 polkit/49-omarchy-greeter-self-admin.rules "$(DESTDIR)/usr/share/polkit-1/rules.d/49-omarchy-greeter-self-admin.rules"
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
	install -Dm644 keys/allowed_signers "$(DESTDIR)/usr/share/omarchy-greeter/allowed_signers"
	install -Dm644 LICENSE "$(DESTDIR)/usr/share/licenses/omarchy-greeter/LICENSE"

SHELL_SCRIPTS = bin/* lib/boot-unlock-mark lib/boot-unlock-auth lib/prepare-dirs hooks/post-update omarchy-greeter.install scripts/release scripts/install.sh tests/run tests/*.sh

# Static checks: syntax, shellcheck, QML.
check:
	bash -n $(SHELL_SCRIPTS)
	shellcheck -s bash $(SHELL_SCRIPTS)
	python3 -W error -c 'import ast,sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' lib/patch-lock.py lib/publish-view
	luac -p share/hyprland.lua
	! /usr/lib/qt6/bin/qmllint theme/*.qml lock/*.qml 2>&1 | grep -E '\[syntax\]'

# Behaviour tests, in temporary folders (never the real system).
# OMARCHY_LOCK_SOURCES: extra copies of Omarchy's lock plugin to patch.
test:
	tests/run
