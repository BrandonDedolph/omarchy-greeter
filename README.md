# omarchy-greeter

Multi-user SDDM login screen for Omarchy. Grew out of the `omarchy-mu` theme
(stock Omarchy login + Tab to switch user).

- Shows the selected user's own Omarchy background, video included, and
  colors the whole screen from their theme.
- Switching users (Tab / ↑↓ / click an avatar) wipes to the next background
  with the same slanted reveal the desktop uses; colors cross-fade.
- Sized to match each user's desktop: their monitor scale per connector and
  their Omarchy shell font and base size.
- Monitors stay in step on which user is selected.
- Primary monitor only (`primary=` in `/etc/omarchy-greeter.conf`): the
  login screen and the lock screen show on that monitor, the rest stay black.
  The greeter compositor keeps keyboard focus there; the lock's black screens
  still pass typing to the password. Falls back to every monitor if the
  primary is unplugged.
- One password at boot (`boot_unlock=yes`): after the disk password is typed,
  the first login skips the account password. See below.
- Clock, avatars (`~/.face` or initials), Caps Lock warning, wrong-password
  shake, progress while logging in, sleep/restart/shut down.

## How it works

The greeter runs as `sddm` and cannot read home folders. Each user's
`omarchy-greeter-sync.path` unit watches `~/.local/state/omarchy/current`,
`~/.config/hypr`, `~/.config/omarchy/shell.toml` and `~/.face`, and
`omarchy-greeter-sync` publishes a screen-sized still (plus the video, if
any), `colors.toml`, `display.json` and the avatar to
`/var/lib/omarchy-greeter/<user>/` (owned by that user, world-readable).
`omarchy-greeter-dirs.service` creates those folders at boot.

## Install / remove

    makepkg -si          # install
    sudo pacman -R omarchy-greeter   # back to the stock Omarchy login

## Test without logging out

    QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 \
      sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/omarchy-greeter

## One password at boot

`omarchy-greeter-boot-unlock.service` runs before SDDM and leaves a mark in
`/run/omarchy-greeter/boot-unlocked` only if `/` is on LUKS with no TPM/FIDO
token and no key file (so a typed passphrase is the only way it unlocked) and
the kernel booted under 5 minutes ago (not a soft-reboot). A `pam_exec` line
at the top of `/etc/pam.d/sddm` (`boot-unlock-auth`) lets exactly one login
through while that mark exists, deletes it, and logs it to the journal. The
mark also expires 10 minutes after boot. Otherwise PAM falls through to the
normal password check. Same trust as Omarchy's own encrypted-disk autologin,
but one use, time-boxed, and you pick the account.

If you ever enroll a TPM or FIDO key for the disk, the mark stops being made
automatically. Set `boot_unlock=no` to turn it off.

## Lock screen: who is signed in, switching user

The lock shows your avatar and name with a **Locked** label, chips for other
accounts that are signed in, and **Switch user**. Switching opens the login
screen on a new console (SDDM `SwitchToGreeter`) while your session stays
locked, preselecting the account you clicked. On the login screen each
account reads **Locked · resumes session** (it has a session running, via
`omarchy-greeter-presence`) or **Log in**. Logging back into a locked session
unlocks it in one step when SDDM tells logind to (`omarchy-greeter-session-watch`).

## Lock screen on the primary monitor

`omarchy-greeter-lock-setup` clones Omarchy's lock plugin and patches it; the
sync service runs it once per user (`--ensure`). A post-update hook re-clones
after each `omarchy update` so Omarchy's lock fixes are not lost; if the patch
no longer fits, it falls back to the built-in lock. `--remove` reverts.
