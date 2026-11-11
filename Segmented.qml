import QtQuick
import qs.Commons

// A pill switch whose highlight slides to the picked option.
Item {
  id: seg

  property var t
  property var options: []
  property string current: ""
  signal picked(string key)

  readonly property int currentIndex: {
    for (var i = 0; i < options.length; i++) if (options[i].key === current) return i
    return 0
  }
  property real slotW: t.px(52)

  // Keyboard: Tab to reach, Left / Right to move the selection.
  activeFocusOnTab: true
  Accessible.role: Accessible.PageTabList
  Accessible.name: options.length ? options.map(function(o) { return o.label }).join(", ") : ""
  Keys.onLeftPressed: if (currentIndex > 0) picked(options[currentIndex - 1].key)
  Keys.onRightPressed: if (currentIndex < options.length - 1) picked(options[currentIndex + 1].key)

  width: slotW * options.length + t.px(6)
  height: t.px(26)

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: seg.t.neu ? seg.t.glassInset : "transparent"
    border.width: seg.activeFocus ? seg.t.px(2) : (seg.t.neu ? 0 : 1)
    border.color: seg.activeFocus ? seg.t.accent : seg.t.border
    InsetShade { t: seg.t }
  }

  Rectangle {
    x: seg.t.px(3) + seg.slotW * seg.currentIndex
    y: seg.t.px(3)
    width: seg.slotW
    height: parent.height - seg.t.px(6)
    radius: height / 2
    color: seg.t.raised
    border.width: 0
    SoftShadow { visible: seg.t.neu; z: -1; target: parent; x: seg.t.px(-2); y: seg.t.px(-2); radius: parent.radius; blur: seg.t.px(6); color: seg.t.shadowLight; strength: 0.7 }
    Behavior on x { NumberAnimation { duration: Style.duration(220); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
  }

  Row {
    x: seg.t.px(3)
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
      model: seg.options
      Item {
        required property var modelData
        required property int index
        width: seg.slotW
        height: seg.height
        JText {
          t: seg.t
          anchors.centerIn: parent
          text: parent.modelData.label
          size: 10.5
          color: parent.index === seg.currentIndex ? seg.t.text : seg.t.textFaint
          font.weight: parent.index === seg.currentIndex ? Font.DemiBold : Font.Normal
          Behavior on color { ColorAnimation { duration: Style.duration(160) } }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: seg.picked(parent.modelData.key)
        }
      }
    }
  }
}
