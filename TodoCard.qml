import QtQuick
import qs.Commons

// The built-in checklist. Click a row (or its box) to tick it, type in the
// field at the bottom and press Enter to add one. The list is saved to
// ~/.local/state/jarvis/todos.json.
GlassCard {
  id: card

  // A ListModel with roles title, done, due, so ticking and adding animate
  // in place instead of rebuilding the list.
  property ListModel todos
  property var dueLabel: function(iso) { return iso }
  property var dueState: function(iso) { return "" }
  signal toggled(int index)
  signal added(string text)
  signal removed(int index)

  property int total: 0
  property int doneCount: 0
  function recount() {
    var c = 0
    for (var i = 0; i < todos.count; i++) if (todos.get(i).done) c++
    doneCount = c
    total = todos.count
  }
  Component.onCompleted: recount()
  Connections {
    target: card.todos
    function onDataChanged() { card.recount() }
    function onRowsInserted() { card.recount() }
    function onRowsRemoved() { card.recount() }
    function onModelReset() { card.recount() }
    function onCountChanged() { card.recount() }
  }

  title: "To-do"
  icon: ""
  iconColor: t.green

  headerExtra: [
    JText { t: card.t; text: card.doneCount + " of " + card.total + " done"; size: 10.5; color: card.t.textFaint }
  ]

  function focusInput() { input.forceActiveFocus() }

  Item {
    anchors.fill: parent

    // Progress line under the header.
    Rectangle {
      id: track
      width: parent.width
      height: card.t.px(4)
      radius: height / 2
      color: card.t.inkA(0.06)
      Rectangle {
        height: parent.height
        radius: height / 2
        width: parent.width * (card.total ? card.doneCount / card.total : 0) * card.ease(card.progress * 1.4)
        color: card.t.green
        Behavior on width { NumberAnimation { duration: Style.duration(260); easing.type: Easing.OutCubic } }
      }
    }

    ListView {
      id: list
      anchors.top: track.bottom
      anchors.topMargin: card.t.px(8)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: inputBox.top
      anchors.bottomMargin: card.t.px(8)
      clip: true
      model: card.todos
      boundsBehavior: Flickable.StopAtBounds
      spacing: card.t.px(2)

      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(200); easing.type: Easing.OutCubic }
        NumberAnimation { property: "x"; from: card.t.px(12); duration: Style.duration(220); easing.type: Easing.OutCubic }
      }

      delegate: Rectangle {
        id: row
        required property string title
        required property bool done
        required property string due
        required property int index
        readonly property real e: card.ease(card.progress * 1.6 - index * 0.08)
        width: ListView.view.width
        height: card.t.px(34)
        radius: card.t.radiusSmall
        color: rowHover.hovered ? card.t.inkA(0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        opacity: e

        Rectangle {
          id: box
          x: card.t.px(6)
          anchors.verticalCenter: parent.verticalCenter
          width: card.t.px(18); height: width
          radius: card.t.px(6)
          color: row.done ? card.t.green : "transparent"
          border.width: row.done ? 0 : 1.5
          border.color: rowHover.hovered ? card.t.green : card.t.inkA(0.28)
          Behavior on color { ColorAnimation { duration: Style.duration(160) } }
          JText {
            t: card.t
            anchors.centerIn: parent
            text: ""
            size: 9.5
            color: card.t.base
            scale: row.done ? 1 : 0.4
            opacity: row.done ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Style.duration(200); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
            Behavior on opacity { NumberAnimation { duration: Style.duration(140) } }
          }
        }

        JText {
          id: label
          t: card.t
          anchors.left: box.right
          anchors.leftMargin: card.t.px(10)
          anchors.right: due.left
          anchors.rightMargin: card.t.px(8)
          anchors.verticalCenter: parent.verticalCenter
          text: row.title
          size: 11.5
          color: row.done ? card.t.textFaint : card.t.text
          Behavior on color { ColorAnimation { duration: Style.duration(160) } }

          // Strike-through that draws across instead of snapping on.
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            width: row.done ? Math.min(parent.paintedWidth, parent.width) : 0
            color: card.t.textFaint
            Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
          }
        }

        JText {
          id: due
          t: card.t
          anchors.right: parent.right
          anchors.rightMargin: card.t.px(8)
          anchors.verticalCenter: parent.verticalCenter
          readonly property string st: card.dueState(row.due)
          text: card.dueLabel(row.due)
          size: 9.5
          color: row.done ? card.t.textFaint : st === "overdue" ? card.t.red : st === "today" ? card.t.yellow : card.t.textFaint
        }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onTapped: function(point, button) {
            if (button === Qt.RightButton) card.removed(row.index)
            else card.toggled(row.index)
          }
        }
      }
    }

    JText {
      visible: card.total === 0
      anchors.centerIn: list
      t: card.t
      text: "Nothing on your list.\nType below, or press T."
      horizontalAlignment: Text.AlignHCenter
      size: 11
      color: card.t.textFaint
    }

    Rectangle {
      id: inputBox
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: card.t.px(34)
      radius: card.t.radiusSmall
      color: card.t.neu ? card.t.glassInset : card.t.inkA(input.activeFocus ? 0.07 : 0.04)
      InsetShade { t: card.t }
      border.width: 1
      border.color: input.activeFocus ? card.t.borderStrong : card.t.border
      Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }

      JText { id: plus; t: card.t; x: card.t.px(12); anchors.verticalCenter: parent.verticalCenter; text: ""; size: 10; color: card.t.textFaint }

      TextInput {
        id: input
        anchors.left: plus.right
        anchors.leftMargin: card.t.px(10)
        anchors.right: parent.right
        anchors.rightMargin: card.t.px(10)
        anchors.verticalCenter: parent.verticalCenter
        color: card.t.text
        font.family: card.t.font
        font.pixelSize: card.t.px(11.5)
        selectionColor: card.t.alpha(card.t.accent, 0.4)
        clip: true
        maximumLength: 200
        Accessible.role: Accessible.EditableText
        Accessible.name: "Add a task"
        Keys.onReturnPressed: { if (text.trim().length) { card.added(text.trim()); text = "" } }
        Keys.onEnterPressed: { if (text.trim().length) { card.added(text.trim()); text = "" } }
        Keys.onEscapePressed: function(event) { if (text.length) { text = ""; event.accepted = true } else { event.accepted = false } }

        JText {
          t: card.t
          anchors.fill: parent
          visible: !input.text.length
          text: "Add a task…"
          size: 11.5
          color: card.t.textFaint
        }
      }
    }
  }
}
