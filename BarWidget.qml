import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omansory"

  property bool masonryOn: false
  property int activeWorkspace: 0
  property var masonryWorkspaces: []
  property string packKind: ""
  property bool pulse: false

  readonly property bool centerMode: masonryOn && packKind === "center"
  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  readonly property color accent: "#ff71ce"
  readonly property color ink: masonryOn ? accent : Qt.darker(barForeground, 1.55)
  readonly property string tooltipText: {
    if (!masonryOn) return "Omansory off — click to pack this workspace"
    if (centerMode) return "Central Mode — workspace " + (activeWorkspace || "?") + " — click to restore"
    return "Masonry Mode — workspace " + (activeWorkspace || "?") + " — click to restore"
  }

  visible: true
  implicitWidth: vertical ? barSize : layout.implicitWidth + Style.spaceReal(8)
  implicitHeight: vertical ? layout.implicitHeight + Style.spaceReal(8) : barSize

  function helper() {
    var value = String(Qt.resolvedUrl("bin/omansory") || "")
    if (value.indexOf("file://") === 0) {
      value = decodeURIComponent(value.substring(7))
      if (value.charAt(0) !== "/") value = "/" + value
    }
    return value
  }

  function applyStatus(raw) {
    var parsed = {}
    try { parsed = JSON.parse(raw || "{}") || {} } catch (e) { parsed = {} }
    var wasOn = masonryOn
    var wasKind = packKind
    masonryOn = parsed.active === true
    activeWorkspace = Number(parsed.workspace || 0)
    masonryWorkspaces = parsed.workspaces || []
    packKind = String(parsed.kind || "")
    if (wasOn !== masonryOn || wasKind !== packKind) {
      pulse = true
      pulseTimer.restart()
    }
  }

  function refresh() {
    if (statusProc.running) return
    var path = helper()
    if (path === "") return
    statusProc.command = [path, "status", "--json"]
    statusProc.running = true
  }

  function toggle() {
    if (!root.bar) return
    root.bar.run(helper() + " toggle")
    refreshTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: 500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: pulseTimer
    interval: 1400
    repeat: false
    onTriggered: root.pulse = false
  }

  Process {
    id: statusProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    tooltipText: root.tooltipText
    dimmed: !root.masonryOn
    active: root.masonryOn
    useActiveColor: false
    implicitWidth: root.implicitWidth
    implicitHeight: root.implicitHeight
    onPressed: function() { root.toggle() }

    Row {
      id: layout
      anchors.centerIn: parent
      spacing: Style.space(6)

      Item {
        id: glyphBox
        width: Style.bar.iconFont
        height: Style.bar.iconFont
        anchors.verticalCenter: parent.verticalCenter
        scale: root.pulse ? 1.18 : 1.0
        Behavior on scale { NumberAnimation { duration: 180 } }

        property real gap: Math.max(1, width * 0.10)
        property real cell: (width - gap * 3) / 2

        Repeater {
          model: root.centerMode ? 0 : 4
          Rectangle {
            required property int index
            x: glyphBox.gap + (index % 2) * (glyphBox.cell + glyphBox.gap)
            y: glyphBox.gap + Math.floor(index / 2) * (glyphBox.cell + glyphBox.gap)
            width: glyphBox.cell
            height: glyphBox.cell
            radius: 1
            color: root.ink
            Behavior on color { ColorAnimation { duration: 180 } }
          }
        }

        Rectangle {
          visible: root.centerMode
          anchors.fill: parent
          anchors.margins: 1
          color: "transparent"
          border.width: Math.max(1.5, glyphBox.gap)
          border.color: root.ink
          radius: 2
          Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
          visible: root.centerMode
          anchors.centerIn: parent
          width: parent.width * 0.42
          height: parent.height * 0.42
          radius: 1
          color: root.ink
          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }
    }
  }
}
