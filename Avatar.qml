import QtQuick
import QtQuick.Effects

// A round initials avatar tinted from the palette by name, so the same
// person keeps the same color everywhere on the dashboard.
Rectangle {
  id: av

  property var t
  property string name: ""
  property int seed: 0
  property real size: 26
  property bool ring: false
  property string image: ""
  property color ringColor: t.accent

  readonly property var tones: ["accent", "magenta", "green", "yellow", "cyan", "red"]
  readonly property color tone: {
    var h = 0
    for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 997
    return t.tone(tones[h % tones.length])
  }
  readonly property string initials: {
    if (name.charAt(0) === "+") return name
    var parts = name.replace(/[^A-Za-z0-9 ]/g, " ").trim().split(/\s+/)
    if (parts.length === 0 || parts[0] === "") return "?"
    return (parts[0].charAt(0) + (parts.length > 1 ? parts[1].charAt(0) : "")).toUpperCase()
  }

  width: t.px(size)
  height: width
  radius: width / 2
  color: Qt.tint(t.base, av.t.inkA(0.10))
  border.width: ring ? 2 : 1
  border.color: ring ? ringColor : t.surface

  Image {
    id: pic
    anchors.fill: parent
    anchors.margins: 1
    source: av.image
    visible: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: 96
  }
  Rectangle { id: picMask; anchors.fill: pic; radius: width / 2; visible: false; layer.enabled: true }
  MultiEffect {
    anchors.fill: pic
    source: pic
    visible: av.image.length > 0 && pic.status === Image.Ready
    maskEnabled: true
    maskSource: picMask
  }

  JText {
    t: av.t
    visible: !(av.image.length > 0 && pic.status === Image.Ready)
    anchors.centerIn: parent
    text: av.initials
    size: av.size * 0.38
    font.weight: Font.Medium
    color: av.t.textDim
  }
}
