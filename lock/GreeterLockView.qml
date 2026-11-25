import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons

// omarchy-greeter's lock layout: the same Windows-style form as the login
// screen (AccountForm.qml, shared), every account bottom-left, and the
// account's pre-blurred background.
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
  // Locking is opening the login screen: show only the background and clock
  // so the form appears once, there. Turns off if the login screen does not
  // take over.
  property bool handingOff: false
  onHandingOffChanged: if (!handingOff && inputEnabled) Qt.callLater(forcePasswordFocus)
  signal switchUserRequested(string name)

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

  // Focus on the account list (Tab) is left alone; anything else that takes
  // focus away, like a VT switch around suspend, hands it back to the field.
  function inAccountList(item) {
    for (var it = item; it; it = it.parent) if (it === accountList) return true
    return false
  }
  function restorePasswordFocus() {
    if (inputEnabled && pw.input.enabled && !pw.focused && !inAccountList(Window.activeFocusItem)) forcePasswordFocus()
  }
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  Component.onCompleted: {
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
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 250 } }
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
      visible: !root.handingOff
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
      visible: root.extrasEnabled && !root.handingOff && root.accountRows.length > 1
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
        else root.switchUserRequested(name)
      }
      onTyped: (text) => {
        root.forcePasswordFocus()
        root.passwordTextEdited(root.passwordText + text)
      }
    }
  }
}
