import QtQuick

// Neumorphism's "pressed in" look for fields, tracks and wells: shade along
// the top edge, light along the bottom, as if lit from the top-left. Drop it
// inside any rounded rectangle; it only shows in the neu style.
Rectangle {
  property var t
  visible: t.neu
  anchors.fill: parent
  radius: parent.radius
  gradient: Gradient {
    GradientStop { position: 0.0; color: t.alpha(t.shadowDark, 0.75) }
    GradientStop { position: 0.28; color: t.alpha(t.shadowDark, 0.0) }
    GradientStop { position: 0.72; color: t.alpha(t.shadowLight, 0.0) }
    GradientStop { position: 1.0; color: t.alpha(t.shadowLight, 0.55) }
  }
}
