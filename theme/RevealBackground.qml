import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A still wallpaper that changes with the same slanted reveal the Omarchy
// desktop uses when you switch backgrounds.
Item {
  id: bg

  property string source: ""
  property color fallbackColor: "#1a1b26"
  property size decodeSize: Qt.size(width, height)

  property string shown: ""
  property string incoming: ""
  property real progress: 1
  property bool finishing: false
  // Off: changes show at once (no fade or reveal), e.g. while loading.
  property bool animate: true
  // The current picture is on screen (or there is none to wait for).
  readonly property bool ready: shown === "" ? source === "" : (base.status === Image.Ready || base.status === Image.Error)

  function settle() {
    if (finishing && base.status === Image.Ready && String(base.source) === shown) {
      incoming = ""
      finishing = false
    }
  }

  onSourceChanged: {
    if (!animate) {
      reveal.stop()
      incoming = ""
      progress = 1
      shown = source
      return
    }
    if (reveal.running) {
      reveal.stop()
      shown = incoming
    }
    if (source === shown) {
      incoming = ""
      return
    }
    // Nothing on screen yet, or nothing to reveal: swap directly (fades in).
    if (!shown || !source || base.status !== Image.Ready) {
      incoming = ""
      shown = source
      return
    }
    progress = 0
    finishing = false
    incoming = source
    if (incomingImage.status === Image.Ready) reveal.restart()
  }

  Rectangle {
    anchors.fill: parent
    color: bg.fallbackColor
    Behavior on color { enabled: bg.animate; ColorAnimation { duration: 600 } }
  }

  Image {
    id: base
    anchors.fill: parent
    source: bg.shown
    sourceSize: bg.decodeSize
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    smooth: true
    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity { enabled: bg.animate; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    onStatusChanged: bg.settle()
  }

  Item {
    id: incomingLayer
    anchors.fill: parent
    visible: bg.incoming !== "" && incomingImage.status === Image.Ready
    layer.enabled: visible && bg.progress < 1
    layer.smooth: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 0.02
    }

    Image {
      id: incomingImage
      anchors.fill: parent
      source: bg.incoming
      sourceSize: bg.decodeSize
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      smooth: true
      onStatusChanged: {
        if (status === Image.Ready && bg.incoming !== "" && bg.progress === 0) reveal.restart()
        // An unreadable image is skipped rather than left half-revealed.
        if (status === Image.Error && bg.incoming !== "") bg.incoming = ""
      }
    }
  }

  Item {
    id: mask
    anchors.fill: parent
    visible: false
    layer.enabled: true

    readonly property real slant: -0.18
    readonly property real centerTop: width / 2 - slant * height / 2
    readonly property real centerBottom: width / 2 + slant * height / 2
    readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
    readonly property real spread: reach * bg.progress

    Shape {
      anchors.fill: parent
      antialiasing: true
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: "white"
        strokeColor: "transparent"
        startX: mask.centerTop - mask.spread; startY: 0
        PathLine { x: mask.centerTop + mask.spread; y: 0 }
        PathLine { x: mask.centerBottom + mask.spread; y: mask.height }
        PathLine { x: mask.centerBottom - mask.spread; y: mask.height }
        PathLine { x: mask.centerTop - mask.spread; y: 0 }
      }
    }
  }

  NumberAnimation {
    id: reveal
    target: bg
    property: "progress"
    from: 0
    to: 1
    duration: 840
    easing.type: Easing.OutCubic
    onFinished: {
      bg.shown = bg.incoming
      bg.finishing = true
      // A cached image can be ready without a status change.
      Qt.callLater(bg.settle)
    }
  }
}
