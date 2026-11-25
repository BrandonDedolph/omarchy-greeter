import QtQuick
import QtQuick.Effects

// Round avatar: the user's published picture, their SDDM face icon, or their
// initials on the accent color.
Item {
  id: avatar

  property string picture: ""     // file url to try first
  property string faceIcon: ""    // SDDM's model.icon
  property string label: ""       // real name or username, for initials
  property color accent: "#7aa2f7"
  property color ink: "#1a1b26"
  property color ring: accent
  property real ringWidth: 3
  property string fontFamily: "monospace"

  readonly property string usableFace: faceIcon && faceIcon.indexOf("/usr/share/sddm/faces/") === -1 ? faceIcon : ""
  readonly property bool hasImage: photo.status === Image.Ready

  function initials(text) {
    var parts = String(text || "?").replace(/[._-]+/g, " ").trim().split(/\s+/)
    var out = parts[0].charAt(0) + (parts.length > 1 ? parts[parts.length - 1].charAt(0) : "")
    return out.toUpperCase()
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: avatar.accent
    Behavior on color { ColorAnimation { duration: 600 } }

    Text {
      anchors.centerIn: parent
      visible: !avatar.hasImage
      text: avatar.initials(avatar.label)
      textFormat: Text.PlainText
      color: avatar.ink
      font.family: avatar.fontFamily
      font.pixelSize: avatar.height * 0.36
      font.bold: true
    }
  }

  Image {
    id: photo
    anchors.fill: parent
    anchors.margins: avatar.ringWidth
    sourceSize: Qt.size(256, 256)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    smooth: true
    visible: false
    onStatusChanged: if (status === Image.Error && source == avatar.picture && avatar.usableFace) source = avatar.usableFace
  }
  onPictureChanged: photo.source = picture || usableFace
  Component.onCompleted: photo.source = picture || usableFace

  Rectangle {
    id: roundMask
    anchors.fill: photo
    radius: width / 2
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: photo
    source: photo
    visible: avatar.hasImage
    maskEnabled: true
    maskSource: roundMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    border.color: avatar.ring
    border.width: avatar.ringWidth
    Behavior on border.color { ColorAnimation { duration: 300 } }
  }
}
