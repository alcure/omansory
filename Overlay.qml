import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Compact retrowave wall rocker: ON / OFF only, English, under the bar.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string mode: "on"
  property string pack: ""
  property int workspace: 0
  property real rocker: 1

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "alcure.omansory"
  readonly property bool isOn: mode !== "off"
  readonly property bool isCenter: pack === "center"
  readonly property string packLabel: {
    if (isCenter) return isOn ? "CENTER ON" : "CENTER OFF"
    if (!isOn) return "OFF"
    return "MASONRY ON"
  }
  readonly property color magenta: "#ff71ce"
  readonly property color cyan: "#05d9e8"
  readonly property color ink: isOn ? magenta : cyan
  readonly property color plate: "#14081f"
  readonly property string uiFont: Style.font.family
  readonly property int hudWidth: Style.space(176)

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) { payload = {} }
    root.mode = payload.mode === "off" ? "off" : "on"
    root.pack = payload.pack === "center" ? "center" : (payload.pack || "fit")
    root.workspace = Number(payload.workspace || 0)
    root.rocker = root.isOn ? 1 : -1
    hud.pop = 1
    root.opened = true
    hideTimer.restart()
    flipAnim.stop()
    flipAnim.from = root.rocker
    flipAnim.to = root.isOn ? -1 : 1
    flipAnim.start()
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  Timer {
    id: hideTimer
    interval: 720
    repeat: false
    onTriggered: root.dismiss()
  }

  NumberAnimation {
    id: flipAnim
    target: root
    property: "rocker"
    duration: 220
    easing.type: Easing.OutBack
    easing.overshoot: 2.2
  }

  PanelWindow {
    visible: root.opened || hud.opacity > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omansory-flash"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      onClicked: root.dismiss()
    }

    Item {
      id: hud
      property real pop: 1
      width: root.hudWidth
      height: plateCol.implicitHeight + Style.space(18)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.space(48)
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.9
      Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
      transform: Scale {
        origin.x: hud.width / 2
        origin.y: hud.height / 2
        xScale: hud.pop
        yScale: hud.pop
      }

      MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true } }

      BorderSurface {
        id: card
        anchors.fill: parent
        radius: Style.cornerRadius
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        gradient: Gradient {
          GradientStop { position: 0; color: Util.alpha(Qt.lighter(Color.popups.background, 1.25), 0.96) }
          GradientStop { position: 1; color: Util.alpha(Color.popups.background, 0.96) }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: "#000000"
          shadowOpacity: 0.5
          shadowBlur: 0.85
          blurMax: 28
          shadowVerticalOffset: Style.space(6)
        }
      }

      Column {
        id: plateCol
        width: hud.width - Style.space(20)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Style.space(12)
        spacing: Style.space(8)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "OMANSORY"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 2.2
          color: Util.alpha(root.isOn ? root.magenta : root.cyan, 0.9)
        }

        Item {
          width: Style.space(22)
          height: Style.space(22)
          anchors.horizontalCenter: parent.horizontalCenter

          Repeater {
            model: root.isCenter ? 0 : 4
            Rectangle {
              required property int index
              property real gap: Style.space(2)
              property real cell: (parent.width - gap * 3) / 2
              x: gap + (index % 2) * (cell + gap)
              y: gap + Math.floor(index / 2) * (cell + gap)
              width: cell
              height: cell
              radius: 1
              color: root.ink
            }
          }

          Rectangle {
            visible: root.isCenter
            anchors.fill: parent
            color: "transparent"
            border.width: Math.max(2, Style.space(2))
            border.color: root.ink
            radius: 2
          }
          Rectangle {
            visible: root.isCenter
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: parent.height * 0.42
            radius: 1
            color: root.ink
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.packLabel
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.4
          color: Util.alpha(root.isOn ? root.magenta : root.cyan, 0.85)
        }

        Item {
          id: switchBox
          width: Style.space(72)
          height: Style.space(108)
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            anchors.fill: parent
            radius: Style.space(8)
            color: root.plate
            border.width: Math.max(1, Style.space(2))
            border.color: root.isOn ? root.magenta : root.cyan
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Style.space(2)
            width: parent.width - Style.space(10)
            height: parent.height - Style.space(10)
            radius: Style.space(5)
            color: "#07040c"
          }

          Item {
            id: paddle
            anchors.centerIn: parent
            width: parent.width - Style.space(14)
            height: parent.height - Style.space(14)
            transform: Rotation {
              origin.x: paddle.width / 2
              origin.y: paddle.height / 2
              axis.x: 1; axis.y: 0; axis.z: 0
              angle: root.rocker * 22
            }

            Rectangle {
              anchors.fill: parent
              radius: Style.space(4)
              gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: root.isOn ? "#3a1028" : "#1a2230" }
                GradientStop { position: 0.5; color: "#1a0e24" }
                GradientStop { position: 1; color: root.isOn ? "#1a2230" : "#123038" }
              }
              border.width: 1
              border.color: Util.alpha("#ffffff", 0.12)
            }

            Rectangle {
              id: onFace
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(3)
              height: parent.height / 2 - Style.space(4)
              radius: Style.space(3)
              color: root.isOn ? Util.alpha(root.magenta, 0.35) : "#120816"
              border.width: 1
              border.color: root.isOn ? root.magenta : Util.alpha(root.magenta, 0.25)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "ON"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1.6
                color: root.isOn ? "#fff0fa" : Util.alpha(root.magenta, 0.4)
              }
            }

            Rectangle {
              id: offFace
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(3)
              height: parent.height / 2 - Style.space(4)
              radius: Style.space(3)
              color: root.isOn ? "#0a0810" : Util.alpha(root.cyan, 0.32)
              border.width: 1
              border.color: root.isOn ? Util.alpha(root.cyan, 0.25) : root.cyan

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "OFF"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1.6
                color: root.isOn ? Util.alpha(root.cyan, 0.4) : "#e8ffff"
              }
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(8)
              height: Math.max(1, Style.space(2))
              color: Util.alpha("#000000", 0.65)
            }
          }

          Rectangle {
            visible: root.isOn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(6)
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            color: root.magenta
            opacity: 0.95
          }

          Rectangle {
            visible: !root.isOn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(6)
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            color: root.cyan
            opacity: 0.85
          }
        }
      }
    }
  }
}
