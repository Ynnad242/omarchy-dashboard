import QtQuick
import qs.Commons

// Today: calendar events and tasks with times, in order, the one happening
// now marked with a pulsing dot.
GlassCard {
  id: card

  property var items: []
  property string calendarNote: ""
  property date now: new Date()

  title: "Today"
  icon: ""
  iconColor: t.magenta

  function minutesOf(hhmm) {
    var p = String(hhmm).split(":")
    return parseInt(p[0]) * 60 + parseInt(p[1] || 0)
  }
  readonly property int nowMin: now.getHours() * 60 + now.getMinutes()

  headerExtra: [
    JText {
      t: card.t
      text: Qt.formatDate(card.now, "dddd, d MMM")
      size: 10.5
      color: card.t.textFaint
    }
  ]

  JText {
    id: calNote
    t: card.t
    width: parent.width
    text: card.calendarNote
    size: 10.5
    color: card.t.textFaint
  }

  Flickable {
    anchors.fill: parent
    anchors.topMargin: calNote.height + card.t.px(10)
    contentHeight: list.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width
      spacing: card.t.px(9)

      Repeater {
        model: card.items
        Item {
          id: row
          required property var modelData
          required property int index
          readonly property int startMin: card.minutesOf(modelData.start)
          readonly property int endMin: modelData.end ? card.minutesOf(modelData.end) : startMin + 30
          readonly property bool live: card.nowMin >= startMin && card.nowMin < endMin
          readonly property bool past: card.nowMin >= endMin
          readonly property color tone: card.t.tone(modelData.tone)
          readonly property real e: card.ease(card.progress * 1.6 - index * 0.1)

          width: list.width
          height: card.t.px(56)
          opacity: e * (past ? 0.5 : 1)
          transform: Translate { y: (1 - row.e) * card.t.px(10) }

          JText {
            id: time
            t: card.t
            width: card.t.px(44)
            height: card.t.px(20)
            text: row.modelData.start || "\uf0ae"
            size: 10.5
            color: row.live ? card.t.text : card.t.textFaint
          }

          Rectangle {
            id: item
            anchors.left: time.right
            anchors.right: parent.right
            height: parent.height
            radius: card.t.radiusSmall
            color: row.live ? card.t.raised : card.t.glassInset
            border.width: 1
            border.color: row.live ? card.t.borderStrong : (rowHover.hovered ? card.t.borderStrong : card.t.border)
            Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }

            Rectangle {
              x: card.t.px(8)
              anchors.verticalCenter: parent.verticalCenter
              width: card.t.px(3)
              height: parent.height - card.t.px(18)
              radius: width / 2
              color: row.tone
            }

            JText {
              id: itemTitle
              t: card.t
              x: card.t.px(20)
              y: card.t.px(9)
              width: parent.width - x - card.t.px(70)
              text: row.modelData.title
              size: 12
              font.weight: Font.DemiBold
              font.strikeout: row.modelData.kind === "task" && row.modelData.done === true
            }
            JText {
              t: card.t
              x: card.t.px(20)
              anchors.top: itemTitle.bottom
              anchors.topMargin: card.t.px(3)
              width: parent.width - x - card.t.px(70)
              text: (row.modelData.kind === "task" ? "Task" : row.modelData.start + " – " + row.modelData.end) + (row.modelData.where ? "  ·  " + row.modelData.where : "")
              size: 10
              color: card.t.textFaint
            }

            // "Now" marker with a pulse.
            Item {
              visible: row.live
              anchors.right: parent.right
              anchors.rightMargin: card.t.px(12)
              anchors.verticalCenter: parent.verticalCenter
              width: nowText.implicitWidth + card.t.px(18)
              height: card.t.px(20)
              Rectangle {
                id: pulse
                width: card.t.px(8); height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: row.tone
                Rectangle {
                  anchors.centerIn: parent
                  width: parent.width; height: width; radius: width / 2
                  color: "transparent"
                  border.width: 2
                  border.color: row.tone
                  SequentialAnimation on scale {
                    running: false
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 2.6; duration: 1400; easing.type: Easing.OutCubic }
                  }
                  SequentialAnimation on opacity {
                    running: false
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.8; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                  }
                }
              }
              JText { id: nowText; t: card.t; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Now"; size: 10; color: row.tone; font.weight: Font.DemiBold }
            }

            // Avatars of who's in it.
            Row {
              visible: !row.live && (row.modelData.who || []).length > 0
              anchors.right: parent.right
              anchors.rightMargin: card.t.px(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: -card.t.px(6)
              Repeater {
                model: row.modelData.who || []
                Avatar { required property var modelData; required property int index; t: card.t; name: modelData; seed: index; size: 22 }
              }
            }

            HoverHandler { id: rowHover }
          }
        }
      }
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: card.shown
    onTriggered: card.now = new Date()
  }
  onShownChanged: if (shown) now = new Date()
}
