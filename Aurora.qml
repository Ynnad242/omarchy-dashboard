import QtQuick
import Quickshell

// The canvas behind everything, per style:
//   flat   near-black with the faintest lift toward the top
//   neu    one even mid-tone; the cards' shadows do the work
//   glass  soft fields of color for the translucent panes to sit over
//   clay   a warm glow toward the top
//   y2k    electric cobalt, a perspective floor grid, a wireframe globe,
//          sparkles and HUD labels in the margins
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

  // omarchy: the desktop's own wallpaper, dimmed toward the theme background.
  Image {
    visible: canvas.t.omarchy && status === Image.Ready
    anchors.fill: parent
    source: canvas.t.omarchy ? "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background" : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    sourceSize.width: 1920
  }
  Rectangle {
    visible: canvas.t.omarchy
    anchors.fill: parent
    color: canvas.t.base
    opacity: 0.78
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
        // Electric cobalt, brighter toward the top-right.
        var g = ctx.createLinearGradient(0, 0, 0, h)
        g.addColorStop(0, "#0b22e0")
        g.addColorStop(0.55, "#06128f")
        g.addColorStop(1, "#020538")
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
        blob(w * 0.82, h * 0.05, h * 0.75, Qt.rgba(0.35, 0.55, 1, 1), 0.55)
        blob(w * 0.05, h * 0.95, h * 0.6, Qt.rgba(0.2, 0.9, 1, 1), 0.18)

        // A perspective floor grid over the bottom third.
        ctx.strokeStyle = "rgba(150,190,255,0.16)"
        ctx.lineWidth = 1
        var horizon = h * 0.62, vx = w * 0.5
        for (var r = 1; r <= 14; r++) {
          var fy = horizon + (h - horizon) * Math.pow(r / 14, 1.9)
          ctx.beginPath(); ctx.moveTo(0, fy); ctx.lineTo(w, fy); ctx.stroke()
        }
        for (var c = -14; c <= 14; c++) {
          ctx.beginPath(); ctx.moveTo(vx + c * w * 0.012, horizon); ctx.lineTo(vx + c * w * 0.11, h); ctx.stroke()
        }

        // A wireframe globe, top right.
        var gx = w * 0.9, gy = h * 0.2, gr = h * 0.16
        ctx.strokeStyle = "rgba(200,220,255,0.22)"
        ctx.beginPath(); ctx.arc(gx, gy, gr, 0, Math.PI * 2); ctx.stroke()
        for (var k = 1; k <= 3; k++) {
          ctx.save(); ctx.translate(gx, gy); ctx.scale(k / 4, 1)
          ctx.beginPath(); ctx.arc(0, 0, gr, 0, Math.PI * 2); ctx.restore(); ctx.stroke()
          ctx.save(); ctx.translate(gx, gy); ctx.scale(1, k / 4)
          ctx.beginPath(); ctx.arc(0, 0, gr, 0, Math.PI * 2); ctx.restore(); ctx.stroke()
        }

        // Four-point sparkles with a soft halo.
        function sparkle(x, y, r) {
          var halo = ctx.createRadialGradient(x, y, 0, x, y, r * 2.2)
          halo.addColorStop(0, "rgba(220,235,255,0.55)")
          halo.addColorStop(1, "rgba(220,235,255,0)")
          ctx.fillStyle = halo
          ctx.beginPath(); ctx.arc(x, y, r * 2.2, 0, Math.PI * 2); ctx.fill()
          ctx.fillStyle = "rgba(255,255,255,0.95)"
          ctx.beginPath()
          ctx.moveTo(x, y - r)
          ctx.quadraticCurveTo(x, y, x + r, y)
          ctx.quadraticCurveTo(x, y, x, y + r)
          ctx.quadraticCurveTo(x, y, x - r, y)
          ctx.quadraticCurveTo(x, y, x, y - r)
          ctx.fill()
        }
        var stars = [[0.035, 0.12, 0.022], [0.62, 0.06, 0.014], [0.975, 0.48, 0.02], [0.3, 0.97, 0.012], [0.04, 0.72, 0.016], [0.83, 0.93, 0.018]]
        for (var i = 0; i < stars.length; i++) sparkle(w * stars[i][0], h * stars[i][1], h * stars[i][2])

        // HUD labels in the margins.
        ctx.fillStyle = "rgba(210,225,255,0.55)"
        ctx.font = Math.round(h * 0.0095) + "px monospace"
        ctx.save(); ctx.translate(w - h * 0.012, h * 0.62); ctx.rotate(Math.PI / 2)
        ctx.fillText("2000 AND BEYOND  //  DIGITAL DREAMS", 0, 0); ctx.restore()
        ctx.save(); ctx.translate(h * 0.016, h * 0.97); ctx.rotate(-Math.PI / 2)
        ctx.fillText(">> SYSTEM ONLINE   \u25cf  CONNECTION OK", 0, 0); ctx.restore()
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
