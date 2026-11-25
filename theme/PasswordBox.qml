import QtQuick

// The password field: dots for what is typed (length shows, text never
// does), a submit arrow, a busy indicator while the password is checked, a
// Caps Lock warning, and a strong ring while it has keyboard focus.
Item {
  id: box

  property FormStyle st
  property string placeholder: "Password"
  property bool failed: false          // last attempt was wrong: red, message as placeholder
  property bool busy: false            // password being checked
  property bool capsOn: false
  property bool openLock: false        // the boot pass applies: open padlock, Enter alone logs in
  property bool inputEnabled: true

  property alias text: input.text
  readonly property alias input: input
  readonly property bool focused: input.activeFocus

  // Every key press, before the box handles it; set event.accepted to stop it.
  signal keyFilter(var event)
  signal submitted()

  function focusInput() { input.forceActiveFocus() }

  width: 380 * st.ui
  height: 52 * st.ui

  property real shakeOffset: 0
  transform: Translate { x: box.shakeOffset }
  function shake() { shakeAnim.restart() }
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: box; property: "shakeOffset"; to: -12 * box.st.ui; duration: 50 }
    NumberAnimation { target: box; property: "shakeOffset"; to: 10 * box.st.ui; duration: 70 }
    NumberAnimation { target: box; property: "shakeOffset"; to: -6 * box.st.ui; duration: 70 }
    NumberAnimation { target: box; property: "shakeOffset"; to: 0; duration: 60 }
  }

  readonly property real radius: 10 * st.ui

  FocusRing { st: box.st; radius: box.radius; shown: box.focused }

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: box.radius
    color: box.st.alpha(box.st.back, 0.82)
    border.width: (box.focused ? 2 : 1) * box.st.ui
    border.color: box.failed ? box.st.error : (box.focused ? box.st.accent : box.st.alpha(box.st.text, 0.28))
    Behavior on border.color { ColorAnimation { duration: 150 } }
  }

  // Padlock (open while the boot pass applies).
  Text {
    id: padlock
    anchors.left: parent.left
    anchors.leftMargin: 18 * box.st.ui
    anchors.verticalCenter: parent.verticalCenter
    text: box.openLock && !box.failed ? "" : ""
    color: box.failed ? box.st.error : (box.focused ? box.st.accent : box.st.muted)
    font.family: box.st.fontFamily
    font.pixelSize: 17 * box.st.ui
  }

  // Placeholder, or the reason the last attempt failed.
  Text {
    anchors.left: padlock.right
    anchors.leftMargin: 14 * box.st.ui
    anchors.right: trailing.left
    anchors.rightMargin: 8 * box.st.ui
    anchors.verticalCenter: parent.verticalCenter
    visible: input.text.length === 0 && !box.busy
    text: box.placeholder
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: box.failed ? box.st.error : box.st.alpha(box.st.text, 0.7)
    font.family: box.st.fontFamily
    font.pixelSize: 15 * box.st.ui
  }

  // Dots and caret, centered on the box's middle line.
  Item {
    id: dotsArea
    anchors.left: padlock.right
    anchors.leftMargin: 15 * box.st.ui
    anchors.right: trailing.left
    anchors.rightMargin: 8 * box.st.ui
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    clip: true
    visible: !box.busy

    readonly property real dot: 9 * box.st.ui
    readonly property real gap: 6 * box.st.ui
    // Shrink the dots once a long password would overflow, so every key
    // press still shows.
    readonly property real fit: input.text.length > 0
      ? Math.min(1, (width - 6 * box.st.ui) / (input.text.length * (dot + gap)))
      : 1

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: dotsArea.gap * dotsArea.fit
      Repeater {
        model: input.text.length
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(2, dotsArea.dot * dotsArea.fit)
          height: width
          radius: width / 2
          color: box.st.bright
        }
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 2 * box.st.ui
        height: 20 * box.st.ui
        color: box.st.accent
        visible: box.focused && box.inputEnabled
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: box.focused
          NumberAnimation { to: 0; duration: 530 }
          NumberAnimation { to: 1; duration: 530 }
        }
      }
    }
  }

  // Busy: three pulsing dots while the password is checked.
  Row {
    anchors.centerIn: parent
    spacing: 10 * box.st.ui
    visible: box.busy
    Repeater {
      model: 3
      Rectangle {
        required property int index
        width: 9 * box.st.ui
        height: width
        radius: width / 2
        color: box.st.accent
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: box.busy
          PauseAnimation { duration: index * 160 }
          NumberAnimation { from: 0.25; to: 1; duration: 320 }
          NumberAnimation { from: 1; to: 0.25; duration: 320 }
          PauseAnimation { duration: (2 - index) * 160 }
        }
      }
    }
  }

  // Caps Lock warning and the submit arrow, at the right end.
  Row {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: 6 * box.st.ui
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6 * box.st.ui

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: box.capsOn
      height: 24 * box.st.ui
      width: capsText.width + 14 * box.st.ui
      radius: 6 * box.st.ui
      color: box.st.alpha(box.st.warn, 0.18)
      border.color: box.st.warn
      border.width: 1
      Text {
        id: capsText
        anchors.centerIn: parent
        text: "⇪ CAPS"
        color: box.st.warn
        font.family: box.st.fontFamily
        font.pixelSize: 11 * box.st.ui
        font.bold: true
      }
    }

    Rectangle {
      id: arrow
      anchors.verticalCenter: parent.verticalCenter
      width: 40 * box.st.ui
      height: width
      radius: 8 * box.st.ui
      readonly property bool ready: box.inputEnabled && !box.busy && (input.text.length > 0 || box.openLock)
      color: arrowMouse.containsMouse && ready ? box.st.accent : box.st.alpha(box.st.accent, ready ? 0.22 : 0.08)
      Behavior on color { ColorAnimation { duration: 120 } }
      Text {
        anchors.centerIn: parent
        text: ""
        color: arrowMouse.containsMouse && arrow.ready ? box.st.back : (arrow.ready ? box.st.bright : box.st.alpha(box.st.text, 0.35))
        font.family: box.st.fontFamily
        font.pixelSize: 16 * box.st.ui
      }
      MouseArea {
        id: arrowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: arrow.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (arrow.ready) box.submitted()
      }
    }
  }

  // The real input: invisible, it only holds the text and the focus.
  TextInput {
    id: input
    anchors.fill: dotsArea
    echoMode: TextInput.Password
    color: "transparent"
    selectionColor: "transparent"
    selectedTextColor: "transparent"
    cursorDelegate: Item {}
    readOnly: box.busy
    enabled: box.inputEnabled
    activeFocusOnTab: true
    activeFocusOnPress: true

    Keys.onPressed: (event) => {
      box.keyFilter(event)
      if (event.accepted) return
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        box.submitted()
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        text = ""
        event.accepted = true
      }
    }
  }

  MouseArea {
    anchors.left: parent.left
    anchors.right: trailing.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    cursorShape: Qt.IBeamCursor
    onClicked: input.forceActiveFocus()
  }
}
