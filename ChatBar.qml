import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.Commons

// The Jarvis bar along the bottom: an orb that breathes while idle and spins
// while thinking, an input, suggestion chips, and an answer panel that grows
// up out of the bar and types its reply in. Phase 1 answers from `replyFor`;
// phase 3 swaps that for Claude.
Item {
  id: bar

  property var t
  property bool shown: false
  property int order: 0
  property var replyFor: function(q) { return "" }
  property bool thinking: false
  property string question: ""
  property string answer: ""
  property string typed: ""
  readonly property bool hasAnswer: typed.length > 0 || thinking
  readonly property bool inputFocused: input.activeFocus
  property var suggestions: ["What do I need to do today?", "Anything important in my inbox?", "How much screen time today?"]

  signal escaped()
  onThinkingChanged: if (spin.running) spin.restart()

  function focusInput() { input.forceActiveFocus() }
  function clear() {
    thinkTimer.stop(); typeTimer.stop()
    thinking = false; question = ""; answer = ""; typed = ""; input.text = ""
  }
  function ask(q) {
    q = String(q || "").trim()
    if (!q.length) return
    question = q
    input.text = ""
    typed = ""
    answer = ""
    thinking = true
    thinkTimer.restart()
  }

  Timer {
    id: thinkTimer
    interval: 900
    onTriggered: {
      bar.answer = bar.replyFor(bar.question)
      bar.thinking = false
      typeTimer.restart()
    }
  }
  Timer {
    id: typeTimer
    interval: 16
    repeat: true
    onTriggered: {
      if (bar.typed.length >= bar.answer.length) { stop(); return }
      bar.typed = bar.answer.slice(0, bar.typed.length + 3)
    }
  }

  // Entrance, same wave as the cards.
  opacity: 0
  property real rise: t.px(22)
  transform: Translate { y: bar.rise }
  onShownChanged: {
    if (shown) { exitAnim.stop(); enterAnim.restart() }
    else { enterAnim.stop(); exitAnim.restart() }
  }
  SequentialAnimation {
    id: enterAnim
    ScriptAction { script: { bar.opacity = 0; bar.rise = bar.t.px(22) } }
    PauseAnimation { duration: Style.duration(bar.order * 42) }
    ParallelAnimation {
      NumberAnimation { target: bar; property: "opacity"; to: 1; duration: Style.duration(260); easing.type: Easing.OutCubic }
      NumberAnimation { target: bar; property: "rise"; to: 0; duration: Style.duration(300); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }
  }
  NumberAnimation { id: exitAnim; target: bar; property: "opacity"; to: 0; duration: Style.duration(120); easing.type: Easing.OutCubic }

  // Answer panel, growing upward from the bar.
  Rectangle {
    id: answerPanel
    anchors.left: field.left
    anchors.right: field.right
    anchors.bottom: field.top
    anchors.bottomMargin: bar.t.px(10)
    readonly property real wanted: bar.hasAnswer ? Math.min(answerCol.implicitHeight + bar.t.px(28), bar.t.px(300)) : 0
    height: wanted
    Behavior on height { NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
    opacity: bar.hasAnswer ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
    visible: height > 1
    radius: bar.t.radius
    color: bar.t.raised
    border.width: 1
    border.color: bar.t.borderStrong
    clip: true

    Column {
      id: answerCol
      x: bar.t.px(18)
      y: bar.t.px(14)
      width: parent.width - bar.t.px(36)
      spacing: bar.t.px(8)
      JText {
        t: bar.t
        width: parent.width
        text: "You  ·  " + bar.question
        size: 10.5
        color: bar.t.textFaint
      }
      JText {
        t: bar.t
        width: parent.width
        visible: bar.thinking
        text: "Thinking…"
        size: 12.5
        color: bar.t.accent
        SequentialAnimation on opacity {
          running: bar.thinking
          loops: Animation.Infinite
          NumberAnimation { from: 1; to: 0.4; duration: 600; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.4; to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
      }
      JText {
        t: bar.t
        width: parent.width
        visible: !bar.thinking
        text: bar.typed
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        size: 12.5
        lineHeight: 1.25
      }
    }

    JText {
      t: bar.t
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: bar.t.px(12)
      text: "×"
      size: 15
      color: closeArea.containsMouse ? bar.t.text : bar.t.textFaint
      MouseArea { id: closeArea; anchors.fill: parent; anchors.margins: -bar.t.px(6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.clear() }
    }
  }

  // Suggestions above the field while it is focused and empty.
  Row {
    anchors.left: field.left
    anchors.leftMargin: bar.t.px(64)
    anchors.bottom: field.top
    anchors.bottomMargin: bar.t.px(10)
    spacing: bar.t.px(8)
    readonly property bool on: input.activeFocus && !input.text.length && !bar.hasAnswer
    opacity: on ? 1 : 0
    visible: opacity > 0
    transform: Translate { y: parent.on ? 0 : bar.t.px(6) }
    Behavior on opacity { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
    Repeater {
      model: bar.suggestions
      Rectangle {
        required property string modelData
        height: bar.t.px(28)
        width: sText.implicitWidth + bar.t.px(22)
        radius: height / 2
        color: sh.hovered ? bar.t.raised : bar.t.surface
        border.width: 1
        border.color: sh.hovered ? bar.t.borderStrong : bar.t.border
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        JText { id: sText; t: bar.t; anchors.centerIn: parent; text: parent.modelData; size: 10.5; color: bar.t.textDim }
        HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.ask(parent.modelData) }
      }
    }
  }


  Rectangle {
    id: field
    anchors.fill: parent
    radius: height / 2
    color: bar.t.neu ? bar.t.glassInset : bar.t.surface
    InsetShade { t: bar.t }
    border.width: 1
    border.color: input.activeFocus ? bar.t.borderStrong : bar.t.border
    Behavior on color { ColorAnimation { duration: Style.duration(160) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(160) } }

    RectangularShadow {
      visible: false
      anchors.fill: parent
      z: -1
      radius: parent.radius
      blur: bar.t.px(30)
      color: bar.t.alpha(bar.t.accent, 0.28)
      opacity: input.activeFocus ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(200) } }
    }

    // The orb
    Item {
      id: orb
      x: bar.t.px(10)
      anchors.verticalCenter: parent.verticalCenter
      width: parent.height - bar.t.px(16)
      height: width

      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 1.5; height: width; radius: width / 2
        visible: false
        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop { position: 0; color: bar.t.alpha(bar.t.accent, 0.0) }
          GradientStop { position: 0.5; color: bar.t.alpha(bar.t.accent, 0.10) }
          GradientStop { position: 1; color: bar.t.alpha(bar.t.accent, 0.0) }
        }
      }
      Rectangle {
        id: core
        visible: false
        anchors.centerIn: parent
        width: parent.width * 0.62; height: width; radius: width / 2
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.lighter(bar.t.accent, 1.35) }
          GradientStop { position: 1; color: bar.t.magenta }
        }
        SequentialAnimation on scale {
          running: bar.shown
          loops: Animation.Infinite
          NumberAnimation { from: 0.9; to: 1.05; duration: bar.thinking ? 420 : 1800; easing.type: Easing.InOutSine }
          NumberAnimation { from: 1.05; to: 0.9; duration: bar.thinking ? 420 : 1800; easing.type: Easing.InOutSine }
        }
      }
      RectangularShadow {
        visible: false
        anchors.fill: core
        radius: core.radius
        blur: bar.t.px(14)
        color: bar.t.alpha(bar.t.accent, 0.7)
        z: -1
      }
      Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: bar.thinking ? bar.t.accent : bar.t.textFaint
          strokeWidth: bar.t.px(2)
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: arc.width / 2; centerY: arc.height / 2
            radiusX: arc.width / 2 - bar.t.px(2); radiusY: radiusX
            startAngle: 0; sweepAngle: bar.thinking ? 100 : 360
          }
        }
        RotationAnimation on rotation {
          id: spin
          running: bar.thinking
          loops: Animation.Infinite
          from: 0; to: 360
          duration: bar.thinking ? 700 : 6000
        }
      }
    }

    TextInput {
      id: input
      anchors.left: orb.right
      anchors.leftMargin: bar.t.px(14)
      anchors.right: hints.left
      anchors.rightMargin: bar.t.px(12)
      anchors.verticalCenter: parent.verticalCenter
      color: bar.t.text
      font.family: bar.t.font
      font.pixelSize: bar.t.px(13.5)
      selectionColor: bar.t.alpha(bar.t.accent, 0.4)
      clip: true
      maximumLength: 2000
      Accessible.role: Accessible.EditableText
      Accessible.name: "Ask Jarvis"
      Keys.onReturnPressed: bar.ask(text)
      Keys.onEnterPressed: bar.ask(text)
      Keys.onEscapePressed: function(event) {
        if (text.length) text = ""
        else if (bar.hasAnswer) bar.clear()
        else bar.escaped()
      }

      JText {
        t: bar.t
        anchors.fill: parent
        visible: !input.text.length
        text: "Ask Jarvis anything…"
        size: 13.5
        color: bar.t.textFaint
      }
    }

    Row {
      id: hints
      anchors.right: parent.right
      anchors.rightMargin: bar.t.px(18)
      anchors.verticalCenter: parent.verticalCenter
      spacing: bar.t.px(8)
      Repeater {
        model: input.activeFocus ? [["Enter", "ask"], ["Esc", "back"]] : [["/", "focus"], ["Esc", "close"]]
        Row {
          required property var modelData
          spacing: bar.t.px(5)
          Rectangle {
            height: bar.t.px(20)
            width: Math.max(height, k.implicitWidth + bar.t.px(10))
            radius: bar.t.px(5)
            color: bar.t.inkA(0.06)
            border.width: 1
            border.color: bar.t.inkA(0.1)
            JText { id: k; t: bar.t; anchors.centerIn: parent; text: parent.parent.modelData[0]; size: 9.5; color: bar.t.textDim }
          }
          JText { t: bar.t; height: bar.t.px(20); text: parent.modelData[1]; size: 10; color: bar.t.textFaint }
        }
      }
      Rectangle { width: 1; height: bar.t.px(20); color: bar.t.inkA(0.08) }
      JText { t: bar.t; height: bar.t.px(20); text: String.fromCodePoint(0xF0674) + " Claude"; size: 10.5; color: bar.t.accent }
    }

    TapHandler { onTapped: input.forceActiveFocus() }
  }
}
