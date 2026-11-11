import QtQuick
import qs.Commons

// An on/off switch in the theme accent.
Item {
  id: tg

  property var t
  property bool on: false
  signal flipped(bool on)

  width: t.px(38)
  height: t.px(22)

  // Keyboard and screen readers: Tab to reach, Space or Enter to flip.
  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.checked: on
  Accessible.onToggleAction: tg.flipped(!tg.on)
  Keys.onPressed: function(e) { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { tg.flipped(!tg.on); e.accepted = true } }

  Rectangle {
    visible: tg.activeFocus
    anchors.fill: parent
    anchors.margins: -tg.t.px(3)
    radius: tg.t.swiss ? 0 : height / 2
    color: "transparent"
    border.width: tg.t.px(2)
    border.color: tg.t.accent
  }

  Rectangle {
    anchors.fill: parent
    radius: tg.t.swiss ? 0 : height / 2
    color: tg.on ? (tg.t.discord ? tg.t.green : tg.t.accent) : (tg.t.neu ? tg.t.glassInset : tg.t.inkA(0.12))
    Behavior on color { ColorAnimation { duration: Style.duration(160) } }
    InsetShade { t: tg.t; visible: tg.t.neu && !tg.on }
  }
  Rectangle {
    width: parent.height - tg.t.px(6); height: width
    radius: tg.t.swiss ? 0 : width / 2
    y: tg.t.px(3)
    x: tg.on ? parent.width - width - tg.t.px(3) : tg.t.px(3)
    color: "white"
    Behavior on x { NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: tg.flipped(!tg.on)
  }
}
