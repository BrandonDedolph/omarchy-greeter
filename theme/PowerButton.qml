import QtQuick

// Sleep / Restart / Shut down, bottom-right. Reachable with Tab; Enter or
// Space presses it.
Item {
  id: button
  property FormStyle st
  property string glyph: ""
  property string label: ""
  property color hoverInk: st.accent
  signal clicked()

  width: row.width + 22 * st.ui
  height: 40 * st.ui
  activeFocusOnTab: true

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      if (!event.isAutoRepeat) button.clicked()
      event.accepted = true
    }
  }

  readonly property bool lit: mouse.containsMouse || activeFocus

  FocusRing { st: button.st; radius: 8 * button.st.ui; shown: button.activeFocus }

  Rectangle {
    anchors.fill: parent
    radius: 8 * button.st.ui
    color: button.hoverInk
    opacity: button.lit ? 0.16 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 8 * button.st.ui
    Text {
      text: button.glyph
      color: button.lit ? button.hoverInk : button.st.alpha(button.st.text, 0.85)
      font.family: button.st.fontFamily
      font.pixelSize: 18 * button.st.ui
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: button.label
      color: button.lit ? button.hoverInk : button.st.alpha(button.st.text, 0.85)
      font.family: button.st.fontFamily
      font.pixelSize: 14 * button.st.ui
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
