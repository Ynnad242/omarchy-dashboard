import QtQuick
import qs.Commons

// Home: each Govee lamp (over the LAN) on its own row with a toggle and a
// brightness slider, shared swatches and scenes aimed by the picker in the
// header, and the Govee air purifier (over Govee's cloud). `home` is the
// latest state line from govee.py and `send` hands a command back to it.
GlassCard {
  id: card

  property var home: ({ lights: [], purifiers: [], cloud: "off", error: "" })
  property var send: function(cmd) {}

  readonly property var lights: home.lights || []
  readonly property bool lampFound: lights.length > 0
  // After a while without an answer, say so instead of "looking" forever.
  property bool searchedLong: false
  Timer { interval: 10000; running: card.shown && !card.lampFound && !card.searchedLong; onTriggered: card.searchedLong = true }
  readonly property bool anyOn: { for (var i = 0; i < lights.length; i++) if (lights[i].on) return true; return false }
  readonly property var purifier: (home.purifiers || []).length ? home.purifiers[0] : null

  // Which lamp the swatches and scenes act on: "" for every lamp, else an IP.
  property string target: ""
  readonly property var targetLight: {
    for (var i = 0; i < lights.length; i++) if (lights[i].ip === target) return lights[i]
    return null
  }
  // A lamp that drops off the network can't stay the target.
  onLightsChanged: if (target !== "" && !targetLight) target = ""

  function shortName(l, i) {
    var n = String(l.name || "").trim()
    return n.length ? n.split(/\s+/)[0] : "Bulb " + (i + 1)
  }
  function rgbOf(c) { return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)] }
  function colorOf(l) {
    var c = l && l.color ? l.color : [255, 166, 87]
    return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1)
  }
  function colorName(l) {
    if (!l) return ""
    if (l.white) return l.kelvin <= 3200 ? "warm" : l.kelvin <= 4800 ? "neutral" : "cool"
    return "color"
  }
  // The glow color for the card icon: the target lamp, else the first lit one.
  readonly property color glowColor: {
    if (targetLight) return colorOf(targetLight)
    for (var i = 0; i < lights.length; i++) if (lights[i].on) return colorOf(lights[i])
    return t.yellow
  }

  readonly property var whites: [2700, 4000, 6500]
  readonly property var colors: [t.accent, t.red, "#ff7a1a", t.magenta, t.cyan, t.green]
  readonly property var scenes: [
    { label: "Focus", cmd: { on: true, kelvin: 5500, brightness: 100 } },
    { label: "Chill", cmd: { on: true, kelvin: 2700, brightness: 40 } },
    { label: "Movie", cmd: { on: true, color: [255, 110, 30], brightness: 12 } },
    { label: "Theme", cmd: null }
  ]
  // Send to one lamp (ip) or, without one, to the current target.
  function lamp(c, ip) {
    c.cmd = "lights"
    var to = ip !== undefined ? ip : card.target
    if (to) c.ip = to
    card.send(c)
  }

  title: "Home"
  icon: ""
  iconColor: anyOn ? glowColor : t.yellow

  headerExtra: [
    Segmented {
      visible: card.lights.length > 1
      t: card.t
      options: {
        var o = [{ key: "", label: "Both" }]
        if (card.lights.length > 2) o[0].label = "All"
        for (var i = 0; i < card.lights.length; i++) o.push({ key: card.lights[i].ip, label: card.shortName(card.lights[i], i) })
        return o
      }
      current: card.target
      onPicked: function(key) { card.target = key }
    }
  ]

  // ---- small parts ---------------------------------------------------------

  component Toggle: Item {
    id: tg
    property bool on: false
    property color tint: card.t.accent
    property bool enabled2: true
    signal flipped()
    width: card.t.px(38); height: card.t.px(22)
    opacity: enabled2 ? 1 : 0.4
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: tg.on ? card.t.alpha(tg.tint, 0.85) : card.t.inkA(0.10)
      border.width: 1
      border.color: tg.on ? card.t.alpha("white", 0.25) : card.t.inkA(0.12)
      Behavior on color { ColorAnimation { duration: Style.duration(180) } }
    }
    Rectangle {
      width: parent.height - card.t.px(6); height: width; radius: width / 2
      y: card.t.px(3)
      x: tg.on ? parent.width - width - card.t.px(3) : card.t.px(3)
      color: "white"
      Behavior on x { NumberAnimation { duration: Style.duration(200); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
    }
    MouseArea { anchors.fill: parent; enabled: tg.enabled2; cursorShape: Qt.PointingHandCursor; onClicked: tg.flipped() }
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property bool active: false
    property color tint: card.t.accent
    signal tapped()
    height: card.t.px(24)
    width: chipText.implicitWidth + card.t.px(18)
    radius: height / 2
    color: active ? card.t.alpha(tint, 0.22) : (chipHover.hovered ? card.t.inkA(0.08) : card.t.inkA(0.04))
    border.width: 1
    border.color: active ? card.t.alpha(tint, 0.6) : card.t.inkA(0.08)
    Behavior on color { ColorAnimation { duration: Style.duration(140) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }
    JText { id: chipText; t: card.t; anchors.centerIn: parent; text: chip.label; size: 10; color: chip.active ? card.t.text : card.t.textDim }
    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.tapped() }
  }

  // One lamp: glow, name and level, its own slider, its own toggle.
  component LampRow: Rectangle {
    id: row
    property var light: ({})
    property int slot: 0
    readonly property bool on: light.on === true
    readonly property int level: light.brightness || 0
    readonly property color tint: card.colorOf(light)
    readonly property bool targeted: card.target === light.ip

    height: card.t.px(40)
    radius: card.t.radiusSmall
    color: targeted ? card.t.alpha(tint, 0.10) : (rowHover.hovered ? card.t.inkA(0.035) : "transparent")
    border.width: 1
    border.color: targeted ? card.t.alpha(tint, 0.45) : "transparent"
    Behavior on color { ColorAnimation { duration: Style.duration(160) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(160) } }
    HoverHandler { id: rowHover }

    Item {
      id: orb
      x: card.t.px(6)
      width: card.t.px(28); height: width
      anchors.verticalCenter: parent.verticalCenter
      Rectangle {
        id: orbCore
        anchors.fill: parent
        radius: width / 2
        color: row.on ? card.t.alpha(row.tint, 0.28) : card.t.inkA(0.05)
        border.width: 1
        border.color: row.on ? card.t.alpha(row.tint, 0.7) : card.t.inkA(0.12)
        Behavior on color { ColorAnimation { duration: Style.duration(260) } }
        JText { t: card.t; anchors.centerIn: parent; text: ""; size: 12; color: row.on ? Qt.lighter(row.tint, 1.2) : card.t.textFaint }
      }
    }

    // Name and level; clicking here aims the swatches and scenes at this lamp.
    Item {
      id: label
      anchors.left: orb.right
      anchors.leftMargin: card.t.px(9)
      anchors.verticalCenter: parent.verticalCenter
      width: card.t.px(76)
      height: parent.height
      JText {
        id: nameText
        t: card.t
        width: parent.width
        y: card.t.px(5)
        text: row.light.name || ("Bulb " + (row.slot + 1))
        size: 11
        font.weight: Font.DemiBold
      }
      JText {
        t: card.t
        width: parent.width
        anchors.top: nameText.bottom
        text: row.on || slider.dragging ? Math.round(slider.shown) + "% · " + card.colorName(row.light) : "off"
        size: 9
        color: card.t.textFaint
      }
      TapHandler { onTapped: card.target = row.targeted ? "" : row.light.ip }
      HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // Brightness. The knob follows the pointer exactly (grab it anywhere on
    // the track, or by the knob without it jumping), eases a hair behind so
    // it glides, and the scroll wheel nudges 5% a notch. While dragging it
    // sends to the bulb every 80ms; after letting go it holds the new value
    // until the bulb confirms it, so a late status reply can't snap it back.
    Item {
      id: slider
      anchors.left: label.right
      anchors.leftMargin: card.t.px(6)
      anchors.right: toggle.left
      anchors.rightMargin: card.t.px(12)
      anchors.verticalCenter: parent.verticalCenter
      height: card.t.px(28)
      opacity: row.on ? 1 : 0.45
      Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }

      readonly property real knob: card.t.px(18)
      readonly property real travel: Math.max(1, width - knob)
      readonly property bool dragging: drag.pressed
      readonly property bool hot: dragging || drag.containsMouse
      readonly property real ent: card.ease(card.progress * 1.5 - 0.15)
      property real dragValue: 0
      property real grabOffset: 0
      property real target: -1
      readonly property real wanted: dragging ? dragValue : (target >= 0 ? target : row.level)
      property real shown: wanted
      Behavior on shown {
        enabled: card.progress >= 1 && !slider.dragging
        NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
      }

      function valueAt(x) { return Math.max(1, Math.min(100, Math.round(1 + 99 * (x - knob / 2) / travel))) }
      function knobX(v) { return travel * (v - 1) / 99 }
      function send(v) { throttle.pending = Math.round(v); if (!throttle.running) throttle.start() }

      // The bulb caught up: drop the held value.
      Connections {
        target: row
        function onLevelChanged() { if (slider.target >= 0 && !slider.dragging && Math.abs(row.level - slider.target) <= 1) slider.target = -1 }
      }
      Timer { id: confirmTimeout; interval: 4000; onTriggered: slider.target = -1 }

      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: parent.width
        height: slider.hot ? card.t.px(8) : card.t.px(6)
        radius: height / 2
        color: card.t.inkA(slider.hot ? 0.13 : 0.10)
        Behavior on height { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Style.duration(140) } }

        Rectangle {
          height: parent.height
          radius: height / 2
          width: Math.max(height, (slider.knobX(slider.shown) + slider.knob / 2) * slider.ent)
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: card.t.alpha(row.tint, 0.30) }
            GradientStop { position: 1; color: row.tint }
          }
        }
      }

      // Soft glow under the knob in the lamp's color.
      Rectangle {
        width: slider.knob * 2.2; height: width; radius: width / 2
        x: knobDot.x + slider.knob / 2 - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: card.t.alpha(row.tint, 0.22)
        opacity: 0
        scale: slider.dragging ? 1 : 0.8
        Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
        Behavior on scale { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
      }
      Rectangle {
        id: knobDot
        width: slider.knob; height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: slider.knobX(slider.shown) * slider.ent
        color: "white"
        border.width: slider.dragging ? card.t.px(3) : 0
        border.color: row.tint
        scale: slider.dragging ? 1.12 : (drag.containsMouse ? 1.05 : 1)
        Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: Style.duration(120) } }
      }

      Timer {
        id: throttle
        interval: 80
        property int pending: -1
        onTriggered: if (pending > 0) { card.lamp({ on: true, brightness: pending }, row.light.ip); pending = -1 }
      }

      MouseArea {
        id: drag
        anchors.fill: parent
        enabled: card.lampFound
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: function(m) {
          var center = slider.knobX(slider.wanted) + slider.knob / 2
          // Grabbing the knob keeps it under the pointer; clicking the track jumps there.
          slider.grabOffset = Math.abs(m.x - center) <= slider.knob * 0.75 ? m.x - center : 0
          slider.dragValue = slider.valueAt(m.x - slider.grabOffset)
          confirmTimeout.stop()
          slider.send(slider.dragValue)
        }
        onPositionChanged: function(m) {
          if (!pressed) return
          var v = slider.valueAt(m.x - slider.grabOffset)
          if (v !== slider.dragValue) { slider.dragValue = v; slider.send(v) }
        }
        onReleased: {
          slider.target = slider.dragValue
          throttle.stop()
          card.lamp({ on: true, brightness: Math.round(slider.dragValue) }, row.light.ip)
          confirmTimeout.restart()
        }
        onWheel: function(w) {
          var base = slider.target >= 0 ? slider.target : row.level
          var v = Math.max(1, Math.min(100, Math.round(base + (w.angleDelta.y > 0 ? 5 : -5))))
          slider.target = v
          slider.send(v)
          confirmTimeout.restart()
          w.accepted = true
        }
      }
    }

    Toggle {
      id: toggle
      anchors.right: parent.right
      anchors.rightMargin: card.t.px(6)
      anchors.verticalCenter: parent.verticalCenter
      on: row.on
      tint: card.t.accent
      onFlipped: card.lamp({ on: !row.on }, row.light.ip)
    }
  }

  // ---- layout --------------------------------------------------------------

  Item {
    anchors.fill: parent

    Column {
      id: lampList
      width: parent.width
      spacing: card.t.px(4)

      JText {
        visible: !card.lampFound
        t: card.t
        width: parent.width
        height: card.t.px(40)
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        text: card.searchedLong ? "No Govee lamps found on your network. Turn on LAN Control for them in the Govee Home app."
                                : "Looking for your lamps… (are they switched on?)"
        size: 10
        color: card.t.textFaint
      }

      // A plain count, not the array: govee.py sends a fresh array on every
      // update (many times a second while dragging), and an array model
      // would destroy and rebuild the rows each time, killing the drag.
      Repeater {
        model: card.lights.length
        LampRow {
          required property int index
          light: card.lights[index] || ({})
          slot: index
          width: lampList.width
          opacity: card.ease(card.progress * 1.6 - index * 0.08)
        }
      }
    }

    // Whites and colors, for the lamp picked in the header (or both).
    Row {
      id: swatches
      visible: card.lampFound
      height: visible ? implicitHeight : 0
      anchors.top: lampList.bottom
      anchors.topMargin: card.t.px(10)
      x: card.t.px(6)
      spacing: card.t.px(7)
      opacity: card.ease(card.progress * 1.6 - 0.2)
      readonly property real d: card.t.px(20)
      readonly property var ref: card.targetLight || (card.lights.length ? card.lights[0] : null)

      Repeater {
        model: card.whites
        Rectangle {
          required property int modelData
          readonly property bool active: !!swatches.ref && swatches.ref.on === true && swatches.ref.white === true && Math.abs((swatches.ref.kelvin || 0) - modelData) < 400
          width: swatches.d; height: width; radius: width / 2
          color: modelData <= 3000 ? "#ffc58f" : modelData <= 4500 ? "#ffe4ce" : "#e8f0ff"
          border.width: active ? 2 : 1
          border.color: active ? card.t.text : card.t.inkA(0.2)
          scale: sh.hovered ? 1.15 : 1
          Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
          HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: card.lamp({ on: true, kelvin: parent.modelData }) }
        }
      }
      Rectangle { width: 1; height: swatches.d; color: card.t.inkA(0.1) }
      Repeater {
        model: card.colors
        Rectangle {
          required property color modelData
          width: swatches.d; height: width; radius: width / 2
          color: modelData
          border.width: 1
          border.color: card.t.inkA(0.25)
          scale: ch.hovered ? 1.15 : 1
          Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
          HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: card.lamp({ on: true, color: card.rgbOf(parent.modelData) }) }
        }
      }
    }

    Row {
      id: sceneRow
      visible: card.lampFound
      height: visible ? implicitHeight : 0
      anchors.top: swatches.bottom
      anchors.topMargin: visible ? card.t.px(9) : 0
      x: card.t.px(6)
      spacing: card.t.px(6)
      opacity: card.ease(card.progress * 1.6 - 0.25)
      Repeater {
        model: card.scenes
        Chip {
          required property var modelData
          label: modelData.label
          tint: card.t.accent
          onTapped: card.lamp(modelData.cmd ? JSON.parse(JSON.stringify(modelData.cmd)) : { on: true, color: card.rgbOf(card.t.accent), brightness: 80 })
        }
      }
    }

    Rectangle {
      id: divider
      anchors.top: sceneRow.bottom
      anchors.topMargin: card.t.px(11)
      width: parent.width
      height: 1
      color: card.t.inkA(0.07)
    }

    // Air purifier
    Item {
      id: purifierBox
      anchors.top: divider.bottom
      anchors.topMargin: card.t.px(12)
      anchors.bottom: parent.bottom
      width: parent.width
      opacity: card.ease(card.progress * 1.6 - 0.3)

      // No key yet, or the cloud is unhappy.
      JText {
        visible: !card.purifier
        width: parent.width
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        maximumLineCount: 3
        text: card.home.cloud === "disabled" ? "Air purifier is switched off in Settings"
          : card.home.cloud === "nokey" ? "Air purifier: add your Govee API key to ~/.config/jarvis/govee.json"
          : card.home.cloud === "error" ? "Air purifier: " + (card.home.error || "Govee isn't answering")
          : card.home.cloud === "ok" ? "No air purifier found on your Govee account"
          : "Connecting to the air purifier…"
        size: 10
        color: card.home.cloud === "error" ? card.t.red : card.t.textFaint
      }

      Item {
        id: purRow
        visible: !!card.purifier
        width: parent.width
        height: card.t.px(38)

        readonly property bool on: card.purifier ? card.purifier.on : false
        readonly property var mode: {
          if (!card.purifier) return null
          var ms = card.purifier.modes || []
          for (var i = 0; i < ms.length; i++) if (ms[i].id === card.purifier.mode) return ms[i]
          return null
        }
        readonly property var readings: card.purifier ? card.purifier.readings || {} : {}
        readonly property var air: readings.airQuality !== undefined ? readings.airQuality : (readings.pm25Value !== undefined ? readings.pm25Value : readings.sensorPm25)

        Rectangle {
          id: fan
          width: card.t.px(34); height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: purRow.on ? card.t.alpha(card.t.cyan, 0.22) : card.t.inkA(0.05)
          border.width: 1
          border.color: purRow.on ? card.t.alpha(card.t.cyan, 0.6) : card.t.inkA(0.12)
          Behavior on color { ColorAnimation { duration: Style.duration(200) } }
          JText {
            id: fanGlyph
            t: card.t
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF0210)
            size: 15
            color: purRow.on ? card.t.cyan : card.t.textFaint
            RotationAnimation on rotation {
              id: fanSpin
              running: purRow.on && card.shown
              loops: Animation.Infinite
              from: 0; to: 360
              duration: purRow.mode && /high|turbo/i.test(purRow.mode.label) ? 700 : purRow.mode && /sleep|low/i.test(purRow.mode.label) ? 2600 : 1400
            }
          }
        }
        JText {
          id: purName
          t: card.t
          anchors.left: fan.right
          anchors.leftMargin: card.t.px(10)
          anchors.right: airBox.left
          anchors.rightMargin: card.t.px(8)
          y: card.t.px(2)
          text: card.purifier ? card.purifier.name : ""
          size: 12
          font.weight: Font.DemiBold
        }
        JText {
          t: card.t
          anchors.left: purName.left
          anchors.right: airBox.left
          anchors.top: purName.bottom
          anchors.topMargin: card.t.px(1)
          text: !card.purifier ? "" : !card.purifier.online ? "Offline"
            : (purRow.on ? (purRow.mode ? purRow.mode.label : "On") : "Off")
              + (purRow.readings.filterLifeTime !== undefined ? "  ·  filter " + purRow.readings.filterLifeTime + "%" : "")
          size: 9.5
          color: card.t.textFaint
        }
        Column {
          id: airBox
          visible: purRow.air !== undefined
          anchors.right: purToggle.left
          anchors.rightMargin: card.t.px(12)
          anchors.verticalCenter: parent.verticalCenter
          // Govee sends no scale. Small whole numbers are the purifier's
          // quality level (1 best, as on the H7124's light ring); anything
          // bigger is treated as PM2.5 in ug/m3.
          readonly property bool isLevel: purRow.air !== undefined && purRow.air <= 5 && Math.round(purRow.air) === purRow.air
          readonly property var levels: ["", "Good", "Fair", "Poor", "Bad", "Bad"]
          readonly property int level: isLevel ? purRow.air : (purRow.air <= 12 ? 1 : purRow.air <= 35 ? 2 : purRow.air <= 55 ? 3 : 4)
          readonly property color tone: level <= 1 ? card.t.green : level === 2 ? card.t.yellow : card.t.red
          JText { anchors.right: parent.right; t: card.t; text: airBox.isLevel ? airBox.levels[airBox.level] : String(purRow.air); size: 13; font.weight: Font.Bold; color: airBox.tone }
          JText { anchors.right: parent.right; t: card.t; text: airBox.isLevel ? "air quality" : "PM2.5"; size: 8.5; color: card.t.textFaint }
        }
        Toggle {
          id: purToggle
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          on: purRow.on
          tint: card.t.accent
          enabled2: !!card.purifier && card.purifier.online
          onFlipped: card.send({ cmd: "purifier", device: card.purifier.device, on: !purRow.on })
        }
      }

      Flow {
        visible: !!card.purifier
        anchors.top: purRow.bottom
        anchors.topMargin: card.t.px(10)
        width: parent.width
        spacing: card.t.px(6)
        Repeater {
          model: card.purifier ? card.purifier.modes : []
          Chip {
            required property var modelData
            label: modelData.label
            tint: card.t.accent
            active: purRow.on && card.purifier.mode === modelData.id
            onTapped: card.send({ cmd: "purifier", device: card.purifier.device, mode: modelData.id })
          }
        }
      }
    }
  }
}
