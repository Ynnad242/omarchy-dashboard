import QtQuick

// A soft shadow made of stacked translucent rounded rectangles, so it draws
// the same with or without shader support. Put it behind a card and point
// `target` at the card's background.
Item {
  id: sh

  property Item target
  property real radius: 0
  property real blur: 16          // how far the shadow spreads, in px
  property real dx: 0             // offset
  property real dy: 0
  property color color: "black"
  property real strength: 0.5     // overall opacity at the core
  property int steps: 10

  x: target ? target.x + dx : 0
  y: target ? target.y + dy : 0
  width: target ? target.width : 0
  height: target ? target.height : 0

  Repeater {
    model: sh.steps
    Rectangle {
      required property int index
      // Largest (faintest) first, so smaller layers stack on top.
      readonly property real f: 1 - index / sh.steps
      readonly property real grow: sh.blur * f
      x: -grow / 2
      y: -grow / 2
      width: sh.width + grow
      height: sh.height + grow
      radius: sh.radius + grow / 2
      color: Qt.rgba(sh.color.r, sh.color.g, sh.color.b, sh.strength / sh.steps * 1.6 * (1 - f * 0.85))
    }
  }
}
