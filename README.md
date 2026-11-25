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
