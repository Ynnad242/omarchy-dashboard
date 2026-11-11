import QtQuick

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
    var p = 1 - Math.pow(1 - Math.max(0, Math.min(1, progress)), 3)
    var reach = w * p

    function px(i) { return pad + w * i / (v.length - 1) }
    function py(i) { return pad + h - h * (v[i] - min) / span }

    // Smooth the line with midpoint quadratic curves.
    function trace() {
      ctx.moveTo(px(0), py(0))
      for (var i = 1; i < v.length; i++) {
        var mx = (px(i - 1) + px(i)) / 2, my = (py(i - 1) + py(i)) / 2
        ctx.quadraticCurveTo(px(i - 1), py(i - 1), mx, my)
      }
      ctx.lineTo(px(v.length - 1), py(v.length - 1))
    }

    ctx.save()
    ctx.beginPath()
    ctx.rect(0, 0, pad + reach, height)
    ctx.clip()

    var fill = ctx.createLinearGradient(0, pad, 0, height)
    fill.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.10))
    fill.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.0))
    ctx.beginPath()
    trace()
    ctx.lineTo(px(v.length - 1), height)
    ctx.lineTo(px(0), height)
    ctx.closePath()
    ctx.fillStyle = fill
    ctx.fill()

    ctx.beginPath()
    trace()
    ctx.lineWidth = lineWidth
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    ctx.strokeStyle = color
    ctx.stroke()
    ctx.restore()

    if (p > 0.98) {
      var lx = px(v.length - 1), ly = py(v.length - 1)
      ctx.beginPath()
      ctx.arc(lx, ly, lineWidth * 3, 0, Math.PI * 2)
      ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.0)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(lx, ly, lineWidth * 1.3, 0, Math.PI * 2)
      ctx.fillStyle = color
      ctx.fill()
    }
  }
}
