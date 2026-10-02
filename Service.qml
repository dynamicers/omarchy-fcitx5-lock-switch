import QtQuick
import Quickshell.Io

Item {
  id: root

  // The lock service is private to Omarchy. Its public IPC reports the lock
  // request before the session-lock surface appears.
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
