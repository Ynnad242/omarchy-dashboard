import QtQuick
import QtQuick.Effects
import qs.Commons

// The big chart: screen time per hour, day or week with the current one lit
// in the accent, and the apps that took the most of it beside the bars.
GlassCard {
  id: card

  property var chartData: ({})
  property string range: "week"
  readonly property var bars: (chartData[range] && chartData[range].bars) || []
  readonly property int current: chartData[range] ? chartData[range].current : -1
  readonly property var apps: chartData.apps || []
  property int hoverIndex: -1

  signal rangePicked(string range)

  title: "Screen time"
  icon: ""

  function hours(m) {
    m = Math.round(m)
    if (m < 60) return m + "m"
    return Math.floor(m / 60) + "h " + (m % 60 < 10 ? "0" : "") + (m % 60) + "m"
  }

  readonly property real maxMinutes: {
    var m = 60
    for (var i = 0; i < bars.length; i++) m = Math.max(m, bars[i].minutes)
    var step = m > 240 ? 120 : 60
    return Math.ceil(m / step) * step
  }

  headerExtra: [
    Segmented {
      t: card.t
      options: [{ key: "day", label: "Day" }, { key: "week", label: "Week" }, { key: "month", label: "Month" }]
      current: card.range
      onPicked: function(key) { card.rangePicked(key) }
    }
  ]

  Item {
    anchors.fill: parent

    Item {
      id: plot
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * 0.68

      readonly property real axisW: card.t.px(46)
      readonly property real labelH: card.t.px(22)
      readonly property real topPad: card.t.px(26)
      readonly property real chartH: height - labelH - topPad

      Repeater {
        model: 5
        Item {
          required property int index
          x: 0
          y: plot.topPad + plot.chartH * (1 - index / 4)
          width: plot.width
          JText {
            t: card.t
            anchors.verticalCenter: parent.top
            width: plot.axisW
            text: card.hours(card.maxMinutes * index / 4).replace(" 00m", "")
            size: 9.5
            color: card.t.textFaint
          }
          // Dashed guides; the baseline stays solid.
          Canvas {
            x: plot.axisW
            y: -1
            width: plot.width - plot.axisW
            height: 2
            readonly property color ink: card.t.inkA(index === 0 ? 0.12 : 0.08)
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d"); ctx.reset()
              ctx.strokeStyle = ink; ctx.lineWidth = 1
              if (index > 0) ctx.setLineDash([2, 5])
              ctx.beginPath(); ctx.moveTo(0, 1.5); ctx.lineTo(width, 1.5); ctx.stroke()
            }
          }
        }
      }

      Item {
        id: lane
        x: plot.axisW
        y: plot.topPad
        width: plot.width - plot.axisW
        height: plot.chartH
        readonly property real slot: card.bars.length > 0 ? width / card.bars.length : width
        readonly property real barW: Math.min(slot * 0.56, card.t.px(46))

        // A count, not the array: screen time sends a fresh array every few
        // seconds, and an array model would rebuild the bars (replaying their
        // grow-in) each time. With a count they stay and just tween to the
        // new height. They're rebuilt only when Day/Week/Month changes.
        Repeater {
          model: card.bars.length
          Item {
            id: col
            required property int index
            readonly property var modelData: card.bars[index] || ({ label: "", minutes: 0 })
            readonly property bool isCurrent: index === card.current
            readonly property bool isHover: index === card.hoverIndex
            // Days (or hours) still to come: drawn as a striped stub.
            readonly property bool future: card.current >= 0 && index > card.current && modelData.minutes === 0
            property real minutes: modelData.minutes
            property real grow: 0
            Behavior on minutes { NumberAnimation { duration: Style.duration(320); easing.type: Easing.OutCubic } }

            x: lane.slot * index
            width: lane.slot
            height: lane.height

            Component.onCompleted: growAnim.start()
            SequentialAnimation {
              id: growAnim
              PauseAnimation { duration: Style.duration(col.index * 45) }
              // GSAP-style: power3.out, staggered left to right.
              NumberAnimation { target: col; property: "grow"; to: 1; duration: Style.duration(800); easing.type: Easing.OutQuart }
            }

            readonly property real entrance: card.ease((card.progress * 1.5) - col.index * 0.05)
            readonly property real barH: (col.future ? lane.barW * 0.9 : Math.max(lane.barW * 0.5, lane.height * col.minutes / card.maxMinutes)) * col.entrance * col.grow

            RectangularShadow {
              visible: false
              anchors.fill: bar
              radius: bar.radius
              blur: card.t.px(26)
              color: card.t.alpha(card.t.accent, 0.55)
              opacity: col.entrance
            }

            Rectangle {
              id: bar
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              width: lane.barW
              height: col.barH
              // Pill bars, like Bklit's; square when the style has square corners.
              radius: card.t.radiusSmall > 0 ? Math.min(width, height) / 2 : 0
              color: col.future ? "transparent" : col.isCurrent ? card.t.accent : card.t.inkA(col.isHover ? 0.20 : 0.13)
              border.width: col.future ? 1 : 0
              border.color: card.t.inkA(0.14)
              clip: true
              Behavior on color { ColorAnimation { duration: 120 } }
              // Diagonal stripes for what hasn't happened yet.
              Canvas {
                visible: col.future
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                  var ctx = getContext("2d"); ctx.reset()
                  ctx.strokeStyle = card.t.inkA(0.16); ctx.lineWidth = 1.5
                  var step = card.t.px(5)
                  for (var x = -height; x < width; x += step) { ctx.beginPath(); ctx.moveTo(x, height); ctx.lineTo(x + height, 0); ctx.stroke() }
                }
              }
            }

            JText {
              t: card.t
              anchors.horizontalCenter: parent.horizontalCenter
              y: parent.height + card.t.px(6)
              text: col.modelData.hour !== undefined ? card.t.hourLabel(col.modelData.hour) : col.modelData.label
              size: 10
              color: col.isCurrent ? card.t.text : card.t.textFaint
              font.weight: col.isCurrent ? Font.DemiBold : Font.Normal
            }

            // Value bubble above the hovered or current bar.
            Rectangle {
              readonly property bool on: col.isHover || (card.hoverIndex < 0 && col.isCurrent)
              anchors.horizontalCenter: parent.horizontalCenter
              y: parent.height - col.barH - height - card.t.px(8)
              width: bubbleText.implicitWidth + card.t.px(14)
              height: card.t.px(22)
              radius: card.t.px(7)
              color: card.t.raised
              border.width: 1
              border.color: card.t.border
              opacity: on && col.entrance > 0.9 ? 1 : 0
              scale: on ? 1 : 0.95
              Behavior on opacity { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
              Behavior on scale { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
              JText { id: bubbleText; t: card.t; anchors.centerIn: parent; text: card.hours(col.modelData.minutes); size: 10.5; font.weight: Font.DemiBold }
            }

            HoverHandler {
              onHoveredChanged: card.hoverIndex = hovered ? col.index : (card.hoverIndex === col.index ? -1 : card.hoverIndex)
            }
          }
        }
      }
    }

    // Top apps
    Item {
      anchors.left: plot.right
      anchors.leftMargin: card.t.px(22)
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: -card.t.px(11)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: card.t.inkA(0.06)
      }

      JText {
        anchors.centerIn: parent
        visible: card.apps.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        t: card.t
        text: "Tracking started today.\nApps show up here as you use them."
        size: 10.5
        color: card.t.textFaint
      }
      JText {
        id: appsTitle
        t: card.t
        text: "Top apps"
        size: 11
        color: card.t.textDim
      }

      Column {
        anchors.top: appsTitle.bottom
        anchors.topMargin: card.t.px(12)
        width: parent.width
        spacing: card.t.px(12)

        Repeater {
          model: card.apps.length
          Item {
            id: app
            required property int index
            readonly property var modelData: card.apps[index] || ({ name: "", minutes: 0 })
            width: parent.width
            height: card.t.px(34)
            readonly property real share: modelData.minutes / Math.max(1, card.apps[0].minutes)
            readonly property real e: card.ease(card.progress * 1.6 - 0.2 - index * 0.08)
            opacity: e
            transform: Translate { x: (1 - app.e) * card.t.px(10) }

            Rectangle {
              id: appIcon
              width: 0; height: card.t.px(24); visible: false
              radius: card.t.px(7)
              color: card.t.alpha(card.t.tone(app.modelData.tone), 0.16)
              JText { t: card.t; anchors.centerIn: parent; text: app.modelData.icon || app.modelData.name.charAt(0); size: 11; color: card.t.tone(app.modelData.tone) }
            }
            JText {
              t: card.t
              anchors.left: appIcon.right
              anchors.leftMargin: 0
              anchors.right: appTime.left
              y: 0
              height: card.t.px(16)
              text: app.modelData.name
              size: 11.5
            }
            JText {
              id: appTime
              t: card.t
              anchors.right: parent.right
              y: 0
              height: card.t.px(16)
              text: card.hours(app.modelData.minutes)
              size: 10.5
              color: card.t.textDim
            }
            Rectangle {
              anchors.left: appIcon.right
              anchors.leftMargin: 0
              anchors.right: parent.right
              y: card.t.px(22)
              height: card.t.px(4)
              radius: height / 2
              color: card.t.inkA(0.06)
              Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * app.share * app.e
                color: app.index === 0 ? card.t.accent : card.t.alpha(card.t.text, 0.28)
              }
            }
          }
        }
      }
    }
  }
}
