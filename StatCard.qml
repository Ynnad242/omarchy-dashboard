import QtQuick
import qs.Commons

// One metric across the top: a quiet label, the number, the change against
// a reference in plain colored text, and a thin trend line. Color appears
// only when it means something (up/down). `ticker` cycles the watchlist.
GlassCard {
  id: stat

  property var model: ({})
  property var ticker: model.ticker || []
  property int tickerIndex: 0
  signal clicked()

  // Trend lines are neutral unless the metric itself is a gain or loss.
  readonly property color lineColor: model.tone === "green" || model.tone === "red" ? t.tone(model.tone) : t.textDim

  function format(kind, v) {
    switch (kind) {
      case "duration":
        var m = Math.round(v)
        return m < 60 ? m + "m" : Math.floor(m / 60) + "h " + (m % 60 < 10 ? "0" : "") + (m % 60) + "m"
      case "fraction":
        return Math.round(v) + " / " + (model.total || 0)
      case "text":
        return model.text || "—"
      case "percent":
        return (v >= 0 ? "+" : "") + v.toFixed(2) + "%"
      default:
        return String(Math.round(v))
    }
  }

  Item {
    anchors.fill: parent

    JText {
      id: label
      t: stat.t
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      text: stat.model.title || ""
      size: 12
      font.weight: Font.Medium
      color: stat.t.textDim
    }

    JText {
      id: value
      t: stat.t
      anchors.left: parent.left
      anchors.top: label.bottom
      anchors.topMargin: stat.t.px(10)
      text: stat.format(stat.model.kind, (stat.model.value || 0) * stat.ease(stat.progress * 1.25))
      size: stat.model.kind === "text" ? 20 : 28
      font.weight: Font.DemiBold
      font.letterSpacing: -0.6
      color: stat.model.kind === "text" ? stat.t.textFaint : stat.t.text
    }

    // Change, as plain text: "↓ 8% vs your average".
    JText {
      id: delta
      visible: stat.model.delta !== undefined && stat.ticker.length === 0
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      readonly property bool good: (stat.model.delta || 0) >= 0 ? !stat.model.lowerIsBetter : !!stat.model.lowerIsBetter
      t: stat.t
      text: ((stat.model.delta || 0) >= 0 ? "↑ " : "↓ ") + Math.abs(stat.model.delta || 0) + (stat.model.deltaUnit || "") + "  " + (stat.model.deltaLabel || "")
      size: 11
      color: (stat.model.delta || 0) === 0 ? stat.t.textFaint : good ? stat.t.green : stat.t.red
    }

    // Watchlist ticker
    Item {
      visible: stat.ticker.length > 0
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      width: parent.width * 0.55
      height: stat.t.px(16)
      clip: true

      JText {
        id: tickText
        t: stat.t
        width: parent.width
        height: parent.height
        size: 11
        property var row: stat.ticker.length > 0 ? stat.ticker[stat.tickerIndex % stat.ticker.length] : null
        text: row ? row.sym + "  " + row.price.toFixed(2) + "  " + (row.change >= 0 ? "+" : "") + row.change.toFixed(2) + "%" : ""
        color: !row ? stat.t.textFaint : row.change >= 0 ? stat.t.green : stat.t.red
      }

      SequentialAnimation {
        id: tickSwap
        NumberAnimation { target: tickText; property: "opacity"; to: 0; duration: Style.duration(140) }
        ScriptAction { script: stat.tickerIndex++ }
        NumberAnimation { target: tickText; property: "opacity"; to: 1; duration: Style.duration(180) }
      }
      Timer {
        interval: 3500
        repeat: true
        running: stat.shown && stat.ticker.length > 1
        onTriggered: tickSwap.restart()
      }
    }

    TapHandler { onTapped: stat.clicked() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    Sparkline {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: Math.min(stat.t.px(110), parent.width * 0.42)
      height: stat.t.px(36)
      values: stat.model.spark || []
      color: stat.lineColor
      lineWidth: 1.5
      progress: stat.progress
    }
  }
}
