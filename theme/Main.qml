import QtQuick
import QtQuick.Effects
import QtQuick.Window

// Omarchy login screen for several users, laid out like Windows: the
// selected account centered (avatar, name, password), every account listed
// bottom-left, power bottom-right. Each account's own blurred background
// and theme colors (published by omarchy-greeter-sync into dataDir) follow
// the selection, revealed with the desktop's slanted wipe. The form is the
// same one the lock screen uses (AccountForm.qml).
Rectangle {
  id: root
  width: 1920
  height: 1080
  color: "#000000"

  readonly property string dataDir: (typeof config !== "undefined" && config.dataDir) ? String(config.dataDir) : "/var/lib/omarchy-greeter/.view"
  readonly property string settingsFile: (typeof config !== "undefined" && config.settingsFile) ? String(config.settingsFile) : "/etc/omarchy-greeter.conf"
  readonly property string bootFlag: (typeof config !== "undefined" && config.bootFlag) ? String(config.bootFlag) : "/run/omarchy-greeter/boot-unlock-hint"

  // ---- primary monitor ---------------------------------------------------
  //
  // Only the primary monitor shows the login screen; the others stay black.
  // If the primary is not connected, every monitor shows it, so a missing
  // monitor can never leave you without a password field.
  property string primaryOutput: ""
  readonly property bool primaryConnected: {
    var screens = Qt.application.screens
    for (var i = 0; i < screens.length; i++) if (screens[i].name === primaryOutput) return true
    return false
  }
  readonly property bool showsUi: primaryOutput === "" || !primaryConnected || Screen.name === primaryOutput

  // ---- one password at boot ----------------------------------------------
  //
  // Set while the first login after a typed disk password may skip the
  // account password (see boot-unlock-auth). PAM decides; this only changes
  // what the field says.
  // The accounts the boot pass is armed for (a world-readable hint next to
  // the root-only mark; the PAM step decides, this only shows it).
  property var bootAccounts: []
  readonly property bool bootUnlocked: bootAccounts.indexOf(userName) >= 0
  // The boot pass only starts new sessions (boot-unlock-auth enforces it).
  readonly property bool bootPassFor: bootUnlocked && !userRunning

  Timer {
    interval: 1500
    running: root.showsUi
    repeat: true
    triggeredOnStart: true
    onTriggered: root.readText(root.bootFlag, function(text) {
      text = text.trim()
      root.bootAccounts = /^[a-z_][a-z0-9_-]*(,[a-z_][a-z0-9_-]*)*$/.test(text) ? text.split(",") : []
    })
  }

  Component.onCompleted: {
    readText(settingsFile, function(text) {
      var m = text.match(/^\s*primary\s*=\s*(\S*)/m)
      root.primaryOutput = m ? m[1] : ""
    })
    pw.focusInput()
    addDemoUsers()
  }

  readonly property string syncFile: (typeof config !== "undefined" && config.syncFile) ? String(config.syncFile) : "/var/lib/sddm/omarchy-greeter-selected"

  // ---- sizing (matches the selected user's desktop) ----------------------
  //
  // Sizes below are in the user's desktop pixels at the Omarchy shell's
  // default 12px font. They are converted to this greeter's pixels with the
  // scale the user runs this monitor at, over the scale the greeter's own
  // compositor picked, and grown or shrunk with the user's shell font size.
  // So text and controls come out the same physical size as after login.

  readonly property var display: look && look.display ? look.display : ({})
  readonly property real userScale: {
    var m = display.monitors || {}
    // Each monitor is { scale, width, ... } (older data: just the scale).
    function scaleOf(v) { return Number(v && typeof v === "object" ? v.scale : v) }
    var s = scaleOf(m[Screen.name])
    if (!(s > 0)) {
      // Unknown connector: use any of the user's scales.
      for (var k in m) { s = scaleOf(m[k]); break }
    }
    // Clamped: these come from files each account writes.
    return s > 0 ? Math.min(Math.max(s, 0.5), 4) : Screen.devicePixelRatio
  }
  readonly property real fontBase: Number(display.fontBaseSize) > 0 ? Math.min(Math.max(Number(display.fontBaseSize), 7), 24) : 12
  property real ui: userScale / Math.max(Screen.devicePixelRatio, 0.5) * fontBase / 12
  Behavior on ui { enabled: root.settled; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  readonly property string fontFamily: display.fontFamily ? String(display.fontFamily) : "JetBrainsMono Nerd Font"

  // ---- users -------------------------------------------------------------

  property var users: []          // [{ name, realName, icon }]
  property int current: -1
  readonly property var user: current >= 0 && current < users.length ? users[current] : null
  readonly property string userName: user ? user.name : ""
  property var looks: ({})        // name -> { colors, background, video, avatar, theme }
  readonly property var look: userName && looks[userName] ? looks[userName] : null

  // Demo accounts for screenshots: theme.conf demoUsers=name:Real Name,...
  // (unset in normal use; the real accounts come from SDDM).
  readonly property string demoUsers: (typeof config !== "undefined" && config.demoUsers) ? String(config.demoUsers) : ""
  readonly property string demoHost: (typeof config !== "undefined" && config.demoHost) ? String(config.demoHost) : ""
  function addDemoUsers() {
    if (!demoUsers) return
    var list = demoUsers.split(",")
    for (var i = 0; i < list.length; i++) {
      var parts = list[i].split(":")
      if (parts[0]) root.addUser({ name: parts[0].trim(), realName: (parts[1] || "").trim(), icon: "" })
    }
  }

  Repeater {
    id: userCollector
    model: root.demoUsers ? 0 : userModel
    delegate: Item {
      required property string name
      required property string realName
      required property string icon
      Component.onCompleted: root.addUser({ name: name, realName: realName, icon: icon })
    }
  }

  property string requestedUser: ""
  property real requestedStamp: 0
  function applyRequestedUser() {
    if (!requestedUser) return
    for (var i = 0; i < users.length; i++) {
      if (users[i].name === requestedUser) {
        requestedUser = ""
        selectUser(i)
        return
      }
    }
  }

  // Has this account a session running (Locked) or not (Log in)? A root
  // service asks logind and keeps this file current (publish-view --sessions).
  function readSession(name) {
    readText(dataDir + "/" + name + "/session", function(id) {
      setLook(name, "running", /^[0-9a-zA-Z]+$/.test(id.trim()))
    })
  }
  Timer {
    interval: 5000
    repeat: true
    running: root.showsUi
    onTriggered: { for (var i = 0; i < root.users.length; i++) root.readSession(root.users[i].name) }
  }
  readonly property bool userRunning: !!(look && look.running)

  function addUser(entry) {
    var list = users.slice()
    list.push(entry)
    users = list
    loadLook(entry.name)
    if (current < 0 || entry.name === userModel.lastUser) current = list.length - 1
    applyRequestedUser()
  }

  function selectUser(index, fromOtherScreen) {
    if (users.length === 0) return
    index = ((index % users.length) + users.length) % users.length
    if (index === current && fromOtherScreen) return
    current = index
    if (!fromOtherScreen) publishSelection()
    pw.text = ""
    loginFailed = false
    authenticating = false
    pw.focusInput()
  }

  function fileUrl(path) { return "file://" + path }

  // Each monitor runs its own copy of this screen with nothing shared in
  // memory, so the selected user is passed between them through a small file.
  property string lastSeenSelection: ""
  readonly property real startedAt: Date.now()

  function publishSelection() {
    if (!userName) return
    var stamp = Date.now() + " " + userName
    lastSeenSelection = stamp
    var xhr = new XMLHttpRequest()
    try {
      xhr.open("PUT", fileUrl(syncFile))
      xhr.send(stamp)
    } catch (e) {}
  }

  Timer {
    interval: 200
    running: root.users.length > 1
    repeat: true
    onTriggered: root.readText(root.syncFile, function(text) {
      text = text.trim()
      if (!text || text === root.lastSeenSelection) return
      root.lastSeenSelection = text
      // Ignore what an earlier greeter left behind.
      if (Number(text.split(" ")[0]) < root.startedAt) return
      var name = text.slice(text.indexOf(" ") + 1)
      for (var i = 0; i < root.users.length; i++) {
        if (root.users[i].name === name) root.selectUser(i, true)
      }
    })
  }

  function readText(path, done) {
    var xhr = new XMLHttpRequest()
    var finished = false
    function finish(text) {
      if (finished) return
      finished = true
      done(text)          // reads it starts count before this one ends
      root.pendingReads--
      Qt.callLater(root.trySettle)
    }
    root.pendingReads++
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) finish(xhr.status === 200 || xhr.status === 0 ? String(xhr.responseText || "") : "")
    }
    try {
      xhr.open("GET", fileUrl(path))
      xhr.send()
    } catch (e) {
      finish("")
    }
  }

  // ---- showing up --------------------------------------------------------
  //
  // Black until the selected account's look (colors, size, background) is
  // loaded, then shown in one step: nothing visibly loads or re-lays out.
  // Opened from a lock screen's Switch user, it appears at once, so it reads
  // as the same screen changing account; otherwise (at boot) it settles in
  // gently. At most 1.5s of black, whatever is still loading.
  property int pendingReads: 0
  property bool settled: false
  property bool quiet: false
  function trySettle() {
    if (settled || pendingReads > 0 || users.length === 0 || !background.ready) return
    settle()
  }
  function settle() {
    if (settled) return
    quiet = requestedStamp > 0
    settled = true
  }
  Timer { interval: 1500; running: true; onTriggered: root.settle() }

  function parseColors(text) {
    var out = {}
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/)
      if (m) out[m[1]] = m[2]
    }
    return out
  }

  function setLook(name, key, value) {
    var all = Object.assign({}, looks)
    all[name] = Object.assign({}, all[name] || {})
    all[name][key] = value
    looks = all
  }

  function loadLook(name) {
    var dir = dataDir + "/" + name + "/"
    // Bust Qt's image cache when a user published a new background.
    readText(dir + "updated", function(stamp) {
      stamp = stamp.trim()
      setLook(name, "background", fileUrl(dir + "background.jpg") + (stamp ? "?v=" + stamp : ""))
      setLook(name, "avatar", fileUrl(dir + "avatar.png") + (stamp ? "?v=" + stamp : ""))
      // The pre-blurred copy, if this account published one (older data
      // has only the sharp background).
      readText(dir + "background-blur.jpg", function(data) {
        setLook(name, "blur", data.length > 0 ? fileUrl(dir + "background-blur.jpg") + (stamp ? "?v=" + stamp : "") : "")
      })
    })
    readText(dir + "colors.toml", function(text) { setLook(name, "colors", parseColors(text)) })
    readText(dir + "display.json", function(text) {
      var parsed = {}
      try { parsed = JSON.parse(text) || {} } catch (e) {}
      setLook(name, "display", parsed)
    })
    readText(dir + "theme.name", function(text) { setLook(name, "theme", text.trim()) })
    readSession(name)
    // A lock screen's "Switch user" names the account to preselect.
    // Only a request made just before this login screen opened counts, and
    // the newest one wins (several accounts may have left one).
    readText(dir + "switch-to", function(text) {
      var parts = text.trim().split(" ")
      var stamp = Number(parts[0])
      if (parts.length !== 2 || !(stamp > 0)) return
      if (stamp < root.startedAt / 1000 - 15 || stamp > Date.now() / 1000 + 2) return
      if (stamp <= root.requestedStamp) return
      root.requestedStamp = stamp
      root.requestedUser = parts[1]
      root.applyRequestedUser()
    })
    readText(dir + "video", function(text) {
      var file = text.trim()
      setLook(name, "video", /^background\.(mp4|webm|mkv|mov|m4v)$/.test(file) ? fileUrl(dir + file) : "")
    })
  }

  // ---- palette (follows the selected user's theme) -----------------------

  function pick(key, fallback) {
    var c = look && look.colors ? look.colors[key] : undefined
    return c ? c : fallback
  }

  property color cBackground: pick("background", "#1a1b26")
  property color cSurface: pick("lighter_background", "#24283b")
  property color cForeground: pick("foreground", "#a9b1d6")
  property color cBright: pick("bright_foreground", "#c0caf5")
  property color cMuted: pick("dark_foreground", "#565f89")
  property color cAccent: pick("accent", "#7aa2f7")
  property color cError: pick("red", "#f7768e")
  property color cWarn: pick("yellow", "#e0af68")
  Behavior on cBackground { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cSurface { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cForeground { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cBright { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cMuted { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cAccent { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cError { enabled: root.settled; ColorAnimation { duration: 600 } }
  Behavior on cWarn { enabled: root.settled; ColorAnimation { duration: 600 } }

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ---- session & auth ----------------------------------------------------

  property bool loginFailed: false
  property bool authenticating: false
  property bool capsGuess: false
  readonly property bool capsOn: (typeof keyboard !== "undefined" && keyboard && keyboard.capsLock) || capsGuess

  // The Omarchy session (uwsm), which runs the per-user services this
  // login screen and the lock rely on. SDDM's session list answers its own
  // roles only: FileRole = Qt.UserRole + 2, ExecRole = Qt.UserRole + 5.
  property int sessionIndex: {
    var fallback = -1
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var index = sessionModel.index(i, 0)
      var file = String(sessionModel.data(index, Qt.UserRole + 2) || "")
      var exec = String(sessionModel.data(index, Qt.UserRole + 5) || "")
      if (/(^|\/)omarchy\.desktop$/.test(file)) return i
      if (fallback < 0 && (file.indexOf("uwsm") !== -1 || exec.indexOf("uwsm") !== -1)) fallback = i
    }
    return fallback >= 0 ? fallback : sessionModel.lastIndex
  }

  function login() {
    if (!userName || authenticating || !showsUi) return
    if (pw.text.length === 0 && !bootPassFor) return
    authenticating = true
    loginFailed = false
    sddm.login(userName, pw.text, sessionIndex)
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.authenticating = false
      root.loginFailed = true
      pw.text = ""
      pw.shake()
      pw.focusInput()
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  // ---- shared form style -------------------------------------------------

  FormStyle {
    id: formStyle
    ui: root.ui
    fontFamily: root.fontFamily
    back: root.cBackground
    text: root.cForeground
    bright: root.cBright
    muted: root.cMuted
    accent: root.cAccent
    error: root.cError
    warn: root.cWarn
  }
  readonly property var pw: form.passwordBox

  // Accounts for the list, each in its own colors.
  readonly property var accountRows: {
    var rows = []
    for (var i = 0; i < users.length; i++) {
      var u = users[i], l = looks[u.name] || {}
      var c = l.colors || {}
      rows.push({ name: u.name, label: u.realName || u.name, picture: l.avatar || "", faceIcon: u.icon || "",
                  accent: c.accent || "", ink: c.background || "", signedIn: !!l.running })
    }
    return rows
  }

  // ---- background --------------------------------------------------------

  Item {
    id: scene
    anchors.fill: parent

    // A gentle settle on first show (not after Switch user).
    scale: root.settled ? 1.0 : 1.04
    Behavior on scale { enabled: !root.quiet; NumberAnimation { duration: 1600; easing.type: Easing.OutCubic } }

    // The account's background, blurred ahead of time (sharp if it has no
    // blurred copy yet).
    RevealBackground {
      id: background
      anchors.fill: parent
      source: root.showsUi && root.look ? (root.look.blur || root.look.background || "") : ""
      fallbackColor: root.cBackground
      animate: root.settled
      onReadyChanged: root.trySettle()
      decodeSize: Qt.size(Math.ceil(root.width * Screen.devicePixelRatio), Math.ceil(root.height * Screen.devicePixelRatio))
    }

    Loader {
      anchors.fill: parent
      active: root.showsUi && !!(root.look && root.look.video)
      source: "VideoLayer.qml"
      onLoaded: item.source = Qt.binding(function() { return root.look && root.look.video ? root.look.video : "" })
    }
  }

  // Flat, not a gradient: a soft gradient over a whole 4K screen steps
  // through only a few dozen color levels and shows as horizontal bands.
  Rectangle {
    anchors.fill: parent
    color: root.alpha(root.cBackground, root.look && root.look.video ? 0.5 : 0.3)
  }

  // ---- clock -------------------------------------------------------------

  property date now: new Date()
  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Column {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: root.height * 0.08
    spacing: 2 * root.ui
    opacity: root.settled ? 1 : 0
    Behavior on opacity { enabled: !root.quiet; NumberAnimation { duration: 900 } }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
      color: root.cBright
      font.family: root.fontFamily
      font.pixelSize: 64 * root.ui
      font.weight: Font.Light
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(root.now, "dddd, MMMM d")
      color: root.cForeground
      font.family: root.fontFamily
      font.pixelSize: 17 * root.ui
    }
  }

  // ---- the form ----------------------------------------------------------

  AccountForm {
    id: form
    st: formStyle
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.height * 0.03
    opacity: root.settled ? 1 : 0
    Behavior on opacity { enabled: !root.quiet; NumberAnimation { duration: 700 } }

    displayName: root.user ? (root.user.realName || root.user.name) : ""
    userName: root.userName
    picture: root.look && root.look.avatar ? root.look.avatar : ""
    faceIcon: root.user ? root.user.icon : ""
    status: root.userRunning ? "Signed in · locked" : ""
    statusGlyph: root.userRunning ? "" : ""
    message: root.bootPassFor && !root.loginFailed ? "Your disk password already unlocked this account" : ""

    passwordBox.placeholder: root.loginFailed ? "Wrong password, try again"
      : (root.bootPassFor ? "Press Enter to sign in" : (root.userRunning ? "Password to unlock" : "Password"))
    passwordBox.failed: root.loginFailed
    passwordBox.busy: root.authenticating
    passwordBox.capsOn: root.capsOn
    passwordBox.openLock: root.bootPassFor
    passwordBox.inputEnabled: root.showsUi
  }

  Connections {
    target: root.pw
    function onSubmitted() { root.login() }
    function onKeyFilter(event) {
      if (event.text.length === 1 && event.text.toLowerCase() !== event.text.toUpperCase()) {
        var upper = event.text !== event.text.toLowerCase()
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        root.capsGuess = upper !== shift
      }
      if (event.key === Qt.Key_CapsLock) root.capsGuess = !root.capsGuess
      // Up/Down step through the accounts without leaving the field.
      if (event.key === Qt.Key_Down) {
        root.selectUser(root.current + 1)
        event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        root.selectUser(root.current - 1)
        event.accepted = true
      }
    }
  }
  Connections {
    target: root.pw.input
    function onTextChanged() { if (root.pw.text.length > 0) root.loginFailed = false }
  }

  // ---- accounts, bottom-left -----------------------------------------------

  AccountList {
    id: accountList
    st: formStyle
    visible: root.users.length > 1 && root.showsUi
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: 36 * root.ui
    anchors.bottomMargin: 36 * root.ui
    accounts: root.accountRows
    selected: root.userName
    onChosen: (name) => {
      for (var i = 0; i < root.users.length; i++) if (root.users[i].name === name) root.selectUser(i)
      root.pw.focusInput()
    }
    onTyped: (text) => {
      root.pw.focusInput()
      root.pw.text += text
    }
  }

  // ---- machine, top-left; power, bottom-right ----------------------------

  Text {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: 28 * root.ui
    textFormat: Text.PlainText
    text: "  " + (root.demoHost || sddm.hostName)
    color: root.alpha(root.cForeground, 0.8)
    font.family: root.fontFamily
    font.pixelSize: 14 * root.ui
  }

  Row {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 28 * root.ui
    spacing: 8 * root.ui

    PowerButton {
      st: formStyle
      visible: sddm.canSuspend || root.demoUsers !== ""
      glyph: "\u{f04b2}"
      label: "Sleep"
      onClicked: sddm.suspend()
    }
    PowerButton {
      st: formStyle
      visible: sddm.canReboot || root.demoUsers !== ""
      glyph: "\u{f0709}"
      label: "Restart"
      onClicked: sddm.reboot()
    }
    PowerButton {
      st: formStyle
      visible: sddm.canPowerOff || root.demoUsers !== ""
      glyph: "\u{f0425}"
      label: "Shut down"
      hoverInk: root.cError
      onClicked: sddm.powerOff()
    }
  }

  // Black until settled (see "showing up").
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    visible: !root.settled
  }

  // Non-primary monitors: plain black over everything, swallowing clicks.
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    visible: !root.showsUi
    z: 1000
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }
  }
}
