pragma Singleton
import QtQuick
QtObject {
  function isVideoPath(path) { return /\.(mp4|webm|mkv|mov|m4v)$/i.test(String(path || "")) }
}
