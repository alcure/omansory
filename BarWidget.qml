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
  property bool pulse: false

  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  readonly property color accent: "#ff71ce"
  readonly property string glyph: "󰕰"
  readonly property string wsLabel: {
    if (!masonryOn || masonryWorkspaces.length === 0) return ""
    var parts = []
    for (var i = 0; i < masonryWorkspaces.length; i++) parts.push(String(masonryWorkspaces[i]))
    return parts.join("·")
  }
  readonly property string tooltipText: {
    if (masonryOn) return "Omansory on workspace " + (activeWorkspace || "?") + " — click to restore"
    return "Omansory off — click to pack this workspace"
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
    var was = masonryOn
    masonryOn = parsed.active === true
    activeWorkspace = Number(parsed.workspace || 0)
    masonryWorkspaces = parsed.workspaces || []
    if (was !== masonryOn) {
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

      Text {
        textFormat: Text.PlainText
        text: root.glyph
        color: root.masonryOn ? root.accent : Qt.darker(root.barForeground, 1.55)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Style.bar.iconFont
        anchors.verticalCenter: parent.verticalCenter
        scale: root.pulse ? 1.18 : 1.0
        Behavior on scale { NumberAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 180 } }
      }

      Text {
        visible: root.wsLabel !== "" && !root.vertical
        textFormat: Text.PlainText
        text: root.wsLabel
        color: root.accent
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
