import QtQuick
import qs.Commons

// Important email only: sender, subject, a line of preview, and a pill on
// the ones that need a reply from you.
GlassCard {
  id: card

  property var mails: []
  property string emptyText: ""

  title: "Important email"
  icon: ""
  iconColor: t.yellow
  action: "Gmail"

  headerExtra: [
    Rectangle {
      readonly property int n: { var c = 0; for (var i = 0; i < card.mails.length; i++) if (card.mails[i].needsReply) c++; return c }
      visible: n > 0
      height: card.t.px(18)
      width: replyCount.implicitWidth + card.t.px(14)
      radius: height / 2
      color: "transparent"
      JText { id: replyCount; t: card.t; anchors.centerIn: parent; text: parent.n + " need a reply"; size: 9.5; color: card.t.yellow }
    }
  ]

  JText {
    visible: card.mails.length === 0
    anchors.centerIn: parent
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    t: card.t
    text: card.emptyText
    size: 11
    color: card.t.textFaint
  }

  Flickable {
    anchors.fill: parent
    contentHeight: col.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: col
      width: parent.width
      spacing: card.t.px(4)

      Repeater {
        model: card.mails
        Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property real e: card.ease(card.progress * 1.6 - index * 0.1)
          width: col.width
          height: card.t.px(60)
          radius: card.t.radiusSmall
          color: hover.hovered ? card.t.inkA(0.05) : "transparent"
          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
          opacity: e
          transform: Translate { x: (1 - row.e) * card.t.px(12) }

          Avatar {
            id: av
            t: card.t
            name: row.modelData.from
            size: 32
            x: card.t.px(6)
            anchors.verticalCenter: parent.verticalCenter
          }

          JText {
            id: from
            t: card.t
            anchors.left: av.right
            anchors.leftMargin: card.t.px(10)
            anchors.right: when.left
            anchors.rightMargin: card.t.px(8)
            y: card.t.px(8)
            text: row.modelData.from
            size: 11.5
            font.weight: row.modelData.unread ? Font.Bold : Font.DemiBold
          }
          JText {
            id: when
            t: card.t
            anchors.right: parent.right
            anchors.rightMargin: card.t.px(8)
            anchors.verticalCenter: from.verticalCenter
            text: row.modelData.time
            size: 9.5
            color: card.t.textFaint
          }
          JText {
            id: subject
            t: card.t
            anchors.left: from.left
            anchors.right: replyPill.visible ? replyPill.left : parent.right
            anchors.rightMargin: card.t.px(8)
            anchors.top: from.bottom
            anchors.topMargin: card.t.px(2)
            text: row.modelData.subject
            size: 11
            color: card.t.text
          }
          JText {
            t: card.t
            anchors.left: from.left
            anchors.right: parent.right
            anchors.rightMargin: card.t.px(8)
            anchors.top: subject.bottom
            anchors.topMargin: card.t.px(1)
            text: row.modelData.snippet
            size: 10
            color: card.t.textFaint
          }
          Rectangle {
            id: replyPill
            visible: row.modelData.needsReply === true
            anchors.right: parent.right
            anchors.rightMargin: card.t.px(8)
            anchors.verticalCenter: subject.verticalCenter
            height: card.t.px(16)
            width: replyText.implicitWidth + card.t.px(12)
            radius: height / 2
            color: "transparent"
            border.width: 0
            JText { id: replyText; t: card.t; anchors.centerIn: parent; text: " Reply"; size: 9; color: card.t.yellow }
          }

          HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        }
      }
    }
  }
}
