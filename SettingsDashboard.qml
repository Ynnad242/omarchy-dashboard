import QtQuick
import qs.Commons

// Settings > Dashboard: pick what's on Home. A hidden card also stops its
// background work (a hidden Govee card doesn't look for lamps, a hidden
// watchlist doesn't fetch prices). The preview shows the layout as it'll be.
Item {
  id: pane

  property var t
  property var app
  property bool shown: false
  readonly property real gap: t.px(18)

  readonly property var groups: [
    { title: "TOP ROW", items: [
      { key: "stat-screen", label: "Screen time today" },
      { key: "stat-tasks", label: "Done today" },
      { key: "stat-inbox", label: "Email" },
      { key: "stat-stocks", label: "Watchlist today" } ] },
    { title: "MIDDLE", items: [
      { key: "screentime", label: "Screen time chart", hint: "Day, week and month, with your top apps" },
      { key: "today", label: "Today", hint: "Tasks due today" } ] },
    { title: "BOTTOM ROW", items: [
      { key: "mail", label: "Important email", hint: "Needs an email account (Accounts)" },
      { key: "discord", label: "Discord", hint: "Pings, DMs and your voice call" },
      { key: "todo", label: "To-do" },
      { key: "home", label: "Home: Govee lamps and purifier", hint: "Hide it if you don't have Govee devices" },
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

    Item {
      id: sketch
      readonly property real g: pane.t.px(8)
      // Same proportions as Home.
      width: Math.min(parent.width, (parent.height - pane.t.px(30)) * 16 / 9)
      height: width * 9 / 16
      anchors.horizontalCenter: parent.horizontalCenter

      readonly property var stats: ["stat-screen", "stat-tasks", "stat-inbox", "stat-stocks"].filter(function(k) { return pane.on(k) })
      readonly property var mids: ["screentime", "today"].filter(function(k) { return pane.on(k) })
      readonly property var lows: ["mail", "discord", "todo", "home", "system"].filter(function(k) { return pane.on(k) })
      readonly property var w: ({ mail: 1.2, discord: 1, todo: 1, home: 1.05, system: 0.75, screentime: 2, today: 1 })
      readonly property var names: ({ "stat-screen": "Screen", "stat-tasks": "Done", "stat-inbox": "Email", "stat-stocks": "Stocks",
                                      screentime: "Screen time", today: "Today", mail: "Email", discord: "Discord", todo: "To-do", home: "Govee", system: "System" })
      readonly property real headH: height * 0.1
      readonly property real chatH: height * 0.07
      readonly property real kpiH: stats.length ? height * 0.12 : 0
      readonly property real rest: height - headH - chatH - kpiH - g * (2 + (stats.length && (mids.length || lows.length) ? 1 : 0) + (mids.length && lows.length ? 1 : 0))
      readonly property real midH: mids.length ? (lows.length ? rest / 2 : rest) : 0
      readonly property real lowH: lows.length ? rest - midH : 0
      readonly property real kpiY: headH + g
      readonly property real midY: kpiY + (stats.length ? kpiH + g : 0)
      readonly property real lowY: midY + (mids.length ? midH + g : 0)

      function rowBoxes(keys, y, h) {
        var total = 0, out = []
        for (var i = 0; i < keys.length; i++) total += (w[keys[i]] || 1)
        var unit = (width - g * Math.max(0, keys.length - 1)) / Math.max(0.01, total), x = 0
        for (var j = 0; j < keys.length; j++) { var bw = unit * (w[keys[j]] || 1); out.push({ key: keys[j], x: x, y: y, w: bw, h: h }); x += bw + g }
        return out
      }
      readonly property var boxes: rowBoxes(stats.map(function(k) { return k }), kpiY, kpiH)
        .concat(rowBoxes(mids, midY, midH)).concat(rowBoxes(lows, lowY, lowH))

      // Greeting and the chat bar, always there.
      Rectangle { width: parent.width * 0.3; height: sketch.headH * 0.35; y: sketch.headH * 0.15; radius: height / 2; color: pane.t.inkA(0.14) }
      Rectangle { width: parent.width; height: sketch.chatH; y: parent.height - height; radius: height / 2; color: pane.t.inkA(0.06); border.width: 1; border.color: pane.t.inkA(0.12) }

      Repeater {
        model: sketch.boxes
        Rectangle {
          required property var modelData
          x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
          radius: pane.t.radiusSmall
          color: pane.t.inkA(0.06)
          border.width: 1
          border.color: pane.t.inkA(0.14)
          Behavior on x { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
          Behavior on width { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
          Behavior on height { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
          JText { t: pane.t; anchors.centerIn: parent; width: parent.width - pane.t.px(6); horizontalAlignment: Text.AlignHCenter; text: sketch.names[parent.modelData.key] || ""; size: 9.5; color: pane.t.textFaint }
        }
      }
      JText {
        visible: sketch.boxes.length === 0
        t: pane.t
        anchors.centerIn: parent
        text: "Just the greeting, the clock and the chat bar."
        size: 11
        color: pane.t.textFaint
      }
    }
  }
}
