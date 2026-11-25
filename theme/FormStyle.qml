import QtQuick

// Colors, font and scale for the shared form (login screen and lock screen).
// Each screen fills this from its own theme; the form never imports either.
QtObject {
  property real ui: 1                 // size multiplier (1 = Omarchy's 12px font at scale 1)
  property string fontFamily: "monospace"
  property color back: "#1a1b26"      // theme background
  property color text: "#a9b1d6"
  property color bright: "#c0caf5"
  property color muted: "#565f89"
  property color accent: "#7aa2f7"
  property color error: "#f7768e"
  property color warn: "#e0af68"

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
