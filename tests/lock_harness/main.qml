import QtQuick
import QtQuick.Window

// Loads the generated LockView.qml the way Omarchy's lock logic does, checks
// what it shows and that values and signals pass through, saves a picture
// ($HARNESS_SHOT) and quits. Run by tests/test_lock_view.sh, off-screen.
Window {
  id: win
  width: 1600
  height: 900
  visible: true

  property var events: []
  function note(text) { events.push(text) }

  LockView {
    id: view
    anchors.fill: parent
    backgroundPath: ""
    inputEnabled: true
    loadBackground: true
    currentUser: ({ name: "alex", realName: "Alex Rivera" })
    accounts: [{ name: "alex", realName: "Alex Rivera", signedIn: true },
               { name: "sam", realName: "Sam Chen", signedIn: true },
               { name: "kim", realName: "", signedIn: false }]
    onPasswordTextEdited: function(password) { win.note("edited:" + password); view.passwordText = password }
    onSubmitPassword: function(password) { win.note("submit:" + password) }
    onSwitchUserRequested: function(name) { win.note("switch:" + name) }
    onPowerRequested: function(action) { win.note("power:" + action) }
  }

  Timer {
    interval: 400
    running: true
    onTriggered: {
      console.warn("harness: layout=" + view.loadedLayout)
      var l = view.layout
      if (l && l.pw) {
        view.passwordText = "abc"
        console.warn("harness: into-layout=" + l.pw.text)
        l.pw.text = "abcd"
        l.pw.submitted()
        console.warn("harness: rows=" + (l.accountRows ? l.accountRows.length : -1))
        l.switchUserRequested("sam")
        l.powerRequested("suspend")
      }
      console.warn("harness: events=" + win.events.join(","))
      var shot = Qt.application.arguments[Qt.application.arguments.length - 1]
      if (/\.png$/.test(shot)) {
        if (l && l.pw) { view.passwordText = "hunter22" }
        win.contentItem.grabToImage(function(result) {
          result.saveToFile(shot)
          Qt.quit()
        })
      } else {
        Qt.quit()
      }
    }
  }
}
