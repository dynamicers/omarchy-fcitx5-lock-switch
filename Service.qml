import QtQuick
import Quickshell.Io

Item {
  id: root

  // Follow journal events because the built-in lock service is private.
  Process {
    id: monitor
    command: ["bash", decodeURIComponent(Qt.resolvedUrl("monitor.sh").toString().replace(/^file:\/\//, ""))]
    running: true
    onExited: restartMonitor.restart()
  }

  Timer {
    id: restartMonitor
    interval: 1000
    onTriggered: monitor.running = true
  }
}
