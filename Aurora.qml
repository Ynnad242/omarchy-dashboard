import QtQuick

// The canvas behind everything, per style:
//   flat   near-black with the faintest lift toward the top
//   neu    one even mid-tone; the cards' shadows do the work
//   glass  soft fields of color for the translucent panes to sit over
//   clay   a warm glow toward the top
//   y2k    a loud purple / magenta / cyan wash with a few bubbles
//   swiss  plain paper with a faint 12-column grid
//   wabi   warm paper with a little grain
// Painted with gradients and a Canvas, so no shader support is needed.
Item {
  id: canvas

  property var t
  property bool running: false   // kept for callers; nothing animates here

  Rectangle {
    anchors.fill: parent
    color: canvas.t.base
  }

  Rectangle {
    visible: canvas.t.style === "flat"
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: canvas.t.inkA(0.018) }
      GradientStop { position: 0.35; color: canvas.t.inkA(0.0) }
    }
  }

  Canvas {
    id: art
    anchors.fill: parent
    readonly property string style: canvas.t.style
    readonly property color a: canvas.t.accent
    readonly property color b: canvas.t.base
    function shifted(c, dh, s, l) { return Qt.hsla((c.hslHue + dh + 1) % 1, s, l, 1) }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onStyleChanged: requestPaint()
    onAChanged: requestPaint()
    onBChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width, h = height
      function blob(cx, cy, r, c, alpha) {
        var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, alpha))
        g.addColorStop(0.5, Qt.rgba(c.r, c.g, c.b, alpha * 0.35))
        g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
      }
      switch (style) {
      case "glass":
        blob(w * 0.78, h * 0.12, h * 0.75, a, 0.55)
        blob(w * 0.12, h * 0.85, h * 0.80, shifted(a, 0.12, 0.55, 0.45), 0.40)
        blob(w * 0.45, h * 0.55, h * 0.55, shifted(a, -0.10, 0.50, 0.40), 0.28)
        break
      case "clay":
        blob(w * 0.5, -h * 0.1, h * 0.9, shifted(a, 0.05, 0.35, 0.55), 0.18)
        break
      case "y2k": {
        var g = ctx.createLinearGradient(0, 0, w, h)
        g.addColorStop(0, "#2b0a5e")
        g.addColorStop(0.45, "#5a0f6e")
        g.addColorStop(0.75, "#0f3a6e")
        g.addColorStop(1, "#06323f")
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
        blob(w * 0.85, h * 0.1, h * 0.6, Qt.rgba(1, 0.37, 0.82, 1), 0.55)
        blob(w * 0.1, h * 0.9, h * 0.7, Qt.rgba(0.2, 0.9, 1, 1), 0.40)
        // Bubbles with a glossy highlight.
        var bubbles = [[0.62, 0.18, 0.05], [0.08, 0.3, 0.035], [0.93, 0.62, 0.06], [0.4, 0.92, 0.04]]
        for (var i = 0; i < bubbles.length; i++) {
          var bx = w * bubbles[i][0], by = h * bubbles[i][1], br = h * bubbles[i][2]
          var bg = ctx.createRadialGradient(bx - br * 0.35, by - br * 0.35, br * 0.05, bx, by, br)
          bg.addColorStop(0, "rgba(255,255,255,0.55)")
          bg.addColorStop(0.35, "rgba(255,255,255,0.10)")
          bg.addColorStop(0.9, "rgba(255,180,255,0.10)")
          bg.addColorStop(1, "rgba(255,255,255,0.35)")
          ctx.fillStyle = bg
          ctx.beginPath(); ctx.arc(bx, by, br, 0, Math.PI * 2); ctx.fill()
        }
        break
      }
      case "swiss": {
        ctx.strokeStyle = "rgba(0,0,0,0.05)"
        ctx.lineWidth = 1
        var cols = 12, margin = w * 0.05, cw = (w - margin * 2) / cols
        for (var c = 0; c <= cols; c++) {
          var x = Math.round(margin + c * cw) + 0.5
          ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke()
        }
        break
      }
      case "wabi": {
        // Paper grain: a few thousand faint specks, seeded so it doesn't shimmer.
        var seed = 7
        function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
        for (var k = 0; k < 9000; k++) {
          ctx.fillStyle = rnd() > 0.5 ? "rgba(60,45,30,0.05)" : "rgba(255,250,240,0.06)"
          ctx.fillRect(rnd() * w, rnd() * h, 1.5, 1.5)
        }
        var v = ctx.createRadialGradient(w / 2, h / 2, h * 0.3, w / 2, h / 2, w * 0.75)
        v.addColorStop(0, "rgba(0,0,0,0)")
        v.addColorStop(1, "rgba(70,50,30,0.10)")
        ctx.fillStyle = v
        ctx.fillRect(0, 0, w, h)
        break
      }
      }
    }
  }
}
