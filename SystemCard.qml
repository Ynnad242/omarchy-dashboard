import QtQuick
import qs.Commons

// The machine: CPU, memory and disk gauges, and the mouse Hubless manages.
GlassCard {
  id: card

  property var system: ({})
  readonly property var mouse: system.mouse || null

  title: "System"
  icon: ""
  iconColor: t.cyan

  Item {
    anchors.fill: parent

    Row {
      id: rings
      width: parent.width
      readonly property real d: Math.min((width - card.t.px(16)) / 3, card.t.px(78))
      spacing: (width - d * 3) / 2
      Ring { t: card.t; width: rings.d; height: rings.d; value: card.system.cpu || 0; label: "CPU"; color: card.t.text; progress: card.ease(card.progress * 1.3) }
      Ring { t: card.t; width: rings.d; height: rings.d; value: card.system.ram || 0; label: "RAM"; color: card.t.text; progress: card.ease(card.progress * 1.3 - 0.1) }
      Ring { t: card.t; width: rings.d; height: rings.d; value: card.system.disk || 0; label: "Disk"; color: card.t.text; progress: card.ease(card.progress * 1.3 - 0.2) }
    }

    // Hubless: the mouse, its battery and DPI.
    Rectangle {
      visible: !!card.mouse
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: card.t.px(62)
      radius: card.t.radiusSmall
      color: card.t.glassInset
      InsetShade { t: card.t }
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, mh.hovered ? 0.14 : 0.06)
      opacity: card.ease(card.progress * 1.5 - 0.3)

      Rectangle {
        id: micon
        x: card.t.px(10)
        anchors.verticalCenter: parent.verticalCenter
        width: card.t.px(32); height: width
        radius: card.t.px(9)
        color: card.t.glassInset
        InsetShade { t: card.t }
        JText { t: card.t; anchors.centerIn: parent; text: String.fromCodePoint(0xF037D); size: 15; color: card.t.green }
      }
      JText {
        id: mname
        t: card.t
        anchors.left: micon.right
        anchors.leftMargin: card.t.px(10)
        anchors.right: parent.right
        anchors.rightMargin: card.t.px(10)
        y: card.t.px(11)
        text: card.mouse ? card.mouse.name : ""
        size: 11
        font.weight: Font.DemiBold
      }
      JText {
        id: mmeta
        t: card.t
        anchors.left: mname.left
        anchors.top: mname.bottom
        anchors.topMargin: card.t.px(2)
        text: card.mouse ? card.mouse.dpi + " DPI  ·  " + card.mouse.profile : ""
        size: 9.5
        color: card.t.textFaint
      }
      // Battery bar
      Rectangle {
        anchors.left: mname.left
        anchors.right: batt.left
        anchors.rightMargin: card.t.px(8)
        anchors.top: mmeta.bottom
        anchors.topMargin: card.t.px(5)
        height: card.t.px(4)
        radius: height / 2
        color: card.t.inkA(0.07)
        Rectangle {
          height: parent.height
          radius: height / 2
          readonly property real pct: card.mouse ? card.mouse.battery / 100 : 0
          width: parent.width * pct * card.ease(card.progress * 1.4 - 0.3)
          color: pct > 0.25 ? card.t.green : card.t.red
        }
      }
      JText {
        id: batt
        t: card.t
        anchors.right: parent.right
        anchors.rightMargin: card.t.px(10)
        anchors.verticalCenter: mmeta.bottom
        anchors.verticalCenterOffset: card.t.px(7)
        text: card.mouse ? card.mouse.battery + "%" : ""
        size: 9.5
        color: card.t.textDim
      }
      HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
    }
  }
}
