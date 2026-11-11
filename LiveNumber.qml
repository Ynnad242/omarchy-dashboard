import QtQuick
import qs.Commons

// A number that glides to each new value and flashes green or red for a
// moment when it ticks up or down, like a trading screen.
JText {
  id: live

  property real value: NaN
  property var format: function(v) { return String(v) }
  property bool flash: true
  property color baseColor: t ? t.text : "white"
  property real shown: NaN

  text: isNaN(shown) ? "—" : format(shown)
  color: baseColor

  Behavior on shown {
    enabled: !isNaN(live.shown)
    NumberAnimation { duration: Style.duration(600); easing.type: Easing.OutCubic }
  }

  onValueChanged: {
    if (isNaN(value)) return
    var old = shown
    shown = value
    if (!flash || isNaN(old) || old === value || !t) return
    flashColor.to = value > old ? t.green : t.red
    flashAnim.restart()
  }

  Component.onCompleted: if (!isNaN(value)) shown = value

  SequentialAnimation {
    id: flashAnim
    ColorAnimation { id: flashColor; target: live; property: "color"; duration: Style.duration(90) }
    PauseAnimation { duration: 350 }
    ColorAnimation { target: live; property: "color"; to: live.baseColor; duration: Style.duration(700); easing.type: Easing.OutCubic }
  }
}
