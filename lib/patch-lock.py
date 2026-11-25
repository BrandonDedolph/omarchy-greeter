"""Patch a fresh clone of Omarchy's lock plugin (omarchy.lock).

Adds, on top of the built-in lock:
  - the form shows only on the primary monitor (/etc/omarchy-greeter.conf),
    other monitors black but still passing typing through;
  - who is signed in (avatar, name) and which other accounts are signed in;
  - "Switch user": opens the login screen while this session stays locked;
  - unlocks when logind says so (SDDM does when you log back into this
    session from the login screen), so switching back takes one password.

Every anchor must match exactly once, or nothing is written and the caller
falls back to the built-in lock.

usage: patch-lock.py <clone-dir> <marker>
"""
import sys
from pathlib import Path

clone, mark = Path(sys.argv[1]), sys.argv[2]
files = {name: (clone / name).read_text() for name in ("Service.qml", "LockView.qml")}


def rep(name, old, new):
    text = files[name]
    if text.count(old) != 1:
        raise SystemExit(f"{name}: anchor not found exactly once: {old.strip()[:70]!r}")
    files[name] = text.replace(old, new)


# ---------------------------------------------------------------- Service.qml

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
  // Keyboard focus goes to the lock surface on the focused monitor.
  function focusPrimaryOutput() {
    if (primaryOutput === "" || !primaryConnected) return
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ monitor = "' + primaryOutput + '" })'])
  }

  // Who is signed in here, and who else is signed in on this machine.
  property var currentUserInfo: ({ name: root.userName, realName: "" })
  property var otherUsers: []
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

  // Session state from logind (omarchy-greeter-session-watch):
  //  - a session that goes to the background unlocked locks itself, so a
  //    session you are not looking at is always locked;
  //  - logind "unlock" (SDDM sends it when you log back into this session
  //    from the login screen) unlocks, but only once the session is in front
  //    again, so the unlock is drawn live instead of leaving a stale frame;
  //  - logind "lock" (loginctl lock-session) locks.
  property bool sessionActive: true
  property bool pendingLogindUnlock: false

  function handleSessionEvent(event) {
    if (event === "active") {
      root.sessionActive = true
      if (root.pendingLogindUnlock) logindUnlockTimer.restart()
    } else if (event === "inactive") {
      root.sessionActive = false
      if (!root.currentlyLocked() && !root.lockRequested) {
        root.logEvent("lock: session went to the background")
        Quickshell.execDetached(["omarchy-system-lock"])
      }
    } else if (event === "lock") {
      root.pendingLogindUnlock = false
      if (!root.currentlyLocked() && !root.lockRequested) {
        root.logEvent("lock: logind")
        Quickshell.execDetached(["omarchy-system-lock"])
      }
    } else if (event === "unlock") {
      if (!root.lockRequested) return
      root.pendingLogindUnlock = true
      if (root.sessionActive) logindUnlockTimer.restart()
    }
  }

  // A short wait after coming to the front lets the compositor take the
  // displays back before the lock goes away.
  Timer {
    id: logindUnlockTimer
    interval: 250
    onTriggered: {
      if (!root.pendingLogindUnlock || !root.sessionActive) return
      root.pendingLogindUnlock = false
      root.logEvent("logind-unlock")
      root.finishUnlock()
    }
  }

  // Tell logind whether this session is locked (LockedHint), for any tool
  // that asks it.
  readonly property bool lockedForHint: root.lockRequested || root.currentlyLocked()
  onLockedForHintChanged: Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1",
    "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetLockedHint", "b", root.lockedForHint ? "true" : "false"])
  // A password unlock clears any logind unlock still waiting.
  onLockRequestedChanged: if (!root.lockRequested) root.pendingLogindUnlock = false

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
    interval: 5000
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
        currentUser: root.currentUserInfo
        otherUsers: root.otherUsers
        avatarPath: root.avatarPath
        onSwitchUserRequested: function(name) { root.switchUser(name) }
''')
rep("Service.qml", '''        loadBackground: root.locked
''', '''        loadBackground: root.locked && root.isPrimaryOutput(lockSurface.screen)
''')

# The preview (omarchy-shell lock preview) shows the same identity.
rep("Service.qml", '''      inputEnabled: false
''', '''      inputEnabled: false
      currentUser: root.currentUserInfo
      otherUsers: root.otherUsers
      avatarPath: root.avatarPath
''')

# --------------------------------------------------------------- LockView.qml

rep("LockView.qml", '''  signal wakeRequested()
''', '''  signal wakeRequested()

  // ''' + mark + ''': who is signed in, and switching accounts.
  property var currentUser: ({ name: "", realName: "" })
  property var otherUsers: []
  property string avatarPath: ""
  signal switchUserRequested(string name)

  readonly property string displayName: currentUser && (currentUser.realName || currentUser.name) ? (currentUser.realName || currentUser.name) : ""

  function initials(text) {
    var parts = String(text || "?").replace(/[._-]+/g, " ").trim().split(/\\s+/)
    return (parts[0].charAt(0) + (parts.length > 1 ? parts[parts.length - 1].charAt(0) : "")).toUpperCase()
  }
''')

rep("LockView.qml", '''    // The crossed-out icon has no meaning to a user who has never seen it — it
''', '''    // Signed in as: avatar and name above the password field.
    Column {
      id: identity
      visible: root.displayName !== ""
      anchors.bottom: inputField.top
      anchors.bottomMargin: 32
      anchors.horizontalCenter: inputField.horizontalCenter
      spacing: 10

      Item {
        width: 96
        height: 96
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: Commons.Color.lock.borderActive
          Text {
            anchors.centerIn: parent
            visible: avatarImage.status !== Image.Ready
            text: root.initials(root.displayName)
            color: Commons.Color.lock.background
            font.family: Style.font.family
            font.pixelSize: 34
            font.bold: true
          }
        }
        Image {
          id: avatarImage
          anchors.fill: parent
          anchors.margins: 3
          source: root.avatarPath ? "file://" + root.avatarPath : ""
          sourceSize: Qt.size(256, 256)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: false
        }
        Rectangle {
          id: avatarMask
          anchors.fill: avatarImage
          radius: width / 2
          visible: false
          layer.enabled: true
        }
        MultiEffect {
          anchors.fill: avatarImage
          source: avatarImage
          visible: avatarImage.status === Image.Ready
          maskEnabled: true
          maskSource: avatarMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1.0
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: root.displayName
        color: Commons.Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.5)
        font.bold: true
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: !!root.currentUser.realName && root.currentUser.realName !== root.currentUser.name
        text: root.currentUser.name || ""
        color: Commons.Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "\\uf023  Locked"
        color: Commons.Color.lock.borderActive
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        topPadding: 2
      }
    }

    // Other accounts signed in, and switching to the login screen.
    Row {
      id: switchRow
      anchors.top: inputField.bottom
      anchors.topMargin: root.fingerprintConfigured && root.fingerprintUnavailable ? 72 : 28
      anchors.horizontalCenter: inputField.horizontalCenter
      spacing: 10

      Repeater {
        model: root.otherUsers
        delegate: Rectangle {
          required property var modelData
          height: 38
          width: chipText.implicitWidth + 32
          radius: height / 2
          color: Commons.Color.lock.background
          border.width: 1
          border.color: chipMouse.containsMouse ? Commons.Color.lock.borderActive : Commons.Color.lock.placeholder
          Text {
            id: chipText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "\\u{f0004}  " + (modelData.realName || modelData.name) + "  \\u00b7 signed in"
            color: Commons.Color.lock.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
          }
          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.switchUserRequested(modelData.name)
          }
        }
      }

      Rectangle {
        height: 38
        width: switchText.implicitWidth + 32
        radius: height / 2
        color: Commons.Color.lock.background
        border.width: 1
        border.color: switchMouse.containsMouse ? Commons.Color.lock.borderActive : Commons.Color.lock.placeholder
        Text {
          id: switchText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "\\u{f0019}  Switch user"
          color: Commons.Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
        }
        MouseArea {
          id: switchMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.switchUserRequested("")
        }
      }
    }

    // The crossed-out icon has no meaning to a user who has never seen it — it
''')

for name, text in files.items():
    (clone / name).write_text(text)
