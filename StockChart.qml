import QtQuick
import qs.Commons

// The big price chart: a line with a soft fill, the starting price as a
// dashed baseline, price labels on the right, times along the bottom, and a
// crosshair that follows the pointer with the price and time under it. It
// draws itself in left to right whenever new data arrives.
Item {
  id: chart

  property var t
  property var points: []        // [[unixSeconds, price], ...]
  property real base: 0          // starting price (previous close for 1D)
  property string range: "1d"
  property string currency: "USD"
  property real reveal: 0
  property int hoverIndex: -1

  readonly property bool up: points.length > 1 ? points[points.length - 1][1] >= base : true
  readonly property color tone: up ? t.green : t.red
  readonly property real padR: t.px(64)
  readonly property real padB: t.px(26)
  readonly property real padT: t.px(10)

  readonly property var bounds: {
    var lo = Infinity, hi = -Infinity
    for (var i = 0; i < points.length; i++) { lo = Math.min(lo, points[i][1]); hi = Math.max(hi, points[i][1]) }
    if (base > 0) { lo = Math.min(lo, base); hi = Math.max(hi, base) }
    if (!isFinite(lo)) return { lo: 0, hi: 1 }
    var pad = (hi - lo) * 0.08 || hi * 0.01 || 1
    return { lo: lo - pad, hi: hi + pad }
  }

  function xAt(i) { return points.length > 1 ? (width - padR) * i / (points.length - 1) : 0 }
  function yAt(v) { return padT + (height - padT - padB) * (1 - (v - bounds.lo) / (bounds.hi - bounds.lo)) }
  function money(v) {
    if (v === null || v === undefined || isNaN(v)) return "—"
    var d = Math.abs(v) >= 1000 ? 0 : 2
    return (currency === "USD" ? "$" : "") + Number(v).toLocaleString(Qt.locale("en_US"), "f", d)
  }
  function timeLabel(ts, long) {
    var d = new Date(ts * 1000)
    if (range === "1d") return Qt.formatTime(d, "h:mm AP")
    if (range === "5d") return long ? Qt.formatDateTime(d, "ddd h:mm AP") : Qt.formatDate(d, "ddd")
    if (range === "1mo") return long ? Qt.formatDateTime(d, "MMM d, h AP") : Qt.formatDate(d, "MMM d")
    if (range === "5y") return Qt.formatDate(d, long ? "MMM d, yyyy" : "yyyy")
    return Qt.formatDate(d, long ? "MMM d, yyyy" : "MMM d")
  }

  // Draw in from the left when the stock or range changes; a live refresh of
  // the same chart just repaints, so the line grows a tick at a time.
  property string key: ""
  property string shownKey: ""
  onPointsChanged: {
    if (key !== shownKey) { shownKey = key; revealAnim.restart() }
    canvas.requestPaint()
  }
  onRevealChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onToneChanged: canvas.requestPaint()

  NumberAnimation {
    id: revealAnim
    target: chart
    property: "reveal"
    from: 0; to: 1
    duration: Style.duration(700)
    easing.type: Easing.OutCubic
  }

  // Price grid and labels
  Repeater {
    model: 5
    Item {
      required property int index
      readonly property real v: chart.bounds.lo + (chart.bounds.hi - chart.bounds.lo) * (index + 0.5) / 5
      y: chart.yAt(v)
      width: chart.width
      Rectangle { width: chart.width - chart.padR; height: 1; color: chart.t.inkA(0.045) }
      JText {
        t: chart.t
        x: chart.width - chart.padR + chart.t.px(10)
        anchors.verticalCenter: parent.top
        text: chart.money(parent.v)
        size: 9.5
        color: chart.t.textFaint
      }
    }
  }

  // Time labels
  Repeater {
    model: chart.points.length > 1 ? 5 : 0
    JText {
      required property int index
      readonly property int i: Math.round((chart.points.length - 1) * index / 4)
      t: chart.t
      x: Math.max(0, Math.min(chart.width - chart.padR - width, chart.xAt(i) - width / 2))
      y: chart.height - chart.padB + chart.t.px(8)
      text: chart.points.length > i ? chart.timeLabel(chart.points[i][0], false) : ""
      size: 9.5
      color: chart.t.textFaint
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var p = chart.points
      if (!p || p.length < 2) return
      var reach = (chart.width - chart.padR) * chart.reveal
      var c = chart.tone
      var bottom = chart.height - chart.padB

      // Baseline (start / previous close), dashed.
      if (chart.base > 0) {
        var by = chart.yAt(chart.base)
        ctx.save()
        ctx.setLineDash([3, 5])
        ctx.strokeStyle = chart.t.inkA(0.22)
        ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(0, by); ctx.lineTo(chart.width - chart.padR, by); ctx.stroke()
        ctx.restore()
      }

      ctx.save()
      ctx.beginPath(); ctx.rect(0, 0, reach, chart.height); ctx.clip()

      var fill = ctx.createLinearGradient(0, chart.padT, 0, bottom)
      fill.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.12))
      fill.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0))
      ctx.beginPath()
      ctx.moveTo(chart.xAt(0), chart.yAt(p[0][1]))
      for (var i = 1; i < p.length; i++) ctx.lineTo(chart.xAt(i), chart.yAt(p[i][1]))
      ctx.lineTo(chart.xAt(p.length - 1), bottom)
      ctx.lineTo(chart.xAt(0), bottom)
      ctx.closePath()
      ctx.fillStyle = fill
      ctx.fill()

      ctx.beginPath()
      ctx.moveTo(chart.xAt(0), chart.yAt(p[0][1]))
      for (var j = 1; j < p.length; j++) ctx.lineTo(chart.xAt(j), chart.yAt(p[j][1]))
      ctx.lineWidth = Math.max(1.5, chart.t.px(2))
      ctx.lineJoin = "round"
      ctx.strokeStyle = c
      ctx.stroke()
      ctx.restore()

      if (chart.reveal >= 1) {
        var lx = chart.xAt(p.length - 1), ly = chart.yAt(p[p.length - 1][1])
        ctx.beginPath(); ctx.arc(lx, ly, chart.t.px(7), 0, Math.PI * 2)
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.0); ctx.fill()
        ctx.beginPath(); ctx.arc(lx, ly, chart.t.px(3), 0, Math.PI * 2)
        ctx.fillStyle = c; ctx.fill()
      }
    }
  }

  // Crosshair
  Item {
    visible: chart.hoverIndex >= 0 && chart.hoverIndex < chart.points.length
    readonly property real px: visible ? chart.xAt(chart.hoverIndex) : 0
    readonly property real py: visible ? chart.yAt(chart.points[chart.hoverIndex][1]) : 0
    anchors.fill: parent

    Rectangle { x: parent.px; y: chart.padT; width: 1; height: chart.height - chart.padT - chart.padB; color: chart.t.inkA(0.25) }
    Rectangle { x: 0; y: parent.py; width: chart.width - chart.padR; height: 1; color: chart.t.inkA(0.12) }
    Rectangle {
      x: parent.px - width / 2; y: parent.py - height / 2
      width: chart.t.px(10); height: width; radius: width / 2
      color: chart.tone
      border.width: 2; border.color: "white"
    }
    Rectangle {
      readonly property bool flip: parent.px > (chart.width - chart.padR) * 0.7
      x: flip ? parent.px - width - chart.t.px(12) : parent.px + chart.t.px(12)
      y: Math.max(chart.padT, Math.min(chart.height - chart.padB - height, parent.py - height - chart.t.px(10)))
      width: tipCol.implicitWidth + chart.t.px(20)
      height: tipCol.implicitHeight + chart.t.px(12)
      radius: chart.t.px(8)
      color: chart.t.raised
      border.width: 1
      border.color: chart.t.alpha(chart.tone, 0.5)
      Column {
        id: tipCol
        anchors.centerIn: parent
        spacing: chart.t.px(2)
        JText {
          t: chart.t
          text: chart.hoverIndex >= 0 && chart.hoverIndex < chart.points.length ? chart.money(chart.points[chart.hoverIndex][1]) : ""
          size: 12.5
          font.weight: Font.Bold
        }
        JText {
          t: chart.t
          readonly property real d: chart.hoverIndex >= 0 && chart.hoverIndex < chart.points.length && chart.base > 0 ? (chart.points[chart.hoverIndex][1] - chart.base) / chart.base * 100 : 0
          text: (d >= 0 ? "+" : "") + d.toFixed(2) + "%  ·  " + (chart.hoverIndex >= 0 && chart.hoverIndex < chart.points.length ? chart.timeLabel(chart.points[chart.hoverIndex][0], true) : "")
          size: 9.5
          color: d >= 0 ? chart.t.green : chart.t.red
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    anchors.rightMargin: chart.padR
    hoverEnabled: true
    onPositionChanged: function(m) {
      if (chart.points.length < 2) return
      chart.hoverIndex = Math.max(0, Math.min(chart.points.length - 1, Math.round(m.x / width * (chart.points.length - 1))))
    }
    onExited: chart.hoverIndex = -1
  }
}
