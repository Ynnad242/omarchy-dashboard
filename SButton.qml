import QtQuick
import qs.Commons

// A small button. `kind`: "primary" (accent), "danger" (red outline) or
// "plain". `busy` shows `busyLabel` and ignores clicks.
Rectangle {
  id: b

  property var t
  property string label: ""
  property string busyLabel: "Working…"
  property string kind: "plain"
  property bool busy: false
  property bool enabled: true
  signal clicked()

  readonly property bool live: enabled && !busy
  height: t.px(30)
  width: txt.implicitWidth + t.px(26)
  radius: Math.min(height / 2, t.radiusSmall + t.px(4))
  color: kind === "primary" ? (live ? (area.containsMouse ? Qt.lighter(t.accent, 1.08) : t.accent) : t.inkA(0.06))
       : area.containsMouse && live ? t.inkA(0.08) : t.inkA(0.04)
  border.width: kind === "primary" && live ? 0 : 1
  border.color: kind === "danger" ? t.alpha(t.red, live ? 0.7 : 0.35) : b.activeFocus ? t.accent : t.inkA(0.14)
  opacity: enabled ? 1 : 0.55
  Behavior on color { ColorAnimation { duration: Style.duration(120) } }

  activeFocusOnTab: live
  Accessible.role: Accessible.Button
  Accessible.name: b.label
  Accessible.onPressAction: if (b.live) b.clicked()
  Keys.onPressed: function(e) { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return) && b.live) { b.clicked(); e.accepted = true } }

  JText {
    id: txt
    t: b.t
    anchors.centerIn: parent
    text: b.busy ? b.busyLabel : b.label
    size: 11.5
    font.weight: Font.DemiBold
    color: b.kind === "primary" ? (b.live ? (b.t.dark ? b.t.base : "white") : b.t.textFaint) : b.kind === "danger" ? b.t.red : b.t.text
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: b.live ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (b.live) b.clicked()
  }
}
