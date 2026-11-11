import QtQuick
import qs.Commons

// A card. Its surface depends on the style:
//   flat   hairline border on a flat surface
//   glass  translucent pane, bright top rim and sheen
//   neu    the canvas itself, raised by a light and a dark shadow
//   clay   puffy and very round: inner highlight, inner shade, soft drop
//   y2k    glossy candy shell with a bright rim
//   swiss  no box at all: a heavy rule on top and an uppercase label
//   wabi   soft paper with a faint shadow
// It fades and rises a few pixels into place when `shown` turns on (`order`
// staggers neighbours), then runs `progress` 0 to 1 for content that draws in.
Item {
  id: card

  property var t
  property bool shown: false
  property int order: 0
  property bool dimmed: false
  property string title: ""
  property string icon: ""            // accepted for compatibility, not drawn
  property color iconColor: t.accent  // ditto
  property string action: ""
  property bool hoverable: true
  property bool sample: false
  property real pad: t.px(18)
  property real progress: 0
  property real rise: t.px(8)
  readonly property bool hovered: hover.hovered
  readonly property real headerHeight: title.length > 0 ? t.px(22) : 0
  default property alias content: body.data
  property alias headerExtra: extra.data

  signal actionClicked()

  function ease(x) { x = Math.max(0, Math.min(1, x)); return 1 - Math.pow(1 - x, 3) }

  opacity: 0
  visible: opacity > 0.001
  transform: Translate { y: card.rise }

  onShownChanged: {
    if (shown) { exit.stop(); enter.restart() }
    else { enter.stop(); exit.restart() }
  }
  Component.onCompleted: if (shown) enter.restart()

  SequentialAnimation {
    id: enter
    ScriptAction { script: { card.opacity = 0; card.rise = card.t.px(8); card.progress = 0 } }
    PauseAnimation { duration: Style.duration(card.order * 30) }
    ParallelAnimation {
      NumberAnimation { target: card; property: "opacity"; to: 1; duration: Style.duration(220); easing.type: Easing.OutCubic }
      NumberAnimation { target: card; property: "rise"; to: 0; duration: Style.duration(260); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
      SequentialAnimation {
        PauseAnimation { duration: Style.duration(60) }
        NumberAnimation { target: card; property: "progress"; to: 1; duration: Style.duration(700) }
      }
    }
  }
  NumberAnimation { id: exit; target: card; property: "opacity"; to: 0; duration: Style.duration(110); easing.type: Easing.OutCubic }

  // ---- shadows (behind the surface) ----------------------------------------------
  SoftShadow { visible: card.t.neu; target: bg; radius: bg.radius; blur: card.t.px(22); dx: -card.t.px(9); dy: -card.t.px(9); color: card.t.shadowLight; strength: 0.85 }
  SoftShadow { visible: card.t.neu; target: bg; radius: bg.radius; blur: card.t.px(22); dx: card.t.px(9); dy: card.t.px(9); color: card.t.shadowDark; strength: 0.95 }
  SoftShadow { visible: card.t.clay; target: bg; radius: bg.radius; blur: card.t.px(36); dx: 0; dy: card.t.px(16); color: "black"; strength: 0.8 }
  SoftShadow { visible: card.t.y2k; target: bg; radius: bg.radius; blur: card.t.px(26); dx: 0; dy: card.t.px(10); color: "#2a0a4a"; strength: 0.7 }
  SoftShadow { visible: card.t.wabi; target: bg; radius: bg.radius; blur: card.t.px(16); dx: 0; dy: card.t.px(4); color: "#3a2a1a"; strength: 0.14 }

  // ---- the surface --------------------------------------------------------------------
  Rectangle {
    id: bg
    anchors.fill: parent
    radius: card.t.radius
    color: card.t.swiss ? "transparent" : (card.hoverable && card.hovered ? card.t.surfaceHover : card.t.surface)
    border.width: card.t.neu || card.t.clay || card.t.swiss ? 0 : card.t.y2k ? card.t.px(1.5) : 1
    border.color: card.hoverable && card.hovered ? card.t.borderStrong : card.t.border
    Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }
    Behavior on color { ColorAnimation { duration: Style.duration(140) } }

    // glass: sheen and a bright rim
    Rectangle {
      visible: card.t.glassy
      anchors.fill: parent
      anchors.margins: 1
      radius: parent.radius - 1
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
        GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.02) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
      }
    }
    Rectangle {
      visible: card.t.glassy
      x: parent.radius; width: parent.width - parent.radius * 2
      y: 0; height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
      }
    }

    // clay: light catching the top, shade pooling at the bottom
    Rectangle {
      visible: card.t.clay
      anchors.fill: parent
      radius: parent.radius
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
        GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
        GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
      }
    }
    Rectangle {
      visible: card.t.clay
      anchors.fill: parent
      anchors.margins: card.t.px(2)
      radius: parent.radius - card.t.px(2)
      color: "transparent"
      border.width: card.t.px(2)
      border.color: Qt.rgba(1, 1, 1, 0.07)
    }

    // y2k: candy gloss over the top half
    Rectangle {
      visible: card.t.y2k
      anchors.fill: parent
      anchors.margins: card.t.px(1.5)
      radius: parent.radius - card.t.px(1.5)
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.30) }
        GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.06) }
        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.10) }
      }
    }

    // swiss: a heavy rule across the top instead of a box
    Rectangle {
      visible: card.t.swiss
      width: parent.width
      height: card.t.px(3)
      color: card.hoverable && card.hovered ? card.t.accent : card.t.text
      Behavior on color { ColorAnimation { duration: Style.duration(140) } }
    }
  }

  // ---- header -------------------------------------------------------------------------
  Item {
    id: header
    visible: card.title.length > 0
    x: card.t.swiss ? 0 : card.pad
    y: card.pad - card.t.px(2)
    width: card.width - x * 2
    height: card.headerHeight

    JText {
      id: titleText
      t: card.t
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: card.t.swiss ? card.title.toUpperCase() : card.title
      size: card.t.swiss ? 11.5 : 12.5
      font.weight: card.t.swiss ? Font.Bold : Font.Medium
      font.letterSpacing: card.t.swiss ? 1.2 : 0
      font.italic: card.t.wabi
      color: card.t.swiss ? card.t.text : card.t.textDim
    }
    JText {
      visible: card.sample
      anchors.left: titleText.right
      anchors.leftMargin: card.t.px(8)
      anchors.verticalCenter: parent.verticalCenter
      t: card.t
      text: "Sample data"
      size: 10.5
      color: card.t.textFaint
    }

    Row {
      id: extra
      anchors.right: actionLabel.visible ? actionLabel.left : parent.right
      anchors.rightMargin: actionLabel.visible ? card.t.px(14) : 0
      anchors.verticalCenter: parent.verticalCenter
      spacing: card.t.px(8)
    }

    JText {
      id: actionLabel
      t: card.t
      visible: card.action.length > 0
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: card.action
      size: 11.5
      color: actionArea.containsMouse ? card.t.text : card.t.textFaint
      Behavior on color { ColorAnimation { duration: Style.duration(120) } }
      MouseArea {
        id: actionArea
        anchors.fill: parent
        anchors.margins: -card.t.px(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.actionClicked()
      }
    }
  }

  Item {
    id: body
    x: card.t.swiss ? 0 : card.pad
    y: card.pad + (card.title.length > 0 ? card.headerHeight + card.t.px(12) : 0)
    width: card.width - x * 2
    height: card.height - y - (card.t.swiss ? 0 : card.pad)
  }

  HoverHandler { id: hover; enabled: card.hoverable }
}
