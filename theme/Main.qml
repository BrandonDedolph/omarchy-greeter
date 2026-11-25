import QtQuick
import QtQuick.Effects
import QtQuick.Window

// Omarchy login screen for several users. Each user's own background and
// theme colors (published by omarchy-greeter-sync into dataDir) follow the
// selected account, and switching accounts reveals the next background with
// the desktop's slanted wipe.
Rectangle {
  id: root
  width: 1920
  height: 1080
  color: "#000000"

  readonly property string dataDir: (typeof config !== "undefined" && config.dataDir) ? String(config.dataDir) : "/var/lib/omarchy-greeter"
  readonly property string settingsFile: (typeof config !== "undefined" && config.settingsFile) ? String(config.settingsFile) : "/etc/omarchy-greeter.conf"
  readonly property string bootFlag: (typeof config !== "undefined" && config.bootFlag) ? String(config.bootFlag) : "/run/omarchy-greeter/boot-unlocked"

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
  property bool bootUnlocked: false

  Timer {
    interval: 1500
    running: root.showsUi
    repeat: true
    triggeredOnStart: true
    onTriggered: root.readText(root.bootFlag, function(text) { root.bootUnlocked = text.trim().length > 0 })
  }

  Component.onCompleted: {
    readText(settingsFile, function(text) {
      var m = text.match(/^\s*primary\s*=\s*(\S*)/m)
      root.primaryOutput = m ? m[1] : ""
    })
    password.forceActiveFocus()
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
    var s = Number(m[Screen.name])
    if (!(s > 0)) {
      // Unknown connector: use the user's most common scale.
      for (var k in m) { s = Number(m[k]); break }
    }
    return s > 0 ? s : Screen.devicePixelRatio
  }
  readonly property real fontBase: Number(display.fontBaseSize) > 0 ? Number(display.fontBaseSize) : 12
  property real ui: userScale / Math.max(Screen.devicePixelRatio, 0.5) * fontBase / 12
  Behavior on ui { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  readonly property string fontFamily: display.fontFamily ? String(display.fontFamily) : "JetBrainsMono Nerd Font"

  // ---- users -------------------------------------------------------------

  property var users: []          // [{ name, realName, icon }]
  property int current: -1
  readonly property var user: current >= 0 && current < users.length ? users[current] : null
  readonly property string userName: user ? user.name : ""
  property var looks: ({})        // name -> { colors, background, video, avatar, theme }
  readonly property var look: userName && looks[userName] ? looks[userName] : null

  Repeater {
    id: userCollector
    model: userModel
    delegate: Item {
      required property string name
      required property string realName
      required property string icon
      Component.onCompleted: root.addUser({ name: name, realName: realName, icon: icon })
    }
  }

  function addUser(entry) {
    var list = users.slice()
    list.push(entry)
    users = list
    loadLook(entry.name)
    if (current < 0 || entry.name === userModel.lastUser) current = list.length - 1
  }

  function selectUser(index, fromOtherScreen) {
    if (users.length === 0) return
    index = ((index % users.length) + users.length) % users.length
    if (index === current && fromOtherScreen) return
    current = index
    if (!fromOtherScreen) publishSelection()
    password.text = ""
    loginFailed = false
    authenticating = false
    password.forceActiveFocus()
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
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status === 200 || xhr.status === 0 ? String(xhr.responseText || "") : "")
    }
    try {
      xhr.open("GET", fileUrl(path))
      xhr.send()
    } catch (e) {
      done("")
    }
  }

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
    })
    readText(dir + "colors.toml", function(text) { setLook(name, "colors", parseColors(text)) })
    readText(dir + "display.json", function(text) {
      var parsed = {}
      try { parsed = JSON.parse(text) || {} } catch (e) {}
      setLook(name, "display", parsed)
    })
    readText(dir + "theme.name", function(text) { setLook(name, "theme", text.trim()) })
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
  Behavior on cBackground { ColorAnimation { duration: 600 } }
  Behavior on cSurface { ColorAnimation { duration: 600 } }
  Behavior on cForeground { ColorAnimation { duration: 600 } }
  Behavior on cBright { ColorAnimation { duration: 600 } }
  Behavior on cMuted { ColorAnimation { duration: 600 } }
  Behavior on cAccent { ColorAnimation { duration: 600 } }
  Behavior on cError { ColorAnimation { duration: 600 } }
  Behavior on cWarn { ColorAnimation { duration: 600 } }

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ---- session & auth ----------------------------------------------------

  property bool loginFailed: false
  property bool authenticating: false
  property bool capsGuess: false
  readonly property bool capsOn: (typeof keyboard !== "undefined" && keyboard && keyboard.capsLock) || capsGuess

  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var label = String(sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "")
      if (label.indexOf("uwsm") !== -1) return i
    }
    return sessionModel.lastIndex
  }

  function login() {
    if (!userName || authenticating || !showsUi) return
    if (password.text.length === 0 && !bootUnlocked) return
    authenticating = true
    loginFailed = false
    sddm.login(userName, password.text, sessionIndex)
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.authenticating = false
      root.loginFailed = true
      password.text = ""
      shake.restart()
      password.forceActiveFocus()
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  // ---- background --------------------------------------------------------

  // Everything behind the UI, so the frosted card can blur it.
  Item {
    id: scene
    anchors.fill: parent

    // A gentle settle on first show.
    scale: entered ? 1.0 : 1.04
    property bool entered: false
    Behavior on scale { NumberAnimation { duration: 1600; easing.type: Easing.OutCubic } }
    Component.onCompleted: entered = true

    RevealBackground {
      id: background
      anchors.fill: parent
      source: root.showsUi && root.look && root.look.background ? root.look.background : ""
      fallbackColor: root.cBackground
      decodeSize: Qt.size(Math.ceil(root.width * Screen.devicePixelRatio), Math.ceil(root.height * Screen.devicePixelRatio))
    }

    Loader {
      anchors.fill: parent
      active: root.showsUi && !!(root.look && root.look.video)
      source: "VideoLayer.qml"
      onLoaded: item.source = Qt.binding(function() { return root.look && root.look.video ? root.look.video : "" })
    }
  }

  // Legibility: darken toward the middle band and the bottom edge, in the
  // theme's own background color rather than flat black.
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.alpha(root.cBackground, 0.10) }
      GradientStop { position: 0.45; color: root.alpha(root.cBackground, 0.30) }
      GradientStop { position: 1.0; color: root.alpha(root.cBackground, 0.65) }
    }
  }

  // ---- clock -------------------------------------------------------------

  property date now: new Date()
  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  Column {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: root.height * 0.12
    spacing: 4 * root.ui
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: 900 } }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
      color: root.cBright
      font.family: root.fontFamily
      font.pixelSize: 112 * root.ui
      font.weight: Font.Light
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.alpha(root.cBackground, 0.8); shadowBlur: 0.8 }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(root.now, "dddd, MMMM d")
      color: root.cForeground
      font.family: root.fontFamily
      font.pixelSize: 22 * root.ui
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.alpha(root.cBackground, 0.8); shadowBlur: 0.6 }
    }
  }

  // ---- login card --------------------------------------------------------

  // Frosted glass behind the card: the scene blurred and tinted with the
  // theme background, so any wallpaper (even one with a centered logo) stays
  // readable.
  Item {
    id: frost
    x: card.x - 44 * root.ui
    y: card.y - 36 * root.ui
    width: card.width + 88 * root.ui
    height: card.height + 72 * root.ui
    opacity: card.opacity

    ShaderEffectSource {
      id: frostSource
      anchors.fill: parent
      sourceItem: scene
      sourceRect: Qt.rect(frost.x, frost.y, frost.width, frost.height)
      visible: false
    }
    Rectangle {
      id: frostMask
      anchors.fill: parent
      radius: 28 * root.ui
      visible: false
      layer.enabled: true
    }
    MultiEffect {
      anchors.fill: parent
      source: frostSource
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      saturation: 0.1
      maskEnabled: true
      maskSource: frostMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
    }
    Rectangle {
      anchors.fill: parent
      radius: frostMask.radius
      color: root.alpha(root.cBackground, 0.55)
      border.width: 1
      border.color: root.alpha(root.cForeground, 0.12)
    }
  }

  Column {
    id: card
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.height * 0.11
    spacing: 18 * root.ui
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: 700 } }

    UserAvatar {
      id: bigAvatar
      anchors.horizontalCenter: parent.horizontalCenter
      width: 112 * root.ui
      height: width
      ringWidth: 3 * root.ui
      picture: root.look && root.look.avatar ? root.look.avatar : ""
      faceIcon: root.user ? root.user.icon : ""
      label: root.user ? (root.user.realName || root.user.name) : ""
      accent: root.cAccent
      ink: root.cBackground
      fontFamily: root.fontFamily
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 2 * root.ui
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.user ? (root.user.realName || root.user.name) : ""
        color: root.cBright
        font.family: root.fontFamily
        font.pixelSize: 26 * root.ui
        font.bold: true
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !!root.user && !!root.user.realName && root.user.realName !== root.user.name
        text: root.user ? root.user.name : ""
        color: root.cForeground
        font.family: root.fontFamily
        font.pixelSize: 15 * root.ui
      }
    }

    // Password field
    Item {
      id: fieldBox
      anchors.horizontalCenter: parent.horizontalCenter
      width: 400 * root.ui
      height: 54 * root.ui
      property real shakeOffset: 0
      transform: Translate { x: fieldBox.shakeOffset }

      SequentialAnimation {
        id: shake
        NumberAnimation { target: fieldBox; property: "shakeOffset"; to: -14 * root.ui; duration: 50 }
        NumberAnimation { target: fieldBox; property: "shakeOffset"; to: 12 * root.ui; duration: 70 }
        NumberAnimation { target: fieldBox; property: "shakeOffset"; to: -8 * root.ui; duration: 70 }
        NumberAnimation { target: fieldBox; property: "shakeOffset"; to: 5 * root.ui; duration: 60 }
        NumberAnimation { target: fieldBox; property: "shakeOffset"; to: 0; duration: 60 }
      }

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.alpha(root.cBackground, 0.78)
        border.width: 2 * root.ui
        border.color: root.loginFailed ? root.cError : (password.activeFocus ? root.cAccent : root.alpha(root.cForeground, 0.25))
        Behavior on border.color { ColorAnimation { duration: 200 } }
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 22 * root.ui
        anchors.verticalCenter: parent.verticalCenter
        text: root.bootUnlocked && !root.loginFailed ? "\uf09c" : "\uf023"
        color: root.loginFailed ? root.cError : root.cMuted
        font.family: root.fontFamily
        font.pixelSize: 18 * root.ui
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 52 * root.ui
        anchors.verticalCenter: parent.verticalCenter
        visible: password.text.length === 0 && !root.authenticating
        text: root.loginFailed ? "Wrong password, try again" : (root.bootUnlocked ? "Unlocked at boot \u00b7 press Enter" : "Password")
        color: root.loginFailed ? root.cError : root.cMuted
        font.family: root.fontFamily
        font.pixelSize: 16 * root.ui
      }

      // Dots rather than the real field, so length shows but text does not.
      Row {
        id: dots
        anchors.left: parent.left
        anchors.leftMargin: 54 * root.ui
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7 * root.ui
        visible: !root.authenticating
        Repeater {
          model: Math.min(password.text.length, 22)
          Rectangle {
            width: 9 * root.ui
            height: width
            radius: width / 2
            color: root.cBright
            scale: 0
            Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
          }
        }
        Rectangle {
          width: 2 * root.ui
          height: 22 * root.ui
          color: root.cAccent
          visible: password.activeFocus
          anchors.verticalCenter: parent.verticalCenter
          SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0; duration: 530 }
            NumberAnimation { to: 1; duration: 530 }
          }
        }
      }

      // Working indicator while PAM checks the password.
      Row {
        anchors.centerIn: parent
        spacing: 10 * root.ui
        visible: root.authenticating
        Repeater {
          model: 3
          Rectangle {
            required property int index
            width: 10 * root.ui
            height: width
            radius: width / 2
            color: root.cAccent
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              PauseAnimation { duration: index * 160 }
              NumberAnimation { from: 0.25; to: 1; duration: 320 }
              NumberAnimation { from: 1; to: 0.25; duration: 320 }
              PauseAnimation { duration: (2 - index) * 160 }
            }
          }
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.ui
        anchors.verticalCenter: parent.verticalCenter
        visible: root.capsOn
        height: 28 * root.ui
        width: capsText.width + 18 * root.ui
        radius: height / 2
        color: root.alpha(root.cWarn, 0.18)
        border.color: root.cWarn
        border.width: 1
        Text {
          id: capsText
          anchors.centerIn: parent
          text: "⇪ CAPS"
          color: root.cWarn
          font.family: root.fontFamily
          font.pixelSize: 12 * root.ui
          font.bold: true
        }
      }

      TextInput {
        id: password
        anchors.fill: parent
        echoMode: TextInput.Password
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        cursorDelegate: Item {}
        readOnly: root.authenticating
        enabled: root.showsUi
        focus: true
        onTextChanged: if (text.length > 0) root.loginFailed = false

        Keys.onPressed: (event) => {
          if (event.text.length === 1 && event.text.toLowerCase() !== event.text.toUpperCase()) {
            var upper = event.text !== event.text.toLowerCase()
            var shift = (event.modifiers & Qt.ShiftModifier) !== 0
            root.capsGuess = upper !== shift
          }
          if (event.key === Qt.Key_CapsLock) root.capsGuess = !root.capsGuess
          if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
            root.selectUser(root.current + 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
            root.selectUser(root.current - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            text = ""
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.login()
            event.accepted = true
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: password.forceActiveFocus()
      }
    }

    // Other accounts
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 14 * root.ui
      visible: root.users.length > 1
      topPadding: 10 * root.ui

      Repeater {
        model: root.users.length
        Item {
          id: chip
          required property int index
          readonly property var entry: root.users[index]
          readonly property var entryLook: root.looks[entry.name] || null
          readonly property bool selected: index === root.current
          width: 44 * root.ui
          height: width
          opacity: selected ? 1 : (chipMouse.containsMouse ? 0.9 : 0.55)
          scale: selected ? 1.0 : 0.88
          Behavior on opacity { NumberAnimation { duration: 200 } }
          Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

          UserAvatar {
            anchors.fill: parent
            ringWidth: 2 * root.ui
            picture: chip.entryLook && chip.entryLook.avatar ? chip.entryLook.avatar : ""
            faceIcon: chip.entry.icon
            label: chip.entry.realName || chip.entry.name
            // Each chip wears its own user's accent, a preview of their theme.
            accent: chip.entryLook && chip.entryLook.colors && chip.entryLook.colors.accent ? chip.entryLook.colors.accent : root.cAccent
            ink: chip.entryLook && chip.entryLook.colors && chip.entryLook.colors.background ? chip.entryLook.colors.background : root.cBackground
            ring: chip.selected ? root.cBright : "transparent"
            fontFamily: root.fontFamily
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selectUser(chip.index)
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.users.length > 1
      text: "Tab to switch user"
      color: root.alpha(root.cForeground, 0.7)
      font.family: root.fontFamily
      font.pixelSize: 13 * root.ui
    }
  }

  // ---- footer ------------------------------------------------------------

  Text {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: 28 * root.ui
    text: "  " + sddm.hostName + (root.look && root.look.theme ? "     " + root.look.theme : "")
    color: root.alpha(root.cForeground, 0.8)
    font.family: root.fontFamily
    font.pixelSize: 14 * root.ui
  }

  Row {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 20 * root.ui
    spacing: 6 * root.ui

    PowerButton {
      visible: sddm.canSuspend
      glyph: "\u{f04b2}"
      label: "Sleep"
      ink: root.alpha(root.cForeground, 0.85); hoverInk: root.cAccent; fontFamily: root.fontFamily
      onClicked: sddm.suspend()
    }
    PowerButton {
      visible: sddm.canReboot
      glyph: "\u{f0709}"
      label: "Restart"
      ink: root.alpha(root.cForeground, 0.85); hoverInk: root.cAccent; fontFamily: root.fontFamily
      onClicked: sddm.reboot()
    }
    PowerButton {
      visible: sddm.canPowerOff
      glyph: "\u{f0425}"
      label: "Shut down"
      ink: root.alpha(root.cForeground, 0.85); hoverInk: root.cError; fontFamily: root.fontFamily
      onClicked: sddm.powerOff()
    }
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
