# Changelog

What changed in each release, for the people using it. Newest first.

## Unreleased

### Lock screen and login screen, like Windows

- **The lock screen is now where you sign back in.** It looks the same as
  the login screen: your account in the middle, every account in the
  bottom-left (with "Signed in" next to the ones that are), the computer's
  name top-left, and Sleep, Restart and Shut down bottom-right. Pick another
  account to open the login screen with it selected; your session stays
  locked and running.
- **New look for the login screen:** the selected account centered, every
  account listed bottom-left, and your blurred wallpaper behind it.
- **Shows who is signed in** using the system's own session list, so it is
  always right (it used to miss accounts that were signed in).
- **The login screen appears in one step** instead of fading and re-sizing
  as it loads. Opened through "switch user", it shows up at once.
- **Clearer keyboard focus:** a bright ring shows what Tab has reached.
  Tab moves through the password box, the accounts and the power buttons.
  Enter or Space picks.
- **Password dots sit centered** in the password box.
- **The login screen turns the displays off** after 2 minutes without
  typing. Change it with `omarchy-greeter screen-off <seconds>` (0: never).
- If anything in the new lock screen fails to load, Omarchy's own lock
  screen shows instead, so you are never left unlocked.

### Behind the scenes

- Your background is blurred once, when you change it, instead of on every
  screen draw. That fixes faint lines, rings and bands some screens showed.
- Releases are signed with one approval instead of one per file.

## 1.0.2 (2026-11-25)

- **Fixed:** faint rings and bands behind the login form on 4K screens.
- **Safer lock screen:** if the multi-user lock screen ever fails to start,
  Omarchy's own lock screen comes back automatically and you get a
  notification.
- **"Signed in" is now reliable:** it comes from the system's session list
  rather than a note each session leaves behind.

## 1.0.1 (2026-11-25)

- **Installing sets everything up at once:** the menu entries and the update
  hook appear for every account, without logging out first.
- **The installer works without a terminal,** asking for your password with
  the usual dialog.
- `omarchy-greeter --version`; `omarchy-greeter status` no longer lists the
  boot-password accounts twice.
- Settings files keep their permissions when rewritten.
- A security policy (SECURITY.md) for reporting problems privately.

## 1.0.0 (2026-11-25)

First release.

- **A login screen for every account on the machine** that follows each
  person's own Omarchy look: theme colors, background, font size and
  monitor layout.
- **A lock screen that knows about the other accounts:** see who else is
  signed in, and switch user without signing out.
- **One password at boot (optional):** after you type the disk password, the
  first login can skip the account password, for the accounts you choose.
- **Login and lock on one monitor** of your choice; the others stay black.
- **Settings in the Omarchy menu** (Setup > Login & Lock), or with the
  `omarchy-greeter` command: monitor, boot password, video backgrounds,
  your look on the login screen, adding accounts and admin rights.
- **Admin prompts ask each admin for their own password.**
- **Signed updates** through `omarchy update`.
