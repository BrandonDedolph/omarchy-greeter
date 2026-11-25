# omarchy-greeter

A multi-user login screen and lock screen for [Omarchy](https://omarchy.org). For computers that more than one person uses, or one person with separate accounts (work and personal, say).

- **Each account looks like its own desktop.** The login screen shows the selected account's Omarchy background (video included) and colors itself from that account's theme. Switching accounts wipes to the next background with the same reveal the desktop uses.
- **Sized like the desktop.** Each account's monitor scale and Omarchy font size carry over to the login screen.
- **Knows who is signed in.** Accounts with a session running read **Locked · resumes session**; the rest read **Log in**.
- **Multi-user lock screen.** The lock shows who it belongs to, who else is signed in, and **Switch user**, which opens the login screen while your session stays locked. Coming back takes one password.
- **One monitor.** Optionally show the login and lock forms on one monitor only and keep the rest black.
- **One password at boot.** On an encrypted disk, the disk password can also log you in once, so you type one password instead of two (see [security](#one-password-at-boot)).
- **Settings in the Omarchy menu**, under **Setup > Login & Lock**, plus an `omarchy-greeter` command for the same and for managing accounts.

| Tokyo Night account | Catppuccin Latte account, signed in | Gruvbox account |
|---|---|---|
| ![Login screen for an account with the Tokyo Night theme](docs/screenshots/login-alex.jpg) | ![Login screen for a signed-in account with the Catppuccin Latte theme, showing Locked · resumes session](docs/screenshots/login-sam-locked.jpg) | ![Login screen for an account with the Gruvbox theme](docs/screenshots/login-jordan.jpg) |

<img src="docs/screenshots/menu.png" alt="Setup > Login & Lock in the Omarchy menu" width="276" align="right">

## Requirements

- Omarchy 4.5 or newer (Hyprland with the Lua config, the Quickshell desktop, SDDM, the uwsm session). These are all Omarchy defaults.
- An Arch-based Omarchy install (it is packaged with `makepkg`).

## Install

From the [AUR](https://aur.archlinux.org/packages/omarchy-greeter):

```bash
omarchy pkg aur add omarchy-greeter
```

(or `yay -S omarchy-greeter`). To build from source instead: `git clone https://github.com/BrandonDedolph/omarchy-greeter.git && cd omarchy-greeter && makepkg -si`.

Then log out once (or reboot). At your next login the package:

- publishes your look for the login screen;
- switches you to the multi-user lock screen (a one-time desktop reload);
- adds **Setup > Login & Lock** to your Omarchy menu.

Every other account gets the same at its own first login. The login screen reads every account's look at boot, so an account shows its own theme even when it is not signed in (a brand-new account shows the default look until its first login).

To pick the monitor for the login and lock forms, open **Setup > Login & Lock > Monitor > This One** on the monitor you want, or run `omarchy-greeter monitor focused`.

## Updates

Installed from the AUR, omarchy-greeter updates along with everything else when you run `omarchy update` (or `yay`). To see whether an update is waiting: `yay -Qua`. Releases and their notes are on the [releases page](https://github.com/BrandonDedolph/omarchy-greeter/releases).

An update takes effect at your next login; it never reloads your desktop in the middle of your work.

## Adding another person

From the Omarchy menu: **Setup > Login & Lock > Accounts > Add**. Or in a terminal:

```bash
omarchy-greeter user add
```

It asks for the account name, the name to show on the login screen, whether the account should be an admin, and a password. The new account starts from Omarchy's defaults (`/etc/skel`), and Omarchy finishes setting it up at its first login. To sign in as it, lock your screen (<kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>L</kbd>), choose **Switch user**, and pick it.

## Admin rights

An admin can use `sudo`, install software and change system settings. Each admin is asked for **their own** password in system dialogs, not for the first admin's.

```bash
omarchy-greeter user list                 # every account and whether it is an admin
omarchy-greeter user admin alex on        # give alex admin rights
omarchy-greeter user admin alex off       # take them away
```

Or from the menu: **Setup > Login & Lock > Accounts > Admin**. Changes take effect at that account's next login. The last remaining admin cannot be removed, so the computer always has one.

## Settings

Every feature can be switched on or off. Machine-wide settings ask for an admin password; personal ones affect only your account.

| Setting | Menu (Setup > Login & Lock) | Command | Scope | Default |
|---|---|---|---|---|
| Monitor for the login and lock forms | Monitor | `omarchy-greeter monitor [focused\|all\|<name>]` | machine | all monitors |
| One password at boot | Boot Login | `omarchy-greeter boot-pass [on\|off]` | machine | on |
| Multi-user lock screen | User Lock | `omarchy-greeter lock [on\|off]` | you | on |
| Your look on the login screen | My Look | `omarchy-greeter publish [on\|off]` | you | on |
| The menu entries | (remove them) | `omarchy-greeter menu [install\|remove]` | you | on |

`omarchy-greeter status` shows them all. The machine-wide settings live in `/etc/omarchy-greeter.conf`.

With **My Look** off, the login screen shows the default look for your account. With **User Lock** off, you get Omarchy's own lock screen back.

## Remove

```bash
sudo pacman -R omarchy-greeter
```

This puts back Omarchy's login screen and, for every account, Omarchy's lock screen. It also removes the menu entries and the PAM line, and deletes the published looks in `/var/lib/omarchy-greeter`. Log out and back in afterwards so a running desktop switches to Omarchy's lock. If the login screen ever fails to come up, switch to a text console (<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd>), log in, and run the same command.

## One password at boot

With Omarchy's full-disk encryption you type the disk password at boot and then an account password. With this on, a disk password typed at boot also lets the **first** login skip the account password:

- only if `/` is on LUKS with no TPM or FIDO2 token and no key file (on the kernel command line, in `/etc/crypttab.initramfs` or bundled into the initramfs), so a typed passphrase was the only way the disk could have opened;
- only for a fresh boot (not a soft-reboot), once, and within 10 minutes of boot;
- only to **start** an account that is not signed in. Returning to a signed-in (locked) session always takes that account's password.

Every use is logged to the journal (`journalctl -t omarchy-greeter`). This is the same trust Omarchy's own encrypted-disk autologin places in the disk password, narrowed to one login and letting you pick the account. If anything about the disk setup does not match, it stays off silently and you type your password as usual. Turn it off with `omarchy-greeter boot-pass off`.

## How it works

- **The login screen** is an SDDM theme (`theme/`). SDDM runs it as the `sddm` user, who cannot read home folders. So each account publishes its look (a screen-sized still of its background, theme colors, font size, monitor layout, avatar from `~/.face`) to `/var/lib/omarchy-greeter/<account>/`. This happens from a systemd user unit whenever the theme, background, monitors or font change, and at boot for every account (`omarchy-greeter-sync`).
- **The login screen's compositor** uses the same monitor modes as the desktop and stays in SDR, so moving between them causes no monitor blackout.
- **The lock screen** is Omarchy's own lock plugin, cloned into `~/.config/omarchy/plugins/<account>.lock` and patched (`lib/patch-lock.py`). The clone is rebuilt from Omarchy's current lock before the desktop starts whenever Omarchy's lock or the patch changes, so Omarchy's lock fixes keep arriving. If an Omarchy update ever changes the lock so much that the patch no longer fits, you get Omarchy's own lock and a notification. Nothing breaks.
- **A session out of sight is always locked.** If another account or the login screen comes to the front while a session is unlocked, that session locks itself (`omarchy-greeter-guard`, which works with either lock screen).
- **Switching back takes one password.** When you log back into your locked session from the login screen, SDDM asks logind to unlock it, and the lock screen follows once your session is in front again.

## Development

Test the login screen without logging out:

```bash
QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 \
  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/omarchy-greeter
```

`make check` runs the syntax checks.

To release a version (maintainers): `scripts/release 3.1.0`. It checks the tree, tags `v3.1.0`, creates the GitHub release, builds and test-installs the AUR package from that release, and pushes it to the AUR, after which users get it through `omarchy update`.

For screenshots without real account names, add `demoUsers=alex:Alex Rivera,sam:Sam Chen` (and optionally `demoHost=`) to a copy of `theme.conf`, with `dataDir=` pointing at sample looks.

## License

MIT
