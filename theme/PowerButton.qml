import QtQuick

Item {
  id: button
  property string glyph: ""
  property string label: ""
  property color ink: "#a9b1d6"
  property color hoverInk: "#7aa2f7"
  property string fontFamily: "monospace"
  signal clicked()

  width: row.width + 20
  height: 36

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: button.hoverInk
    opacity: mouse.containsMouse ? 0.16 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 8
    Text {
      text: button.glyph
      color: mouse.containsMouse ? button.hoverInk : button.ink
      font.family: button.fontFamily
      font.pixelSize: 18
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: button.label
      color: mouse.containsMouse ? button.hoverInk : button.ink
      font.family: button.fontFamily
      font.pixelSize: 14
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
