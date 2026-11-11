import QtQuick
import QtQuick.Shapes

// A circular gauge that sweeps to `value` (0-100) as `progress` runs, Bklit
// style: rounded ends over a faint full track. Live changes glide rather than
// jump.
Item {
  id: ring

  property var t
  property real value: 0
  property real progress: 1
  property color color: t.accent
  property string label: ""
  property real thickness: t.px(7)
  Behavior on value { NumberAnimation { duration: 700; easing.type: Easing.OutQuart } }
  readonly property int cap: t.radiusSmall > 0 ? ShapePath.RoundCap : ShapePath.FlatCap

  readonly property real sweep: 360 * Math.max(0, Math.min(100, value)) / 100 * (1 - Math.pow(1 - Math.max(0, Math.min(1, progress)), 4))

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: ring.t.inkA(0.09)
      strokeWidth: ring.thickness
      fillColor: "transparent"
      capStyle: ring.cap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: ring.width / 2 - ring.thickness; radiusY: radiusX
        startAngle: 0; sweepAngle: 360
      }
    }
    ShapePath {
      strokeColor: ring.color
      strokeWidth: ring.thickness
      fillColor: "transparent"
      capStyle: ring.cap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: ring.width / 2 - ring.thickness; radiusY: radiusX
        startAngle: -90; sweepAngle: ring.sweep
      }
    }
  }

  Column {
    anchors.centerIn: parent
    JText {
      t: ring.t
      anchors.horizontalCenter: parent.horizontalCenter
      text: Math.round(ring.sweep / 3.6) + "%"
      size: 13
      font.weight: Font.Bold
    }
    JText {
      t: ring.t
      anchors.horizontalCenter: parent.horizontalCenter
      text: ring.label
      size: 9
      color: ring.t.textFaint
    }
  }
}
