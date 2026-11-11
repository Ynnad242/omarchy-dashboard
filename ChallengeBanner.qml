import QtQuick
import QtQuick.Effects
import qs.Commons

// The exercise the coach set, sitting in the header until it's done. Hold
// "Done" for a second to mark it (so a stray click can't), swap it once for
// something else. Once it's done it simply goes away.
Item {
  id: banner

  property var t
  property var coach
  readonly property var ch: coach ? coach.challenge : null
  readonly property bool active: !!ch
  readonly property color tone: t.yellow

  height: t.px(30)
  opacity: active ? 1 : 0
  visible: opacity > 0.01
  scale: active ? 1 : 0.97
  Behavior on opacity { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
  Behavior on scale { NumberAnimation { duration: Style.duration(260); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

  // A slow breathing glow so it's noticed without being loud.
  RectangularShadow {
    visible: false
    anchors.fill: pill
    radius: pill.radius
    blur: banner.t.px(22)
    color: banner.t.alpha(banner.tone, 0.45)
    SequentialAnimation on opacity {
      running: banner.visible && !!banner.ch
      loops: Animation.Infinite
      NumberAnimation { from: 0.25; to: 0.8; duration: 1600; easing.type: Easing.InOutSine }
      NumberAnimation { from: 0.8; to: 0.25; duration: 1600; easing.type: Easing.InOutSine }
    }
  }

  Rectangle {
    id: pill
    anchors.fill: parent
    radius: height / 2
    color: banner.t.raised
    border.width: 1
    border.color: banner.t.alpha(banner.tone, 0.35)
    Behavior on border.color { ColorAnimation { duration: Style.duration(240) } }

    Rectangle {
      id: chip
      x: banner.t.px(4)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height - banner.t.px(8)
      width: chipText.implicitWidth + banner.t.px(16)
      radius: height / 2
      color: "transparent"
      JText {
        id: chipText
        t: banner.t
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF01E5) + " MOVE"
        size: 9.5
        font.weight: Font.Bold
        font.letterSpacing: 1
        color: banner.tone
      }
    }

    // Message
    Row {
      anchors.left: chip.right
      anchors.leftMargin: banner.t.px(10)
      anchors.right: actions.left
      anchors.rightMargin: banner.t.px(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: banner.t.px(8)
      clip: true

      JText {
        t: banner.t
        text: banner.ch ? banner.ch.reps + " " + banner.ch.unit : ""
        size: 12.5
        font.weight: Font.Bold
      }
      JText {
        t: banner.t
        text: banner.ch ? "·  " + banner.ch.minutes + " min on " + banner.ch.site : ""
        size: 10.5
        color: banner.t.textDim
      }
      JText {
        t: banner.t
        visible: !!banner.ch && banner.ch.tip.length > 0
        text: banner.ch ? "·  " + banner.ch.tip : ""
        size: 10.5
        color: banner.t.textFaint
      }
    }

    Row {
      id: actions
      visible: !!banner.ch
      anchors.right: parent.right
      anchors.rightMargin: banner.t.px(4)
      anchors.verticalCenter: parent.verticalCenter
      spacing: banner.t.px(6)

      Rectangle {
        visible: !!banner.ch && !banner.ch.swapped
        height: pill.height - banner.t.px(8)
        width: swapText.implicitWidth + banner.t.px(18)
        radius: height / 2
        color: swapHover.hovered ? banner.t.inkA(0.1) : banner.t.inkA(0.04)
        border.width: 1
        border.color: banner.t.inkA(0.12)
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        JText { id: swapText; t: banner.t; anchors.centerIn: parent; text: "Swap"; size: 10; color: banner.t.textDim }
        HoverHandler { id: swapHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: banner.coach.swap() }
      }

      // Hold to confirm: the fill sweeps across while held.
      Rectangle {
        id: done
        height: pill.height - banner.t.px(8)
        width: doneText.implicitWidth + banner.t.px(22)
        radius: height / 2
        color: banner.t.alpha(banner.t.green, 0.14)
        border.width: 1
        border.color: banner.t.alpha(banner.t.green, holdArea.containsMouse ? 0.8 : 0.45)
        clip: true
        property real hold: 0

        Rectangle {
          height: parent.height
          width: parent.width * done.hold
          radius: parent.radius
          color: banner.t.alpha(banner.t.green, 0.45)
        }
        JText {
          id: doneText
          t: banner.t
          anchors.centerIn: parent
          text: holdArea.pressed ? "Keep holding…" : "  Hold when done"
          size: 10
          font.weight: Font.DemiBold
          color: banner.t.green
        }

        NumberAnimation {
          id: fill
          target: done
          property: "hold"
          to: 1
          duration: 1000
          onFinished: if (done.hold >= 1) {
            banner.coach.complete()
            done.hold = 0
          }
        }
        NumberAnimation { id: unfill; target: done; property: "hold"; to: 0; duration: Style.duration(180); easing.type: Easing.OutCubic }

        MouseArea {
          id: holdArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPressed: { unfill.stop(); fill.duration = 1000 * (1 - done.hold); fill.start() }
          onReleased: if (done.hold < 1) { fill.stop(); unfill.start() }
          onCanceled: { fill.stop(); unfill.start() }
        }
      }
    }
  }
}
