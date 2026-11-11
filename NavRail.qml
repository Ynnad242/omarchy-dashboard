import QtQuick
import QtQuick.Effects
import qs.Commons

// The floating icon rail on the left. Picking a section spotlights its cards
// and fades the rest; the highlight slides between icons. Keys 1-6 too.
Item {
  id: rail

  property var t
  property bool shown: false
  property int current: 0
  property var items: []
  signal picked(int index)

  readonly property real btn: t.px(40)
  width: btn + t.px(12)
  height: col.height + t.px(12)

  opacity: shown ? 1 : 0
  property real slide: shown ? 0 : -t.px(16)
  transform: Translate { x: rail.slide }
  Behavior on opacity { NumberAnimation { duration: Style.duration(rail.shown ? 260 : 120); easing.type: Easing.OutCubic } }
  Behavior on slide { NumberAnimation { duration: Style.duration(300); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

  SoftShadow { visible: rail.t.neu; target: railBg; radius: railBg.radius; blur: rail.t.px(18); dx: -rail.t.px(7); dy: -rail.t.px(7); color: rail.t.shadowLight; strength: 0.85 }
  SoftShadow { visible: rail.t.neu; target: railBg; radius: railBg.radius; blur: rail.t.px(18); dx: rail.t.px(7); dy: rail.t.px(7); color: rail.t.shadowDark; strength: 0.95 }

  Rectangle {
    id: railBg
    anchors.fill: parent
    radius: rail.t.discord ? rail.t.px(16) : width / 2
    color: rail.t.discord ? "#1e1f22" : rail.t.surface
    border.width: 1
    border.color: rail.t.border
  }

  function slotOf(i) {
    var n = 0
    for (var k = 0; k < i && k < items.length; k++) if (!items[k].hidden) n++
    return n
  }

  Rectangle {
    id: highlight
    x: rail.t.px(6)
    // Hidden pages take no slot, so count only the shown ones above.
    y: rail.t.px(6) + rail.slotOf(rail.current) * (rail.btn + col.spacing)
    width: rail.btn
    height: rail.btn
    radius: width / 2
    color: rail.t.neu ? rail.t.glassInset : rail.t.raised
    border.width: 0
    InsetShade { t: rail.t }
    Behavior on y { NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
  }
  RectangularShadow {
    visible: false
    anchors.fill: highlight
    radius: highlight.radius
    blur: rail.t.px(16)
    color: rail.t.alpha(rail.t.accent, 0.4)
    z: -1
  }

  Column {
    id: col
    x: rail.t.px(6)
    y: rail.t.px(6)
    spacing: rail.t.px(6)
    Repeater {
      model: rail.items
      Item {
        id: it
        required property var modelData
        required property int index
        visible: !it.modelData.hidden
        width: rail.btn
        height: rail.btn
        Accessible.role: Accessible.PageTab
        Accessible.name: it.modelData.label
        Accessible.selected: it.index === rail.current
        Accessible.onPressAction: rail.picked(it.index)

        JText {
          t: rail.t
          anchors.centerIn: parent
          text: it.modelData.icon
          size: 14
          color: it.index === rail.current ? rail.t.text : (h.hovered ? rail.t.textDim : rail.t.textFaint)
          Behavior on color { ColorAnimation { duration: Style.duration(140) } }
        }

        // Tooltip
        Rectangle {
          x: rail.btn + rail.t.px(14)
          anchors.verticalCenter: parent.verticalCenter
          height: rail.t.px(24)
          width: tip.implicitWidth + rail.t.px(16)
          // Inverted (text-colored label, canvas-colored words) so it reads
          // clearly over any card, in any style.
          radius: Math.min(rail.t.px(7), rail.t.radiusSmall + rail.t.px(2))
          color: rail.t.text
          border.width: 0
          opacity: h.hovered ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
          JText { id: tip; t: rail.t; anchors.centerIn: parent; text: it.modelData.label + "   " + (it.index + 1); size: 10.5; color: rail.t.base; font.weight: Font.Medium }
        }

        HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: rail.picked(it.index) }
      }
    }
  }
}
