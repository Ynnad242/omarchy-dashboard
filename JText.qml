import QtQuick

// Text that never interprets markup (email, Discord and the network all end
// up here). Sans with tabular figures by default so numbers line up; `mono`
// switches to the monospace face for code-like strings.
Text {
  property var t
  property real size: 13
  property bool mono: false

  textFormat: Text.PlainText
  color: t ? t.text : "white"
  font.family: t ? (mono ? t.mono : t.font) : "sans-serif"
  font.pixelSize: t ? t.px(size) : size
  font.features: { "tnum": 1 }
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}
