pragma Singleton
import QtQuick
// Stand-in for Omarchy's Color.
QtObject {
  property color foreground: "#c0caf5"
  property color background: "#1a1b26"
  property color accent: "#7aa2f7"
  property color urgent: "#f7768e"
  readonly property QtObject lock: QtObject {
    property color background: "#cc1a1b26"
    property color text: "#a9b1d6"
    property color placeholder: "#a8a9b1d6"
    property color textError: "#f7768e"
    property color border: "#a9b1d6"
    property color borderActive: "#7aa2f7"
    property color borderError: "#f7768e"
    property color selection: "#737aa2f7"
  }
}
