import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons

// omarchy-greeter's lock layout: the same screen as the login screen, as on
// Windows, where the lock screen is where you sign back in. The shared form
// (AccountForm.qml), every account bottom-left (choosing another one opens
// the login screen with it selected), the machine top-left, Sleep / Restart /
// Shut down bottom-right, and the account's pre-blurred background.
//
// It is loaded by the generated LockView.qml (see lib/patch-lock.py), which
// takes whatever Omarchy's lock logic passes in and forwards what this file
// declares. If this file fails to load, that wrapper loads Omarchy's own
// layout instead (StockLockView.qml), so the screen is locked either way.
//
// The behaviour Omarchy's layout has is kept: the password lives in the
// lock logic (passwordText / passwordTextEdited), held keys do not repeat
// into the field, Escape or Ctrl+U clears it, and focus comes back to the
// field after a VT switch.
Item {
  id: root

  // ---- Omarchy's lock interface ------------------------------------------
  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // ---- omarchy-greeter's additions -----------------------------------------
  property var currentUser: ({ name: "", realName: "" })
  property var otherUsers: []
  property var accounts: []            // [{ name, realName, signedIn }]
  property string avatarPath: ""
  // Off on the black monitors, where the form is invisible but typing still
  // reaches the password field: nothing hidden may be clickable there.
  property bool extrasEnabled: true
  // Whether this session is the one on screen (the lock logic follows logind).
  property bool sessionActive: true
  signal switchUserRequested(string name)
  // The picture is back after a switch: the session hands this screen the keyboard.
  signal arrived()
  signal powerRequested(string action)      // suspend, reboot or poweroff

  property date now: new Date()
  readonly property string me: currentUser && currentUser.name ? String(currentUser.name) : ""
  readonly property string displayName: currentUser ? String(currentUser.realName || currentUser.name || "") : ""

  FormStyle {
    id: formStyle
    ui: Style.fontScale
    fontFamily: Style.font.family
    back: Commons.Color.background
    text: Commons.Color.lock.text
    bright: Commons.Color.foreground
    muted: Commons.Color.lock.placeholder
    accent: Commons.Color.lock.borderActive
    error: Commons.Color.lock.textError
    warn: Commons.Color.urgent
  }
  readonly property var pw: form.passwordBox

  readonly property var accountRows: {
    var rows = [], seen = {}
    var list = root.accounts && root.accounts.length ? root.accounts : []
    if (!list.length && root.me) {
      list = [{ name: root.me, realName: root.currentUser.realName || "", signedIn: true }]
      for (var j = 0; j < (root.otherUsers || []).length; j++)
        list.push({ name: root.otherUsers[j].name, realName: root.otherUsers[j].realName || "", signedIn: true })
    }
    for (var i = 0; i < list.length; i++) {
      var a = list[i]
      if (!a || !a.name || seen[a.name]) continue
      seen[a.name] = true
      var mine = a.name === root.me
      rows.push({ name: a.name, label: a.realName || a.name, picture: mine && root.avatarPath ? "file://" + root.avatarPath : "",
                  accent: mine ? "" : formStyle.alpha(formStyle.text, 0.55), signedIn: mine || !!a.signedIn })
    }
    return rows
  }

  // ---- password, kept in the lock logic --------------------------------------

  property bool syncing: false
  function syncPasswordText() {
    if (pw.text === passwordText) return
    syncing = true
    pw.text = passwordText
    syncing = false
  }
  onPasswordTextChanged: syncPasswordText()

  function forcePasswordFocus() { pw.focusInput() }
  function clearPassword() { passwordTextEdited("") }

  // Focus moved with Tab (account list, power buttons) is left alone;
  // anything else that takes focus away, like a VT switch around suspend,
  // hands it back to the field.
  function tabbable(item) {
    for (var it = item; it; it = it.parent) if (it === accountList || it === powerRow) return true
    return false
  }
  function restorePasswordFocus() {
    if (inputEnabled && pw.input.enabled && !pw.focused && !tabbable(Window.activeFocusItem)) forcePasswordFocus()
  }
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  Component.onCompleted: {
    // Locked while out of sight (the guard): come back through the curtain.
    if (!sessionActive) curtain.opacity = 1
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Connections {
    target: root.pw.input
    function onTextChanged() {
      var text = root.pw.text
      if (!root.syncing) root.passwordTextEdited(text)
      if (text.length > 0) root.wakeRequested()
      if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
    }
  }
  Connections {
    target: root.pw
    function onSubmitted() {
      var submitted = root.passwordText
      root.passwordTextEdited("")
      if (submitted.length > 0) root.submitPassword(submitted)
    }
    function onKeyFilter(event) {
      root.wakeRequested()
      // Waking a blanked display can stall the compositor, and a held key
      // would then repeat into the field. Only Backspace/Delete may repeat.
      if (event.isAutoRepeat && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete) {
        event.accepted = true
        return
      }
      if (event.key === Qt.Key_Escape || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U)) {
        root.passwordTextEdited("")
        event.accepted = true
      }
    }
  }

  // ---- background --------------------------------------------------------

  // The account's pre-blurred background (omarchy-greeter-sync), used only
  // when it was made from the wallpaper this lock is showing; until the sync
  // catches up after a wallpaper change, the sharp one, darker.
  FileView {
    id: publishedSource
    path: root.me ? "/var/lib/omarchy-greeter/" + root.me + "/source" : ""
    blockLoading: true
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
  }
  readonly property string sourceKey: String(publishedSource.text() || "").trim()
  readonly property bool blurMatches: root.me !== "" && backgroundPath !== "" && sourceKey.split(" ")[0] === backgroundPath
  readonly property bool video: Util.isVideoPath(backgroundPath)

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    Image {
      id: blurred
      anchors.fill: parent
      source: root.loadBackground && root.blurMatches
        ? "file:///var/lib/omarchy-greeter/" + root.me + "/background-blur.jpg?v=" + encodeURIComponent(root.sourceKey)
        : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      smooth: true
    }

    Image {
      id: sharp
      anchors.fill: parent
      visible: blurred.status !== Image.Ready
      readonly property string path: root.video ? root.videoPosterPath : root.backgroundPath
      source: root.loadBackground && !root.blurMatches && path !== ""
        ? "file://" + path + (root.backgroundVersion ? "?v=" + root.backgroundVersion : "")
        : ""
      sourceSize: Qt.size(width, height)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      smooth: true
    }

    // Flat (a gradient would band); darker over a sharp background.
    Rectangle {
      anchors.fill: parent
      color: formStyle.alpha(Commons.Color.background, blurred.status === Image.Ready ? 0.3 : 0.6)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ---- clock -----------------------------------------------------------

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: parent.height * 0.08
      spacing: 2 * formStyle.ui
      visible: root.extrasEnabled
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
        color: formStyle.bright
        font.family: formStyle.fontFamily
        font.pixelSize: 64 * formStyle.ui
        font.weight: Font.Light
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(root.now, "dddd, MMMM d")
        color: formStyle.text
        font.family: formStyle.fontFamily
        font.pixelSize: 17 * formStyle.ui
      }
    }

    // ---- the form --------------------------------------------------------

    AccountForm {
      id: form
      st: formStyle
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: parent.height * 0.03

      displayName: root.displayName
      userName: root.me
      picture: root.avatarPath ? "file://" + root.avatarPath : ""
      status: "Locked"
      statusGlyph: ""
      message: root.fingerprintConfigured
        ? (root.fingerprintUnavailable ? Commons.I18n.t("lock.fingerprintUnavailable") : "\u{f0237}  Or touch the fingerprint reader")
        : ""
      messageIsError: root.fingerprintConfigured && root.fingerprintUnavailable

      passwordBox.placeholder: root.authenticatingPassword ? Commons.I18n.t("lock.checking")
        : (root.failureMessage.length > 0 ? root.failureMessage : Commons.I18n.t("lock.enterPassword"))
      passwordBox.failed: root.failureMessage.length > 0
      passwordBox.busy: root.authenticatingPassword
      passwordBox.inputEnabled: root.inputEnabled
    }

    // ---- accounts, bottom-left ---------------------------------------------

    // Every account the login screen offers; choosing another one opens the
    // login screen with it selected, while this session stays locked.
    AccountList {
      id: accountList
      st: formStyle
      visible: root.extrasEnabled && root.accountRows.length > 1
      enabled: root.extrasEnabled
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.leftMargin: 36 * formStyle.ui
      anchors.bottomMargin: 36 * formStyle.ui
      accounts: root.accountRows
      selected: root.me
      onChosen: (name) => {
        root.wakeRequested()
        if (name === root.me) root.forcePasswordFocus()
        else root.leaveFor(name)
      }
      onTyped: (text) => {
        root.forcePasswordFocus()
        root.passwordTextEdited(root.passwordText + text)
      }
    }

    // ---- machine, top-left; power, bottom-right ------------------------------

    FileView {
      id: hostFile
      path: "/etc/hostname"
      blockLoading: true
      printErrors: false
    }
    Text {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: 28 * formStyle.ui
      readonly property string host: String(hostFile.text() || "").trim()
      visible: root.extrasEnabled && host !== ""
      textFormat: Text.PlainText
      text: "\uf108  " + host
      color: formStyle.alpha(formStyle.bright, 0.8)
      font.family: formStyle.fontFamily
      font.pixelSize: 14 * formStyle.ui
    }

    Row {
      id: powerRow
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 28 * formStyle.ui
      spacing: 8 * formStyle.ui
      visible: root.extrasEnabled
      enabled: root.extrasEnabled

      PowerButton {
        st: formStyle
        glyph: "\u{f04b2}"
        label: "Sleep"
        onClicked: { root.wakeRequested(); root.powerRequested("suspend") }
      }
      PowerButton {
        st: formStyle
        glyph: "\u{f0709}"
        label: "Restart"
        onClicked: root.powerRequested("reboot")
      }
      PowerButton {
        st: formStyle
        glyph: "\u{f0425}"
        label: "Shut down"
        hoverInk: formStyle.error
        onClicked: root.powerRequested("poweroff")
      }
    }
  }

  // ---- switching user ------------------------------------------------------
  //
  // Switching to another account hands the monitors to its session, and the
  // monitors reset and re-sync on the way (about a second or two of no new
  // picture, more on some monitors, nothing software can skip). So it is made
  // to look intended, like Windows' "Switching user":
  //  - leaving, the screen fades to black with "Switching to <name>" and the
  //    switch happens on plain black, so this session's last picture is black
  //    and coming back to it never shows a stale, frozen lock screen;
  //  - out of sight, the curtain stays down;
  //  - arriving, it lifts only once frames are flowing smoothly again (the
  //    resets are over), and the password field has the keyboard.
  // If a switch does not happen, the screen comes back after a few seconds.
  property string leavingLabel: ""
  // Timing of a switch in the journal (omarchy-shell), to tune it by.
  function note(text) { console.log("omarchy lock " + new Date().toISOString() + " " + text) }
  readonly property string myLabel: {
    for (var i = 0; i < root.accountRows.length; i++)
      if (root.accountRows[i].name === root.me) return root.accountRows[i].label
    return root.me
  }
  NumberAnimation { id: arrivingText; target: curtainText; property: "opacity"; to: 1; duration: 200 }
  readonly property bool curtainDown: curtain.opacity > 0
  function leaveFor(name) {
    if (leaving.running || curtain.opacity > 0) return
    var label = name
    for (var i = 0; i < root.accountRows.length; i++)
      if (root.accountRows[i].name === name) label = root.accountRows[i].label
    root.leavingLabel = label
    leaving.target = name
    leaving.start()
  }
  onSessionActiveChanged: {
    if (!sessionActive) {
      leaving.stop()
      lifting.stop()
      notSwitched.stop()
      curtain.opacity = 1
      curtainText.opacity = 0
      arrivingText.stop()
      arrival.active = false
      root.leavingLabel = ""
      root.note("curtain: away")
    } else if (curtain.opacity > 0) {
      arrival.begin()
    }
  }

  SequentialAnimation {
    id: leaving
    property string target: ""
    ParallelAnimation {
      NumberAnimation { target: curtain; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
      NumberAnimation { target: curtainText; property: "opacity"; to: 1; duration: 220 }
    }
    PauseAnimation { duration: 280 }
    NumberAnimation { target: curtainText; property: "opacity"; to: 0; duration: 140 }
    // One more frame of plain black before the switch.
    PauseAnimation { duration: 60 }
    ScriptAction {
      script: {
        root.switchUserRequested(leaving.target)
        notSwitched.restart()
      }
    }
  }
  Timer {
    id: notSwitched
    interval: 3000
    onTriggered: if (root.sessionActive) lifting.start()
  }

  // Frames flow at the monitor's rate once the resets are over; while one is
  // under way, none arrive. Lift after a steady run of frames, or at most
  // after a few seconds whatever happens.
  QtObject {
    id: arrival
    property bool active: false
    property real since: 0
    property int steady: 0
    property int frames: 0
    property real firstFrame: 0
    property real longest: 0
    function begin() {
      arrival.since = Date.now()
      arrival.steady = 0
      arrival.frames = 0
      arrival.firstFrame = 0
      arrival.longest = 0
      arrival.active = true
      arrivalCap.restart()
      root.note("curtain: back")
    }
    function done(why) {
      if (!arrival.active) return
      arrival.active = false
      arrivalCap.stop()
      root.note("curtain: lifting (" + why + ") after " + (Date.now() - arrival.since) + " ms; "
        + arrival.frames + " frames, first at " + (arrival.firstFrame ? arrival.firstFrame - arrival.since : -1)
        + " ms, longest gap " + Math.round(arrival.longest * 1000) + " ms")
      lifting.start()
    }
  }
  FrameAnimation {
    running: arrival.active
    onTriggered: {
      if (++arrival.frames === 1) arrival.firstFrame = Date.now()
      else arrival.longest = Math.max(arrival.longest, frameTime)
      // The first frame's time spans the whole time away: not a gap.
      arrival.steady = arrival.frames > 1 && frameTime < 0.05 ? arrival.steady + 1 : 0
      if (arrival.steady >= 20 && Date.now() - arrival.since >= 350) arrival.done("steady")
      // Text on the black while waiting, so it never looks stuck.
      if (arrival.frames === 2) arrivingText.start()
    }
  }
  Timer {
    id: arrivalCap
    interval: 4000
    onTriggered: arrival.done("cap")
  }
  NumberAnimation {
    id: lifting
    target: curtain
    property: "opacity"
    to: 0
    duration: 320
    easing.type: Easing.InOutQuad
    onStarted: {
      root.forcePasswordFocus()
      root.arrived()
    }
  }

  Rectangle {
    id: curtain
    anchors.fill: parent
    z: 1000
    color: "#000000"
    opacity: 0
    visible: opacity > 0
    // Nothing underneath is clickable while it is down.
    MouseArea { anchors.fill: parent; hoverEnabled: true }
    Text {
      id: curtainText
      anchors.centerIn: parent
      opacity: 0
      visible: root.extrasEnabled
      text: root.leavingLabel !== "" ? "Switching to " + root.leavingLabel + "\u2026" : "Welcome back, " + root.myLabel
      textFormat: Text.PlainText
      color: formStyle.alpha(formStyle.bright, 0.85)
      font.family: formStyle.fontFamily
      font.pixelSize: 22 * formStyle.ui
    }
  }

}
