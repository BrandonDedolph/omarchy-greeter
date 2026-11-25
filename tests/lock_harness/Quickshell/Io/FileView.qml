import QtQuick
// Stand-in for Quickshell's FileView: no file contents.
QtObject {
  property string path: ""
  property bool blockLoading: false
  property bool printErrors: true
  property bool watchChanges: false
  signal fileChanged()
  function reload() {}
  function text() { return "" }
}
