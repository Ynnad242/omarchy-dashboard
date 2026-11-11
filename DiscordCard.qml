import QtQuick
import qs.Commons

// Discord: who's in your voice channel (rings pulse while they talk) and
// the mentions and DMs waiting for you.
GlassCard {
  id: card

  property var discord: ({})
  readonly property var voice: discord.voice || null
  readonly property var mentions: discord.mentions || []
  readonly property color blurple: t.textDim

  title: "Discord"
  icon: String.fromCodePoint(0xF066F)
  iconColor: blurple

  headerExtra: [
    Rectangle {
      visible: card.mentions.length > 0
      height: card.t.px(18)
      width: mcount.implicitWidth + card.t.px(14)
      radius: height / 2
      color: "transparent"
      JText { id: mcount; t: card.t; anchors.centerIn: parent; text: card.mentions.length + (card.mentions.length === 1 ? " ping" : " pings") + " today"; size: 9.5; color: card.t.red }
    }
  ]

  Item {
    anchors.fill: parent

    // Voice channel strip
    Rectangle {
      id: voiceBox
      visible: !!card.voice
      width: parent.width
      height: card.voice ? card.t.px(54) : 0
      radius: card.t.radiusSmall
      color: card.t.glassInset
      InsetShade { t: card.t }
      border.width: 1
      border.color: card.t.border
      opacity: card.ease(card.progress * 1.8)

      JText {
        id: vlabel
        t: card.t
        x: card.t.px(12)
        y: card.t.px(8)
        width: faces.x - x - card.t.px(10)
        text: card.voice ? card.voice.channel : ""
        size: 11
        font.weight: Font.DemiBold
      }
      JText {
        t: card.t
        x: card.t.px(12)
        anchors.top: vlabel.bottom
        anchors.topMargin: card.t.px(2)
        width: faces.x - x - card.t.px(10)
        text: card.voice ? (card.voice.server ? card.voice.server + "  \u00b7  " : "") + card.voice.members.length + " in voice" : ""
        size: 9.5
        color: card.t.textFaint
      }
      // Faces get smaller as the call grows (28 / 24 / 20px), never overlap,
      // and stop at 7: anyone past that is a "+N" at the end. Keyed by count
      // so a speaking update doesn't reload every avatar.
      Row {
        id: faces
        anchors.right: parent.right
        anchors.rightMargin: card.t.px(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: card.t.px(4)
        readonly property var members: card.voice ? card.voice.members : []
        readonly property int n: members.length
        readonly property real face: card.t.px(n <= 3 ? 28 : n <= 5 ? 24 : 20)
        // Room for at most half the strip, and never more than 7 faces.
        readonly property int room: Math.max(1, Math.floor((voiceBox.width * 0.68 + spacing) / (face + spacing)))
        // Up to 7 faces; if anyone's left over, the "+N" takes one slot of room.
        readonly property int limit: Math.max(1, Math.min(7, n > Math.min(7, room) ? room - 1 : room))
        readonly property int shown: Math.min(n, limit)
        Repeater {
          model: faces.shown
          Item {
            id: member
            required property int index
            readonly property var m: faces.members[index] || ({})
            width: faces.face; height: width
            Avatar {
              t: card.t
              anchors.centerIn: parent
              name: member.m.name || ""
              image: member.m.avatar || ""
              size: faces.face / card.t.u - 2
            }
            // Talking: a thin green ring.
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: "transparent"
              border.width: card.t.px(2)
              border.color: card.t.green
              visible: member.m.speaking === true
            }
          }
        }
        Rectangle {
          visible: faces.n > faces.shown
          height: faces.face
          width: Math.max(faces.face, moreText.implicitWidth + card.t.px(10))
          radius: height / 2
          color: card.t.raised
          JText { id: moreText; t: card.t; anchors.centerIn: parent; text: "+" + (faces.n - faces.shown); size: 9.5; color: card.t.textDim }
        }
      }
    }

    JText {
      visible: card.mentions.length === 0
      anchors.top: voiceBox.bottom
      anchors.topMargin: card.t.px(18)
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      elide: Text.ElideNone
      t: card.t
      text: "No pings in the last day.\nNeeds desktop notifications on in Discord."
      size: 10.5
      color: card.t.textFaint
    }

    Flickable {
      anchors.top: voiceBox.bottom
      anchors.topMargin: card.t.px(10)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      contentHeight: mcol.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: mcol
        width: parent.width
        spacing: card.t.px(2)
        Repeater {
          model: card.mentions
          Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property real e: card.ease(card.progress * 1.6 - 0.15 - index * 0.1)
            width: mcol.width
            height: card.t.px(46)
            radius: card.t.radiusSmall
            color: hov.hovered ? card.t.inkA(0.05) : "transparent"
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }
            opacity: e
            transform: Translate { x: (1 - row.e) * card.t.px(12) }

            Avatar { id: av; t: card.t; name: row.modelData.from; size: 26; x: card.t.px(4); anchors.verticalCenter: parent.verticalCenter }
            JText {
              id: who
              t: card.t
              anchors.left: av.right
              anchors.leftMargin: card.t.px(9)
              anchors.right: tm.left
              y: card.t.px(6)
              text: row.modelData.from + "  " + (row.modelData.dm ? "· DM" : "in " + row.modelData.where)
              size: 10.5
              font.weight: Font.DemiBold
            }
            JText { id: tm; t: card.t; anchors.right: parent.right; anchors.rightMargin: card.t.px(6); anchors.verticalCenter: who.verticalCenter; text: row.modelData.time; size: 9.5; color: card.t.textFaint }
            JText {
              t: card.t
              anchors.left: who.left
              anchors.right: parent.right
              anchors.rightMargin: card.t.px(6)
              anchors.top: who.bottom
              anchors.topMargin: card.t.px(2)
              text: row.modelData.text
              size: 10
              color: card.t.textDim
            }
            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
          }
        }
      }
    }
  }
}
