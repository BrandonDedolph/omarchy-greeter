import QtQuick
import QtMultimedia

// Plays a video background muted and looped over its still. Loaded through a
// Loader so a system without working Qt Multimedia just keeps the still.
Item {
  id: layer
  property url source

  opacity: player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 800 } }

  MediaPlayer {
    id: player
    source: layer.source
    loops: MediaPlayer.Infinite
    videoOutput: output
    onSourceChanged: if (source != "") play()
    Component.onCompleted: if (source != "") play()
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
  }
}
