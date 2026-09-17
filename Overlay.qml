import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string mode: "on"
  property int workspace: 0

  readonly property string onImage: Qt.resolvedUrl("share/omansory/on.jpg")
  readonly property string offImage: Qt.resolvedUrl("share/omansory/off.jpg")

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) { payload = {} }
    root.mode = payload.mode === "off" ? "off" : "on"
    root.workspace = Number(payload.workspace || 0)
    root.opened = true
    hideTimer.restart()
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "omansory")
    else close()
  }

  Timer {
    id: hideTimer
    interval: 2200
    repeat: false
    onTriggered: root.dismiss()
  }

  PanelWindow {
    visible: root.opened
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omansory-flash"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0.05, 0, 0.12, 0.42)
      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      anchors.centerIn: parent
      width: Math.min(parent.width * 0.62, 920)
      height: width * 9 / 16

      Image {
        anchors.fill: parent
        source: root.mode === "off" ? root.offImage : root.onImage
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#05d9e8"
        border.width: 2
        radius: 4
      }
    }
  }
}
