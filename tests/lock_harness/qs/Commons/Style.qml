pragma Singleton
import QtQuick
// Stand-in for Omarchy's Style (only what the lock layout reads).
QtObject {
  readonly property real fontScale: 1
  readonly property int cornerRadius: 0
  readonly property QtObject font: QtObject {
    readonly property string family: "monospace"
    readonly property int heading: 16
  }
}
