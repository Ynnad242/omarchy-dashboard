import QtQuick

// A settings row: a label (and an optional hint under it) on the left, one
// control on the right.
Item {
  id: r

  property var t
  property string label: ""
  property string hint: ""
  property color hintColor: t.textDim
  default property alias control: slot.data

  width: parent ? parent.width : 0
  height: Math.max(t.px(hint.length ? 48 : 38), lab.height + (hint.length ? hintText.height + t.px(10) : 0))

  JText {
    id: lab
    t: r.t
    y: r.hint.length ? r.t.px(4) : (r.height - height) / 2
    width: r.width - slot.width - r.t.px(16)
    text: r.label
    size: 12.5
  }
  JText {
    id: hintText
    visible: r.hint.length > 0
    t: r.t
    anchors.top: lab.bottom
    anchors.topMargin: r.t.px(2)
    width: lab.width
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    maximumLineCount: 3
    text: r.hint
    size: 10.5
    color: r.hintColor
  }
  Item {
    id: slot
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
}
