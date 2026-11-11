import QtQuick
import qs.Commons
import "Charts.js" as Charts

// The big price chart, Bklit-style: a smooth line over a fill that fades
// toward the bottom and out at the left edge, dashed guides, the starting
// price as a dashed baseline, prices on the right and times along the bottom.
// Hovering shows a crosshair that fades at its ends, a ringed dot on the line,
// the time in a pill on the axis and the price beside it. It draws itself in,
// left to right, whenever the stock or range changes.
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
    if (range === "1d") return Qt.formatTime(d, t.timeFmt)
    if (range === "5d") return long ? Qt.formatDateTime(d, "ddd " + t.timeFmt) : Qt.formatDate(d, "ddd")
    if (range === "1mo") return long ? Qt.formatDateTime(d, t.clock24 ? "MMM d, HH:00" : "MMM d, h AP") : Qt.formatDate(d, "MMM d")
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
    duration: Style.duration(1100)
    easing.type: Easing.OutQuart   // GSAP's power3.out
  }

  // Price grid and labels
  Repeater {
    model: 5
    Item {
      required property int index
      readonly property real v: chart.bounds.lo + (chart.bounds.hi - chart.bounds.lo) * (index + 0.5) / 5
      y: chart.yAt(v)
      width: chart.width
      JText {
        t: chart.t
        x: chart.width - chart.padR + chart.t.px(10)
        anchors.verticalCenter: parent.top
        visible: chart.points.length > 1
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
      var right = chart.width - chart.padR

      // Dashed guides at the price labels.
      for (var gi = 0; gi < 5; gi++)
        Charts.dashed(ctx, 0, right, chart.yAt(chart.bounds.lo + (chart.bounds.hi - chart.bounds.lo) * (gi + 0.5) / 5), chart.t.inkA(0.08))

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

      var xs = [], ys = []
      for (var i = 0; i < p.length; i++) { xs.push(chart.xAt(i)); ys.push(chart.yAt(p[i][1])) }

      // The line and its fill, drawn into a layer of their own so the left
      // edge can fade without touching the guides.
      ctx.save()
      ctx.beginPath(); ctx.rect(0, 0, reach, chart.height); ctx.clip()
      Charts.area(ctx, xs, ys, bottom, c, Math.max(1.5, chart.t.px(2)), 0.26)
      ctx.restore()
      Charts.fadeEdges(ctx, right, chart.height, 0.04, false)

      // The latest price: a dot with a soft halo, once the line has arrived.
      if (chart.reveal >= 1) {
        var lx = xs[xs.length - 1], ly = ys[ys.length - 1]
        ctx.beginPath(); ctx.arc(lx, ly, chart.t.px(8), 0, Math.PI * 2)
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.18); ctx.fill()
        ctx.beginPath(); ctx.arc(lx, ly, chart.t.px(3.5), 0, Math.PI * 2)
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

    // A vertical line that fades out at both ends.
    Rectangle {
      x: Math.round(parent.px); y: chart.padT; width: 1; height: chart.height - chart.padT - chart.padB
      gradient: Gradient {
        GradientStop { position: 0.0; color: chart.t.inkA(0) }
        GradientStop { position: 0.25; color: chart.t.inkA(0.35) }
        GradientStop { position: 0.75; color: chart.t.inkA(0.35) }
        GradientStop { position: 1.0; color: chart.t.inkA(0) }
      }
    }
    // A ringed dot on the line.
    Rectangle {
      x: parent.px - width / 2; y: parent.py - height / 2
      width: chart.t.px(18); height: width; radius: width / 2
      color: chart.t.alpha(chart.tone, 0.2)
      Rectangle {
        anchors.centerIn: parent
        width: chart.t.px(9); height: width; radius: width / 2
        color: chart.tone
        border.width: chart.t.px(2); border.color: chart.t.base
      }
    }
    // The time, in a pill on the axis.
    Rectangle {
      x: Math.max(0, Math.min(chart.width - chart.padR - width, parent.px - width / 2))
      y: chart.height - chart.padB + chart.t.px(4)
      width: pillText.implicitWidth + chart.t.px(16)
      height: chart.t.px(20)
      radius: height / 2
      color: chart.t.text
      z: 2
      JText {
        id: pillText
        t: chart.t
        anchors.centerIn: parent
        text: chart.hoverIndex >= 0 && chart.hoverIndex < chart.points.length ? chart.timeLabel(chart.points[chart.hoverIndex][0], true) : ""
        size: 9.5
        font.weight: Font.DemiBold
        color: chart.t.base
      }
    }
    Rectangle {
      readonly property bool flip: parent.px > (chart.width - chart.padR) * 0.7
      x: flip ? parent.px - width - chart.t.px(12) : parent.px + chart.t.px(12)
      y: Math.max(chart.padT, Math.min(chart.height - chart.padB - height, parent.py - height - chart.t.px(10)))
      width: tipCol.implicitWidth + chart.t.px(20)
      height: tipCol.implicitHeight + chart.t.px(12)
      radius: chart.t.px(10)
      color: chart.t.raised
      border.width: 1
      border.color: chart.t.inkA(0.12)
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
          text: (d >= 0 ? "▲ +" : "▼ ") + d.toFixed(2) + "%" + (chart.base > 0 ? "  vs start" : "")
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
