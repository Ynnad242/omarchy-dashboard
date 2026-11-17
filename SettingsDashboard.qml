import QtQuick
import qs.Commons
import "Layout.js" as Layout

// Settings > Dashboard: pick what's on Home. A hidden card also stops its
// background work (a hidden Govee card doesn't look for lamps, a hidden
// watchlist doesn't fetch prices). The preview shows the layout as it'll be;
// drag a card in it to move it, and it snaps into place in a row.
Item {
  id: pane

  property var t
  property var app
  property bool shown: false
  readonly property real gap: t.px(18)

  readonly property var groups: [
    { title: "STATS", items: [
      { key: "stat-screen", label: "Screen time today" },
      { key: "stat-tasks", label: "Done today" },
      { key: "stat-inbox", label: "Email" },
      { key: "stat-stocks", label: "Watchlist today" } ] },
    { title: "CARDS", items: [
      { key: "screentime", label: "Screen time chart", hint: "Day, week and month, with your top apps" },
      { key: "today", label: "Today", hint: "Tasks due today" },
      { key: "mail", label: "Important email", hint: "Needs an email account (Accounts)" },
      { key: "discord", label: "Discord", hint: "Pings, DMs and your voice call" },
      { key: "todo", label: "To-do" },
      { key: "home", label: "Home: Govee lamps and purifier", hint: "Hide it if you don't have Govee devices" },
      { key: "music", label: "Music", hint: "What's playing in Spotify, with play, pause, back and skip" },
      { key: "system", label: "System", hint: "CPU, memory and disk" } ] },
    { title: "PAGES", items: [
      { key: "stocksPage", label: "Stocks page", hint: "Also hides it from the side bar" } ] }
  ]
  function on(key) { return pane.app ? pane.app.shows(key) : true }

  GlassCard {
    id: listCard
    t: pane.t
    shown: pane.shown
    order: 1
    hoverable: false
    width: Math.round((pane.width - pane.gap) * 0.42)
    height: pane.height
    title: "On your dashboard"
    action: pane.app && pane.app.hiddenCards.length ? "Show all" : ""
    onActionClicked: if (pane.app) pane.app.setSetting("hidden", [])

    Flickable {
      anchors.fill: parent
      contentHeight: col.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: col
        width: parent.width
        spacing: pane.t.px(2)
        Repeater {
          model: pane.groups
          Column {
            id: grp
            required property var modelData
            required property int index
            width: col.width
            spacing: pane.t.px(2)
            Item { width: 1; height: grp.index ? pane.t.px(10) : 0 }
            JText { t: pane.t; text: grp.modelData.title; size: 10.5; font.weight: Font.DemiBold; font.letterSpacing: 0.5; color: pane.t.textFaint }
            Repeater {
              model: grp.modelData.items
              SRow {
                id: item
                required property var modelData
                t: pane.t
                width: grp.width
                label: modelData.label
                hint: modelData.hint || ""
                JToggle {
                  t: pane.t
                  on: pane.on(item.modelData.key)
                  Accessible.name: "Show " + item.modelData.label
                  onFlipped: function(v) { if (pane.app && !pane.app.demo) pane.app.setShown(item.modelData.key, v) }
                }
              }
            }
          }
        }
      }
    }
  }

  // A small live sketch of Home with the cards that are on.
  GlassCard {
    id: preview
    t: pane.t
    shown: pane.shown
    order: 2
    hoverable: false
    x: listCard.width + pane.gap
    width: pane.width - x
    height: pane.height
    title: "Preview"
    action: pane.app && !Layout.same(pane.app.layoutRows, Layout.defaults) ? "Reset layout" : ""
    onActionClicked: if (pane.app) pane.app.setLayout(Layout.defaults.map(function(r) { return r.slice() }))

    Item {
      id: sketch
      readonly property real g: pane.t.px(8)
      // Same proportions as Home, leaving room for the hint underneath.
      width: Math.min(parent.width, (parent.height - pane.t.px(30)) * 16 / 9)
      height: width * 9 / 16
      anchors.horizontalCenter: parent.horizontalCenter

      readonly property var names: ({ "stat-screen": "Screen", "stat-tasks": "Done", "stat-inbox": "Email", "stat-stocks": "Stocks",
                                      screentime: "Screen time", today: "Today", mail: "Email", discord: "Discord", todo: "To-do", home: "Govee", music: "Music", system: "System" })
      readonly property real headH: height * 0.1
      readonly property real chatH: height * 0.07
      readonly property real shortH: height * 0.12
      readonly property var rows: pane.app ? pane.app.layoutRows : Layout.defaults

      // While dragging: the layout as it would be if dropped here, the card's
      // spot under the pointer, and the layout without it (what drops aim at).
      property string dragKey: ""
      property var dragRows: null
      property var baseGeo: null
      property real dragX: 0
      property real dragY: 0
      function showsFn(k) { return pane.on(k) }
      function geoOf(r) {
        return Layout.geometry(Layout.visible(r, showsFn), width, headH + g, height - headH - chatH - g * 2, g, shortH)
      }
      readonly property var geo: geoOf(dragRows || rows)
      function begin(k, x, y) {
        dragX = x; dragY = y
        baseGeo = geoOf(Layout.without(rows, k))
        dragRows = rows
        dragKey = k
      }
      function track(px, py, x, y) {
        dragX = x; dragY = y
        var to = Layout.target(baseGeo, px, py)
        if (to) {
          var next = Layout.move(rows, dragKey, to, showsFn)
          if (!Layout.same(next, dragRows)) dragRows = next
        }
      }
      function end() {
        if (dragKey && dragRows && !Layout.same(dragRows, rows) && pane.app) pane.app.setLayout(dragRows)
        dragKey = ""
        dragRows = null
      }

      // Greeting and the chat bar, always there.
      Rectangle { width: parent.width * 0.3; height: sketch.headH * 0.35; y: sketch.headH * 0.15; radius: height / 2; color: pane.t.inkA(0.14) }
      Rectangle { width: parent.width; height: sketch.chatH; y: parent.height - height; radius: height / 2; color: pane.t.inkA(0.06); border.width: 1; border.color: pane.t.inkA(0.12) }

      Repeater {
        model: Layout.all.length
        Rectangle {
          id: tile
          required property int index
          readonly property string key: Layout.all[index]
          readonly property var box: sketch.geo[key] || null
          readonly property bool dragging: sketch.dragKey === key
          visible: !!box
          x: dragging ? sketch.dragX : box ? box.x : 0
          y: dragging ? sketch.dragY : box ? box.y : 0
          width: box ? box.w : 0
          height: box ? box.h : 0
          z: dragging ? 10 : 1
          radius: pane.t.radiusSmall
          color: dragging ? pane.t.inkA(0.16) : grab.containsMouse ? pane.t.inkA(0.09) : pane.t.inkA(0.06)
          border.width: dragging ? 1.5 : 1
          border.color: dragging ? pane.t.accent : pane.t.inkA(0.14)
          scale: dragging ? 1.04 : 1
          Behavior on x { enabled: !tile.dragging; NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutQuart } }
          Behavior on y { enabled: !tile.dragging; NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutQuart } }
          Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutQuart } }
          Behavior on height { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutQuart } }
          Behavior on scale { NumberAnimation { duration: Style.duration(140) } }
          JText { t: pane.t; anchors.centerIn: parent; width: parent.width - pane.t.px(6); horizontalAlignment: Text.AlignHCenter; text: sketch.names[tile.key] || ""; size: 9.5; color: tile.dragging ? pane.t.text : pane.t.textFaint; elide: Text.ElideRight }
          MouseArea {
            id: grab
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real ox: 0
            property real oy: 0
            onPressed: function(m) { ox = m.x; oy = m.y; sketch.begin(tile.key, tile.x, tile.y) }
            onPositionChanged: function(m) {
              if (!pressed) return
              var p = mapToItem(sketch, m.x, m.y)
              sketch.track(p.x, p.y, p.x - ox, p.y - oy)
            }
            onReleased: sketch.end()
            onCanceled: sketch.end()
          }
        }
      }
      JText {
        visible: !sketch.geo.rows || sketch.geo.rows.length === 0
        t: pane.t
        anchors.centerIn: parent
        text: "Just the greeting, the clock and the chat bar."
        size: 11
        color: pane.t.textFaint
      }
    }
    JText {
      t: pane.t
      anchors.top: sketch.bottom
      anchors.topMargin: pane.t.px(8)
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Drag a card to move it. It snaps into a row, or onto a new row above or below."
      size: 10
      color: pane.t.textFaint
    }
  }
}
