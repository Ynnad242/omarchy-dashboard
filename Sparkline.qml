import QtQuick
import "Charts.js" as Charts

// A small trend line that draws itself left to right as `progress` runs,
// with a soft fill under it and a dot on the latest value.
Canvas {
  id: spark

  property var values: []
  property color color: "white"
  property real progress: 1
  property real lineWidth: 2

  onValuesChanged: requestPaint()
  onProgressChanged: requestPaint()
  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var v = values || []
    if (v.length < 2 || width <= 0 || height <= 0) return

    var min = Math.min.apply(null, v), max = Math.max.apply(null, v)
    var span = max - min || 1
    var pad = lineWidth + 3
    var w = width - pad * 2, h = height - pad * 2
    var p = 1 - Math.pow(1 - Math.max(0, Math.min(1, progress)), 4)   // power3.out
    var reach = w * p

    function px(i) { return pad + w * i / (v.length - 1) }
    function py(i) { return pad + h - h * (v[i] - min) / span }
    var xs = [], ys = []
    for (var k = 0; k < v.length; k++) { xs.push(px(k)); ys.push(py(k)) }

    // Bklit-style: a smooth line over a fill that fades down, drawn in left to
    // right, with the left edge fading out.
    ctx.save()
    ctx.beginPath()
    ctx.rect(0, 0, pad + reach, height)
    ctx.clip()
    Charts.area(ctx, xs, ys, height, color, lineWidth, 0.22)
    ctx.restore()
    Charts.fadeEdges(ctx, width, height, 0.18, false)

    if (p > 0.98) {
      var lx = px(v.length - 1), ly = py(v.length - 1)
      ctx.beginPath()
      ctx.arc(lx, ly, lineWidth * 3, 0, Math.PI * 2)
      ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(lx, ly, lineWidth * 1.3, 0, Math.PI * 2)
      ctx.fillStyle = color
      ctx.fill()
    }
  }
}
