"""Patch a fresh clone of Omarchy's lock plugin (omarchy.lock).

Omarchy's lock logic (Service.qml) gets small additions, by exact-text
anchors:
  - the form shows only on the primary monitor (/etc/omarchy-greeter.conf),
    other monitors black but still passing typing through;
  - who is signed in, and every account (for the account list);
  - switching user: opens the login screen while this session stays locked;
  - unlocks when logind says so (SDDM does when you log back into this
    session from the login screen), so switching back takes one password;
  - a session out of sight never unlocks, blanks or holds the reader.

The layout is not patched: it is replaced. Omarchy's LockView.qml is kept,
untouched, as StockLockView.qml; our layout (GreeterLockView.qml and the
form it shares with the login screen) is copied in; and a generated
LockView.qml declares every property and signal Omarchy's layout declares
(so whatever the lock logic passes in, it loads), loads ours, and falls back
to StockLockView.qml if ours does not load.

Every anchor must match exactly once, or nothing is written and the caller
falls back to the built-in lock.

usage: patch-lock.py <clone-dir> <marker> <ui-dir>...
  ui-dir: folders holding GreeterLockView.qml and the shared form files
"""
import re
import sys
from pathlib import Path

clone, mark, ui_dirs = Path(sys.argv[1]), sys.argv[2], [Path(d) for d in sys.argv[3:]]
files = {name: (clone / name).read_text() for name in ("Service.qml", "LockView.qml")}
stock_view = files["LockView.qml"]


def rep(name, old, new):
    text = files[name]
    if text.count(old) != 1:
        raise SystemExit(f"{name}: anchor not found exactly once: {old.strip()[:70]!r}")
    files[name] = text.replace(old, new)


# ---------------------------------------------------------------- Service.qml

# Lets omarchy-greeter-lock-setup confirm this copy, not the built-in, is the
# one answering `omarchy-shell lock ...` after it reloads the lock.
rep("Service.qml", '''    function isLocked(): string {
''', '''    // "omarchy-greeter <when this instance started>": tells a freshly
    // loaded lock from the one it replaced.
    function owner(): string {
      return "omarchy-greeter " + root.shellStartedAt
    }

    function isLocked(): string {
''')

# A lock out of sight (another console is in front) must not unlock (only a
# deferred logind unlock may, once back in front), hold the fingerprint
# reader or switch hardware off.
rep("Service.qml", '''  function finishUnlock() {
    if (!root.currentlyLocked()) return
''', '''  function finishUnlock() {
    if (!root.currentlyLocked()) return
    if (!root.sessionActive) {
      logEvent("unlock refused: session in the background")
      return
    }
''')
rep("Service.qml", '''  function runBlank() {
''', '''  function runBlank() {
    if (!root.sessionActive) return
''')
rep("Service.qml", '''  function startFingerprint() {
    if (!lockRequested ''', '''  function startFingerprint() {
    if (!root.sessionActive) return
    if (!lockRequested ''')

rep("Service.qml", '''  property string pendingPassword: ""
''', '''  property string pendingPassword: ""

  // ''' + mark + ''': the lock form shows only on the primary monitor
  // from /etc/omarchy-greeter.conf; the others are black. If that monitor
  // is not connected, every monitor shows the form.
  FileView {
    id: greeterSettings
    path: "/etc/omarchy-greeter.conf"
    blockLoading: true
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
  }
  readonly property string primaryOutput: {
    var m = String(greeterSettings.text() || "").match(/^\\s*primary\\s*=\\s*([A-Za-z0-9_.-]*)/m)
    return m ? m[1] : ""
  }
  readonly property bool primaryConnected: {
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) if (screens[i] && screens[i].name === primaryOutput) return true
    return false
  }
  function isPrimaryOutput(screen) {
    return primaryOutput === "" || !primaryConnected || (!!screen && screen.name === primaryOutput)
  }
  // Back in front while locked (switched to from another account): put the
  // keyboard on the primary monitor's password field, so you can type at
  // once. Hyprland is still restoring the monitors then, so a few tries.
  signal refocusRequested()
  property int refocusTries: 0
  function refocusAfterSwitch() {
    root.refocusTries = 0
    refocusTimer.restart()
    refocusTimer.triggered()
  }
  Timer {
    id: refocusTimer
    interval: 300
    repeat: true
    onTriggered: {
      if (!root.lockRequested || !root.sessionActive || ++root.refocusTries > 5) { stop(); return }
      root.focusPrimaryOutput()
      root.refocusRequested()
    }
  }

  // Keyboard focus goes to the lock surface on the focused monitor.
  function focusPrimaryOutput() {
    if (primaryOutput === "" || !primaryConnected) return
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ monitor = "' + primaryOutput + '" })'])
  }

  // Who is signed in here, and who else is signed in on this machine.
  property var currentUserInfo: ({ name: root.userName, realName: "" })
  property var otherUsers: []
  property var accounts: []
  property string avatarPath: ""

  Process {
    id: sessionsProc
    command: ["omarchy-greeter-sessions"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var info = JSON.parse(text)
          if (info.me) root.currentUserInfo = info.me
          root.avatarPath = info.me && info.me.avatar ? info.me.avatar : ""
          root.otherUsers = info.others || []
          root.accounts = info.accounts || []
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.lockRequested
    onTriggered: if (!sessionsProc.running) sessionsProc.running = true
  }

  // The login screen opens on its own console; this session stays locked.
  function switchUser(name) {
    root.logEvent("switch-user " + (name || "(choose)"))
    Quickshell.execDetached(["omarchy-greeter-switch"].concat(name ? [name] : []))
  }

  // Sleep, Restart and Shut down from the lock screen, as on the login
  // screen. Restart and Shut down go through Omarchy, which closes this
  // session's apps first.
  function requestPower(action) {
    var commands = {
      suspend: ["systemctl", "suspend"],
      reboot: ["omarchy-system", "reboot"],
      poweroff: ["omarchy-system", "shutdown"]
    }
    if (!commands[action]) return
    root.logEvent("power " + action)
    Quickshell.execDetached(commands[action])
  }

  // Session state from logind (omarchy-greeter-session-watch):
  //  - a session that goes to the background unlocked locks itself, so a
  //    session you are not looking at is always locked;
  //  - logind "unlock" (SDDM sends it when you log back into this session
  //    from the login screen) unlocks, but only once the session is in front
  //    again, so the unlock is drawn live instead of leaving a stale frame;
  //  - logind "lock" (loginctl lock-session) locks.
  property bool sessionActive: true
  // A logind unlock waits for the session to come back to the front, for at
  // most this long; omarchy-greeter-session-watch also keeps it across a
  // shell restart (it re-announces a recent one at start).
  readonly property int logindUnlockWindowMs: 15000
  property real pendingLogindUnlockAt: 0
  readonly property real shellStartedAt: Date.now()

  function justStarted() { return Date.now() - root.shellStartedAt < root.logindUnlockWindowMs }

  function forgetLogindUnlock() {
    root.pendingLogindUnlockAt = 0
    Quickshell.execDetached(["sh", "-c", 'rm -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/omarchy-greeter-unlock"'])
  }

  function logindUnlockPending() {
    return root.pendingLogindUnlockAt > 0 && Date.now() - root.pendingLogindUnlockAt < root.logindUnlockWindowMs
  }

  function handleSessionEvent(event) {
    if (event === "active") {
      root.sessionActive = true
      if (root.lockRequested) root.refocusAfterSwitch()
      if (root.lockRequested && root.fingerprintConfigured) {
        root.resumeFingerprint()
        Qt.callLater(root.startFingerprint)
      }
      if (root.logindUnlockPending()) logindUnlockTimer.restart()
    } else if (event === "inactive") {
      root.sessionActive = false
      // Nobody can use a reader for a hidden lock; free it for the session
      // in front.
      root.pauseFingerprint()
      if (fingerprintPam.active) {
        // abort() delivers no completion signal; close the attempt here.
        fingerprintPam.abort()
        root.settleFingerprintAttempt()
      }
      backgroundLockTimer.restart()
    } else if (event === "lock") {
      root.pendingLogindUnlockAt = 0
      if (!root.currentlyLocked() && !root.lockRequested) {
        root.logEvent("lock: logind")
        root.beginLock()
      }
    } else if (event === "unlock") {
      // Only for a lock that is up (or coming back right after a shell
      // restart); an unlock sent while unlocked must not open a later lock.
      if (!root.lockRequested && !root.currentlyLocked() && !root.justStarted()) {
        root.forgetLogindUnlock()
        return
      }
      root.pendingLogindUnlockAt = Date.now()
      if (root.sessionActive) logindUnlockTimer.restart()
    }
  }

  // A session out of sight is always locked. Checked every second rather
  // than once, so a lock that fails to start is retried.
  Timer {
    id: backgroundLockTimer
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: false
    onTriggered: {
      if (root.sessionActive) { stop(); return }
      if (root.currentlyLocked() || root.lockRequested) return
      root.logEvent("lock: session went to the background")
      root.beginLock()
    }
  }

  // A short wait after coming to the front lets the compositor take the
  // displays back before the lock goes away. Right after a shell restart the
  // lock may still be coming back, so a pending unlock is held until it is.
  Timer {
    id: logindUnlockTimer
    interval: 250
    onTriggered: {
      if (!root.logindUnlockPending() || !root.sessionActive) return
      if (!root.lockRequested && !root.currentlyLocked()) {
        if (root.justStarted()) restart()
        return
      }
      // Used up: a later shell restart must not replay it.
      root.forgetLogindUnlock()
      root.logEvent("logind-unlock")
      root.finishUnlock()
    }
  }

  // Tell logind whether this session is locked (LockedHint), for any tool
  // that asks it.
  readonly property bool lockedForHint: root.lockRequested || root.currentlyLocked()
  onLockedForHintChanged: Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1",
    "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetLockedHint", "b", root.lockedForHint ? "true" : "false"])
  // A password unlock clears any logind unlock still waiting, and so does a
  // new lock (except the lock coming back after a shell restart, which the
  // replayed unlock is for).
  onLockRequestedChanged: {
    if (!root.lockRequested || !root.justStarted()) root.forgetLogindUnlock()
  }

  Process {
    id: sessionWatch
    command: ["omarchy-greeter-session-watch"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.handleSessionEvent(String(line).trim()) }
    }
    onExited: sessionWatchRestart.restart()
  }
  Timer {
    id: sessionWatchRestart
    interval: 1000
    onTriggered: sessionWatch.running = true
  }
''')

rep("Service.qml", '''    pendingSessionLockTimer.stop()
    sessionLock.locked = true
''', '''    pendingSessionLockTimer.stop()
    root.focusPrimaryOutput()
    sessionLock.locked = true
''')

# Per-surface: black and invisible off the primary. The invisible form still
# takes typing (the password is shared), so keys pressed while focus sits on
# a black monitor are not lost.
rep("Service.qml", '''      color: Commons.Color.background

      LockView {
        id: lockView
        anchors.fill: parent
''', '''      color: root.isPrimaryOutput(lockSurface.screen) ? Commons.Color.background : "#000000"

      LockView {
        id: lockView
        anchors.fill: parent
        opacity: root.isPrimaryOutput(lockSurface.screen) ? 1 : 0
        extrasEnabled: root.isPrimaryOutput(lockSurface.screen)
        currentUser: root.currentUserInfo
        otherUsers: root.otherUsers
        accounts: root.accounts
        avatarPath: root.avatarPath
        onSwitchUserRequested: function(name) { root.switchUser(name) }
        onPowerRequested: function(action) { root.requestPower(action) }
        Connections {
          target: root
          function onRefocusRequested() { if (root.isPrimaryOutput(lockSurface.screen)) lockView.forcePasswordFocus() }
        }
''')
rep("Service.qml", '''        loadBackground: root.locked
''', '''        loadBackground: root.locked && root.isPrimaryOutput(lockSurface.screen)
''')

# The preview (omarchy-shell lock preview) shows the same identity.
rep("Service.qml", '''      inputEnabled: false
''', '''      inputEnabled: false
      currentUser: root.currentUserInfo
      otherUsers: root.otherUsers
      accounts: root.accounts
      avatarPath: root.avatarPath
''')

# ------------------------------------------------------------------ the layout

UI_FILES = ["GreeterLockView.qml", "AccountForm.qml", "AccountList.qml", "PasswordBox.qml",
            "FocusRing.qml", "FormStyle.qml", "UserAvatar.qml", "PowerButton.qml"]

ui = {}
for name in UI_FILES:
    for folder in ui_dirs:
        if (folder / name).is_file():
            ui[name] = (folder / name).read_text()
            break
    else:
        raise SystemExit(f"missing {name} (looked in {', '.join(map(str, ui_dirs)) or 'no folders'})")

# What Omarchy's layout takes: its top-level properties (not readonly) and
# signals. A default is kept only when it is a plain literal.
LITERAL = re.compile(r'"[^"\\]*"|-?\d+(\.\d+)?|true|false|\[\]|\(\{\}\)')
props, signals = [], []
for line in stock_view.splitlines():
    m = re.fullmatch(r"  property ([\w.<>]+) (\w+)(?:\s*:\s*(.*?))?\s*", line)
    if m:
        kind, name, default = m.groups()
        props.append((kind, name, default if default and LITERAL.fullmatch(default) else None))
        continue
    m = re.fullmatch(r"  signal (\w+)(\([^)]*\))?\s*", line)
    if m:
        signals.append((m.group(1), m.group(2) or "()"))
if not any(n == "passwordText" for _, n, _ in props) or not any(n == "submitPassword" for n, _ in signals):
    raise SystemExit("LockView.qml: its interface no longer looks like a lock layout")

OURS_PROPS = [("var", "currentUser", "({})"), ("var", "otherUsers", "[]"), ("var", "accounts", "[]"),
              ("string", "avatarPath", '""'), ("bool", "extrasEnabled", "true")]
OURS_SIGNALS = [("switchUserRequested", "(string name)"), ("powerRequested", "(string action)")]
known = {n for _, n, _ in props}
props += [p for p in OURS_PROPS if p[1] not in known]
known_signals = {n for n, _ in signals}
signals += [s for s in OURS_SIGNALS if s[0] not in known_signals]

decl = "\n".join(f"  property {k} {n}" + (f": {d}" if d else "") for k, n, d in props)
sigs = "\n".join(f"  signal {n}{a}" for n, a in signals)
names = ", ".join(f'"{n}"' for _, n, _ in props)
signal_names = ", ".join(f'"{n}"' for n, _ in signals)

shim = f"""import QtQuick

// {mark}: generated by omarchy-greeter (lib/patch-lock.py) from Omarchy's
// LockView.qml, which is kept unchanged as StockLockView.qml.
//
// Declares everything Omarchy's layout declares, so whatever the lock logic
// passes in loads, then shows omarchy-greeter's layout (GreeterLockView.qml)
// with whatever of it that layout takes. If that layout does not load, it
// shows Omarchy's own instead: the screen stays locked either way.
Item {{
  id: root

{decl}

{sigs}

  readonly property var forwardedProperties: [{names}]
  readonly property var forwardedSignals: [{signal_names}]

  // Which layout is showing, for checks (omarchy-greeter's tests).
  readonly property string loadedLayout: view.status === Loader.Ready ? String(view.source).split("/").pop() : ""
  readonly property var layout: view.item

  function forcePasswordFocus() {{ if (view.item && view.item.forcePasswordFocus) view.item.forcePasswordFocus() }}
  function clearPassword() {{ if (view.item && view.item.clearPassword) view.item.clearPassword() }}

  Loader {{
    id: view
    anchors.fill: parent
    focus: true
    source: "GreeterLockView.qml"
    onStatusChanged: {{
      if (status === Loader.Error && String(source).indexOf("StockLockView.qml") < 0) {{
        console.warn("omarchy-greeter: the lock layout did not load; showing Omarchy's own")
        source = "StockLockView.qml"
      }}
    }}
    onLoaded: {{
      for (var i = 0; i < root.forwardedProperties.length; i++) {{
        var name = root.forwardedProperties[i]
        if (!(name in item)) continue
        item[name] = Qt.binding((function(n) {{ return function() {{ return root[n] }} }})(name))
      }}
      for (var j = 0; j < root.forwardedSignals.length; j++) {{
        var signalName = root.forwardedSignals[j]
        if (item[signalName] && typeof item[signalName].connect === "function") item[signalName].connect(root[signalName])
      }}
    }}
  }}
}}
"""

# All checks passed: write. The stock layout first, so a half-done write can
# never leave a LockView.qml that points at a missing file.
(clone / "StockLockView.qml").write_text(stock_view)
for name, text in ui.items():
    (clone / name).write_text(text)
(clone / "Service.qml").write_text(files["Service.qml"])
(clone / "LockView.qml").write_text(shim)
