import QtQuick

// The keyboard-focus outline: a solid accent ring just outside the item plus
// a soft halo, so it is plain which control Tab is on.
Item {
  id: ring
  property FormStyle st
  property bool shown: false
  property real radius: 0

  anchors.fill: parent
  anchors.margins: -4 * st.ui
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 120 } }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3 * ring.st.ui
    radius: ring.radius + 7 * ring.st.ui
    color: "transparent"
    border.width: 3 * ring.st.ui
    border.color: ring.st.alpha(ring.st.accent, 0.35)
  }
  Rectangle {
    anchors.fill: parent
    radius: ring.radius + 4 * ring.st.ui
    color: "transparent"
    border.width: 2 * ring.st.ui
    border.color: ring.st.accent
  }
}
