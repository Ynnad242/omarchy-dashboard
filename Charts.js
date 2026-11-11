.pragma library

// Drawing helpers shared by the charts, in the style of Bklit UI: smooth
// curves that never overshoot the data, fills that fade toward the bottom,
// and edges that fade out instead of stopping hard.

// Monotone cubic tangents (Fritsch–Carlson): the curve stays smooth but
// never bulges above a peak or below a dip that isn't in the data.
function tangents(xs, ys) {
  var n = xs.length, d = [], m = new Array(n), i
  for (i = 0; i < n - 1; i++) d.push((ys[i + 1] - ys[i]) / ((xs[i + 1] - xs[i]) || 1))
  m[0] = d[0]
  m[n - 1] = d[n - 2]
  for (i = 1; i < n - 1; i++) m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2
  for (i = 0; i < n - 1; i++) {
    if (d[i] === 0) { m[i] = 0; m[i + 1] = 0; continue }
    var a = m[i] / d[i], b = m[i + 1] / d[i], s = a * a + b * b
    if (s > 9) { var k = 3 / Math.sqrt(s); m[i] = k * a * d[i]; m[i + 1] = k * b * d[i] }
  }
  return m
}

// Add a smooth path through the points to ctx (starts with moveTo).
function trace(ctx, xs, ys) {
  var n = xs.length
  if (n < 2) return
  ctx.moveTo(xs[0], ys[0])
  if (n === 2) { ctx.lineTo(xs[1], ys[1]); return }
  var m = tangents(xs, ys)
  for (var i = 0; i < n - 1; i++) {
    var h = (xs[i + 1] - xs[i]) / 3
    ctx.bezierCurveTo(xs[i] + h, ys[i] + m[i] * h, xs[i + 1] - h, ys[i + 1] - m[i + 1] * h, xs[i + 1], ys[i + 1])
  }
}

// Line plus a fill under it that fades to nothing at `bottom`.
function area(ctx, xs, ys, bottom, color, lineWidth, fillAlpha) {
  var c = color
  var g = ctx.createLinearGradient(0, Math.min.apply(null, ys), 0, bottom)
  g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, fillAlpha))
  g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
  ctx.beginPath()
  trace(ctx, xs, ys)
  ctx.lineTo(xs[xs.length - 1], bottom)
  ctx.lineTo(xs[0], bottom)
  ctx.closePath()
  ctx.fillStyle = g
  ctx.fill()

  ctx.beginPath()
  trace(ctx, xs, ys)
  ctx.lineWidth = lineWidth
  ctx.lineJoin = "round"
  ctx.lineCap = "round"
  ctx.strokeStyle = c
  ctx.stroke()
}

// Fade out what's already drawn near the left (and optionally right) edge.
function fadeEdges(ctx, w, h, frac, both) {
  var f = Math.max(1, w * frac)
  ctx.save()
  ctx.globalCompositeOperation = "destination-out"
  var l = ctx.createLinearGradient(0, 0, f, 0)
  l.addColorStop(0, "rgba(0,0,0,1)")
  l.addColorStop(1, "rgba(0,0,0,0)")
  ctx.fillStyle = l
  ctx.fillRect(0, 0, f, h)
  if (both) {
    var r = ctx.createLinearGradient(w - f, 0, w, 0)
    r.addColorStop(0, "rgba(0,0,0,0)")
    r.addColorStop(1, "rgba(0,0,0,1)")
    ctx.fillStyle = r
    ctx.fillRect(w - f, 0, f, h)
  }
  ctx.restore()
}

// Dashed horizontal guide.
function dashed(ctx, x0, x1, y, color) {
  ctx.save()
  ctx.setLineDash([2, 5])
  ctx.strokeStyle = color
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo(x0, Math.round(y) + 0.5)
  ctx.lineTo(x1, Math.round(y) + 0.5)
  ctx.stroke()
  ctx.restore()
}
