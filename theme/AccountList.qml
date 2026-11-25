import QtQuick

// Every account, bottom-left, as on Windows: avatar, name, and "Signed in"
// for accounts with a session running. Tab reaches each row; Up/Down move
// between rows; Enter or Space chooses; typing goes back to the password.
Column {
  id: list

  property FormStyle st
  // [{ name, label, picture, faceIcon, accent, ink, signedIn }]
  property var accounts: []
  property string selected: ""

  signal chosen(string name)
  // A printable key typed on a row: the password box should take it.
  signal typed(string text)

  spacing: 4 * st.ui

  function focusRow(i) {
    if (i < 0 || i >= rows.count) return
    var row = rows.itemAt(i)
    if (row) row.forceActiveFocus()
  }

  Repeater {
    id: rows
    model: list.accounts

    Item {
      id: row
      required property var modelData
      required property int index
      readonly property bool isSelected: modelData.name === list.selected
      width: 280 * list.st.ui
      height: 56 * list.st.ui
      activeFocusOnTab: true

      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          if (!event.isAutoRepeat) list.chosen(row.modelData.name)
          event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          list.focusRow(row.index + 1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          list.focusRow(row.index - 1)
          event.accepted = true
        } else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier)) {
          list.typed(event.text)
          event.accepted = true
        }
      }

      FocusRing { st: list.st; radius: 10 * list.st.ui; shown: row.activeFocus }

      Rectangle {
        anchors.fill: parent
        radius: 10 * list.st.ui
        color: row.isSelected ? list.st.alpha(list.st.bright, 0.16)
                              : (mouse.containsMouse ? list.st.alpha(list.st.bright, 0.09) : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
      }

      UserAvatar {
        id: face
        anchors.left: parent.left
        anchors.leftMargin: 8 * list.st.ui
        anchors.verticalCenter: parent.verticalCenter
        width: 40 * list.st.ui
        height: width
        ringWidth: 2 * list.st.ui
        picture: row.modelData.picture || ""
        faceIcon: row.modelData.faceIcon || ""
        label: row.modelData.label || row.modelData.name
        accent: row.modelData.accent || list.st.accent
        ink: row.modelData.ink || list.st.back
        ring: row.isSelected ? list.st.bright : "transparent"
        fontFamily: list.st.fontFamily
      }

      Column {
        anchors.left: face.right
        anchors.leftMargin: 12 * list.st.ui
        anchors.right: parent.right
        anchors.rightMargin: 8 * list.st.ui
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1 * list.st.ui
        Text {
          width: parent.width
          text: row.modelData.label || row.modelData.name
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: list.st.bright
          font.family: list.st.fontFamily
          font.pixelSize: 15 * list.st.ui
          font.bold: row.isSelected
        }
        Text {
          visible: !!row.modelData.signedIn
          text: "Signed in"
          color: list.st.alpha(list.st.text, 0.8)
          font.family: list.st.fontFamily
          font.pixelSize: 12 * list.st.ui
        }
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: list.chosen(row.modelData.name)
      }
    }
  }
}
