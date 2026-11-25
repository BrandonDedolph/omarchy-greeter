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
      // Tab from the password box: wherever it lands must keep focus (the
      // lock pulls focus back to the field only when it went elsewhere).
      if (l && l.pw) {
        l.forcePasswordFocus()
        var hops = []
        win.tabTargets = []
        var item = l.pw.input
        for (var i = 0; i < 6; i++) {
          item = item.nextItemInFocusChain(true)
          if (!item || item === l.pw.input) break
          win.tabTargets.push(item)
        }
        win.tabIndex = 0
        tabStep.start()
        return
      }
      win.finish(l)
    }
  }

  property var tabTargets: []
  property int tabIndex: 0
  property var tabResults: []
  Timer {
    id: tabStep
    interval: 60
    onTriggered: {
      var l = view.layout
      if (win.tabIndex > 0) {
        var want = win.tabTargets[win.tabIndex - 1]
        win.tabResults.push(win.activeFocusItem === want ? "kept" : "lost")
      }
      if (win.tabIndex < win.tabTargets.length) {
        win.tabTargets[win.tabIndex].forceActiveFocus(Qt.TabFocusReason)
        win.tabIndex++
        tabStep.start()
        return
      }
      console.warn("harness: tab=" + win.tabResults.join(","))
      win.finish(l)
    }
  }

  function finish(l) {
    {
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
