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

    // Three rings, as big as the card allows: in a row, a column, or two
    // over one, whichever gives the biggest rings.
    Item {
      id: rings
      width: parent.width
      height: parent.height - (card.mouse ? card.t.px(62) + card.t.px(12) : 0)
      readonly property real g: card.t.px(14)
      readonly property var fit: {
        var w = width, h = height, g = rings.g, best = null
        var opts = [{ cols: 3, rows: 1 }, { cols: 1, rows: 3 }, { cols: 2, rows: 2 }]
        for (var i = 0; i < opts.length; i++) {
          var o = opts[i], d = Math.min((w - g * (o.cols - 1)) / o.cols, (h - g * (o.rows - 1)) / o.rows)
          if (!best || d > best.d + 0.5) best = { cols: o.cols, rows: o.rows, d: d }
        }
        best.d = Math.max(card.t.px(48), Math.min(best.d, card.t.px(170)))
        return best
      }
      // Top-left of ring i, centered in the area; a lone last ring is centered too.
      function pos(i) {
        var f = fit, col = i % f.cols, row = Math.floor(i / f.cols)
        var inRow = Math.min(f.cols, 3 - row * f.cols)
        var rowW = inRow * f.d + (inRow - 1) * g
        var totalH = f.rows * f.d + (f.rows - 1) * g
        return { x: (width - rowW) / 2 + col * (f.d + g), y: (height - totalH) / 2 + row * (f.d + g) }
      }
      readonly property var data3: [
        { v: card.system.cpu || 0, l: "CPU" }, { v: card.system.ram || 0, l: "RAM" }, { v: card.system.disk || 0, l: "Disk" }
      ]
      Repeater {
        model: 3
        Ring {
          required property int index
          readonly property var p: rings.pos(index)
          t: card.t
          x: p.x; y: p.y
          width: rings.fit.d; height: width
          value: rings.data3[index].v
          label: rings.data3[index].l
          color: card.t.text
          progress: card.ease(card.progress * 1.3 - 0.1 * index)
        }
      }
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
      border.color: card.t.inkA(mh.hovered ? 0.14 : 0.06)
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
