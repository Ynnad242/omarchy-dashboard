import QtQuick
import qs.Commons

// Settings: general options, privacy and data, the style, and colors.
// Style and colors save to ~/.config/jarvis/look.json through the theme;
// everything else goes out through signals to Jarvis.qml, which saves it.
Item {
  id: page

  property var t
  property bool shown: false
  property var settings: ({})
  property var coach: null
  property string defaultName: ""

  signal setSetting(string key, var value)
  signal eraseData()

  readonly property real gap: t.px(18)

  // ---- small parts ----------------------------------------------------------------------
  component Row2: Item {
    id: r
    property string label: ""
    property string hint: ""
    default property alias control: slot.data
    width: parent ? parent.width : 0
    height: page.t.px(hint.length ? 48 : 38)
    JText {
      id: lab
      t: page.t
      y: r.hint.length ? page.t.px(4) : (r.height - height) / 2
      width: r.width - slot.width - page.t.px(16)
      text: r.label
      size: 12.5
    }
    JText {
      visible: r.hint.length > 0
      t: page.t
      anchors.top: lab.bottom
      anchors.topMargin: page.t.px(2)
      width: lab.width
      text: r.hint
      size: 10.5
      color: page.t.textDim
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  component Field: Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property string accessibleName: ""
    signal submitted(string text)
    width: page.t.px(220)
    height: page.t.px(32)
    radius: page.t.radiusSmall
    color: page.t.glassInset
    InsetShade { t: page.t }
    border.width: 1
    border.color: input.activeFocus ? page.t.accent : page.t.border
    TextInput {
      id: input
      anchors.fill: parent
      anchors.leftMargin: page.t.px(10)
      anchors.rightMargin: page.t.px(10)
      verticalAlignment: TextInput.AlignVCenter
      color: page.t.text
      font.family: page.t.font
      font.pixelSize: page.t.px(12.5)
      selectionColor: page.t.alpha(page.t.accent, 0.35)
      clip: true
      maximumLength: 40
      activeFocusOnTab: true
      Accessible.role: Accessible.EditableText
      Accessible.name: f.accessibleName
      onEditingFinished: f.submitted(text)
      JText {
        anchors.fill: parent
        visible: !input.text.length
        t: page.t
        text: f.placeholder
        size: 12.5
        color: page.t.textFaint
      }
    }
  }

  // ---- General ------------------------------------------------------------------------
  GlassCard {
    id: general
    t: page.t
    shown: page.shown
    order: 1
    hoverable: false
    width: Math.round((page.width - page.gap) * 0.38)
    height: Math.round((page.height - page.gap) * 0.46)
    title: "General"

    Column {
      width: parent.width
      spacing: page.t.px(6)

      Row2 {
        label: "Your name"
        hint: "Shown in the greeting"
        Field {
          text: page.settings.name || ""
          placeholder: page.defaultName
          accessibleName: "Your name"
          onSubmitted: function(v) { page.setSetting("name", v.trim()) }
        }
      }
      Row2 {
        label: "Clock"
        Segmented {
          t: page.t
          slotW: page.t.px(76)
          options: [{ key: "12", label: "12-hour" }, { key: "24", label: "24-hour" }]
          current: page.settings.clock24 === false ? "12" : "24"
          onPicked: function(k) { page.setSetting("clock24", k === "24") }
        }
      }
      Row2 {
        label: "Show seconds"
        JToggle { t: page.t; on: page.settings.seconds !== false; Accessible.name: "Show seconds"; onFlipped: function(v) { page.setSetting("seconds", v) } }
      }
      Row2 {
        label: "Exercise coach"
        hint: "A short set after too much scrolling"
        JToggle { t: page.t; on: page.coach ? page.coach.enabled : true; Accessible.name: "Exercise coach"; onFlipped: function(v) { if (page.coach) page.coach.setOption("enabled", v) } }
      }
      Row2 {
        label: "Coach kicks in after"
        Segmented {
          t: page.t
          slotW: page.t.px(56)
          options: [{ key: "10", label: "10m" }, { key: "15", label: "15m" }, { key: "20", label: "20m" }, { key: "30", label: "30m" }]
          current: page.coach ? String(page.coach.triggerMinutes) : "15"
          onPicked: function(k) { if (page.coach) page.coach.setOption("triggerMinutes", parseInt(k)) }
        }
      }
    }
  }

  // ---- Privacy & data ------------------------------------------------------------------
  GlassCard {
    id: privacy
    t: page.t
    shown: page.shown
    order: 3
    hoverable: false
    y: general.height + page.gap
    width: general.width
    height: page.height - y
    title: "Privacy & data"

    Flickable {
      anchors.fill: parent
      contentHeight: pcol.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: pcol
        width: parent.width
        spacing: page.t.px(6)

        JText {
          t: page.t
          width: parent.width
          wrapMode: Text.Wrap
          elide: Text.ElideNone
          text: "Everything Jarvis records stays on this computer, in ~/.local/state/jarvis and ~/.config/jarvis. Nothing is uploaded. These online services are only asked for data while workspace 1 is on screen:"
          size: 11.5
          color: page.t.textDim
          lineHeight: 1.2
        }
        Item { width: 1; height: page.t.px(4) }
        Row2 {
          label: "Stock prices"
          hint: "Yahoo Finance: your watchlist symbols"
          JToggle { t: page.t; on: page.settings.stocks !== false; Accessible.name: "Stock prices from Yahoo Finance"; onFlipped: function(v) { page.setSetting("stocks", v) } }
        }
        Row2 {
          label: "Weather"
          hint: "Open-Meteo and geo.omarchy.org: your rough location"
          JToggle { t: page.t; on: page.settings.weather !== false; Accessible.name: "Weather from Open-Meteo"; onFlipped: function(v) { page.setSetting("weather", v) } }
        }
        Row2 {
          label: "Air purifier"
          hint: "Govee cloud: your API key and device state"
          JToggle { t: page.t; on: page.settings.goveeCloud !== false; Accessible.name: "Air purifier through Govee cloud"; onFlipped: function(v) { page.setSetting("goveeCloud", v) } }
        }
        Item { width: 1; height: page.t.px(6) }

        // Hold to erase: screen time, coach history and caches. Tasks,
        // the watchlist and settings are kept.
        Rectangle {
          id: erase
          width: parent.width
          height: page.t.px(36)
          radius: page.t.radiusSmall
          color: "transparent"
          border.width: 1
          border.color: page.t.alpha(page.t.red, eraseArea.containsMouse || erase.activeFocus ? 0.8 : 0.45)
          clip: true
          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: "Erase recorded data. Hold to confirm."
          property real hold: 0
          property bool done: false
          Rectangle { height: parent.height; width: parent.width * erase.hold; color: page.t.alpha(page.t.red, 0.25) }
          JText {
            anchors.centerIn: parent
            t: page.t
            text: erase.done ? "Erased" : eraseArea.pressed || erase.hold > 0 ? "Keep holding…" : "Hold to erase screen time, coach history and caches"
            size: 11.5
            color: page.t.red
          }
          NumberAnimation {
            id: fill
            target: erase; property: "hold"; to: 1; duration: 1200
            onFinished: if (erase.hold >= 1) { page.eraseData(); erase.done = true; erase.hold = 0; doneTimer.restart() }
          }
          NumberAnimation { id: unfill; target: erase; property: "hold"; to: 0; duration: 180 }
          Timer { id: doneTimer; interval: 2500; onTriggered: erase.done = false }
          function press() { unfill.stop(); fill.duration = 1200 * (1 - erase.hold); fill.start() }
          function release() { if (erase.hold < 1) { fill.stop(); unfill.start() } }
          Keys.onPressed: function(e) { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return) && !e.isAutoRepeat) { erase.press(); e.accepted = true } }
          Keys.onReleased: function(e) { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return) && !e.isAutoRepeat) { erase.release(); e.accepted = true } }
          MouseArea {
            id: eraseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: erase.press()
            onReleased: erase.release()
            onCanceled: erase.release()
          }
        }
        JText {
          t: page.t
          width: parent.width
          wrapMode: Text.Wrap
          elide: Text.ElideNone
          text: "Tasks, your watchlist and these settings are kept. Delete ~/.local/state/jarvis and ~/.config/jarvis to remove everything."
          size: 10.5
          color: page.t.textDim
        }
      }
    }
  }

  // ---- Style -----------------------------------------------------------------------------
  // Presets: the seven built-in styles. Yours: themes you saved (a style plus
  // your colors), and a tile to save what you have now. Kept in look.json.
  property string styleTab: "presets"
  property bool naming: false
  function startSaving() { styleTab = "mine"; naming = true }

  // A tiny drawing of a look: its canvas, one card, the text and the accent.
  component Mini: Rectangle {
    id: mini
    property string styleKey: "flat"
    property var colors: ({})
    property bool active: false
    property bool focused: false
    readonly property var p: page.t.presetFor(styleKey)
    function c(key, fallback) { var v = colors && colors[key]; return v ? v : fallback }
    radius: page.t.px(8)
    clip: true
    color: c("background", p.base)
    border.width: active || focused ? page.t.px(2) : 1
    border.color: active ? page.t.accent : focused ? page.t.text : page.t.border
    gradient: colors && colors.background ? null : styleKey === "y2k" ? y2kGrad : styleKey === "glass" ? glassGrad : null
    Gradient { id: y2kGrad; GradientStop { position: 0; color: "#0b22e0" } GradientStop { position: 1; color: "#020538" } }
    Gradient { id: glassGrad; GradientStop { position: 0; color: Qt.darker(page.t.themeAccent, 2.2) } GradientStop { position: 1; color: mini.p.base } }

    Rectangle {
      x: parent.width * 0.16; y: parent.height * 0.24
      width: parent.width * 0.68; height: parent.height * 0.52
      radius: Math.min(height / 2, mini.p.radius * 0.6)
      color: mini.styleKey === "swiss" ? "transparent" : mini.c("surface", mini.p.surface)
      border.width: mini.styleKey === "neu" || mini.styleKey === "clay" || mini.styleKey === "swiss" ? 0 : 1
      border.color: mini.c("border", mini.p.border)
      Rectangle { visible: mini.styleKey === "swiss"; width: parent.width; height: 3; color: mini.c("text", mini.p.text) }
      Rectangle {
        visible: mini.styleKey === "y2k"
        x: 2; y: 2; width: parent.width - 4; height: Math.max(4, parent.height * 0.18); radius: 2
        color: "#2a63ff"
      }
      Rectangle {
        visible: mini.styleKey === "discord"
        width: 3; height: parent.height
        color: mini.c("accent", mini.p.accent || page.t.themeAccent)
      }
      Canvas {
        visible: mini.styleKey === "ynnad"
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d"); ctx.reset()
          ctx.fillStyle = "#ef233c"
          ctx.beginPath(); ctx.moveTo(width * 0.62, height); ctx.lineTo(width, height * 0.35); ctx.lineTo(width, height); ctx.closePath(); ctx.fill()
        }
      }
      Rectangle {
        x: page.t.px(8); y: mini.styleKey === "y2k" ? parent.height * 0.32 : page.t.px(8)
        width: parent.width * 0.4; height: page.t.px(4); radius: 2
        color: mini.c("text", mini.p.text); opacity: 0.6
      }
      Rectangle {
        x: page.t.px(8); anchors.bottom: parent.bottom; anchors.bottomMargin: page.t.px(8)
        width: page.t.px(10); height: width; radius: width / 2
        color: mini.c("accent", mini.p.accent || page.t.themeAccent)
      }
    }
  }

  GlassCard {
    id: styleCard
    t: page.t
    shown: page.shown
    order: 2
    hoverable: false
    x: general.width + page.gap
    width: page.width - x
    height: Math.round((page.height - page.gap) * 0.46)
    title: "Style"

    headerExtra: [
      Segmented {
        t: page.t
        slotW: page.t.px(84)
        options: [{ key: "presets", label: "Presets" }, { key: "mine", label: "Yours" + (page.t.saved.length ? " (" + page.t.saved.length + ")" : "") }]
        current: page.styleTab
        onPicked: function(k) { page.styleTab = k; page.naming = false }
      }
    ]

    // Presets
    Grid {
      id: tiles
      visible: page.styleTab === "presets"
      width: parent.width
      columns: 5
      spacing: page.t.px(14)
      readonly property real tileW: (width - spacing * (columns - 1)) / columns
      readonly property real tileH: Math.max(page.t.px(60), (parent.height - spacing - page.t.px(44)) / 2)

      Repeater {
        model: page.t.styles
        Item {
          id: tile
          required property var modelData
          required property int index
          readonly property bool active: page.t.style === modelData.key && Object.keys(page.t.custom || {}).length === 0
          readonly property bool base: page.t.style === modelData.key
          width: tiles.tileW
          height: tiles.tileH + page.t.px(26)
          activeFocusOnTab: page.styleTab === "presets"
          Accessible.role: Accessible.RadioButton
          Accessible.name: modelData.label + " style"
          Accessible.checked: base
          Keys.onPressed: function(e) { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { page.t.setStyle(tile.modelData.key); e.accepted = true } }

          Mini { id: tmini; width: parent.width; height: tiles.tileH; styleKey: tile.modelData.key; active: tile.base; focused: tile.activeFocus }
          JText {
            anchors.top: tmini.bottom
            anchors.topMargin: page.t.px(6)
            width: parent.width
            t: page.t
            text: tile.modelData.label + (tile.active ? "  ✓" : tile.base ? "  ✓ + your colors" : "")
            size: 11.5
            font.weight: tile.base ? Font.DemiBold : Font.Normal
            color: tile.base ? page.t.text : page.t.textDim
          }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: page.t.setStyle(tile.modelData.key) }
        }
      }
    }

    // Yours
    Grid {
      id: mine
      visible: page.styleTab === "mine"
      width: parent.width
      columns: 5
      spacing: page.t.px(14)
      readonly property real tileW: tiles.tileW
      readonly property real tileH: tiles.tileH

      // Save what's on screen now.
      Item {
        id: addTile
        width: mine.tileW
        height: mine.tileH + page.t.px(26)
        activeFocusOnTab: page.styleTab === "mine"
        Accessible.role: Accessible.Button
        Accessible.name: "Save the current style and colors as a theme"
        Keys.onPressed: function(e) { if (!page.naming && (e.key === Qt.Key_Space || e.key === Qt.Key_Return)) { page.naming = true; e.accepted = true } }
        Rectangle {
          id: addBox
          width: parent.width
          height: mine.tileH
          radius: page.t.px(8)
          color: addHover.hovered || page.naming ? page.t.inkA(0.06) : "transparent"
          border.width: addTile.activeFocus ? page.t.px(2) : 1
          border.color: addTile.activeFocus || page.naming ? page.t.accent : page.t.inkA(0.25)
          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
          JText {
            visible: !page.naming
            anchors.centerIn: parent
            t: page.t
            text: "+  Save current"
            size: 12
            color: page.t.textDim
          }
          // Naming the theme, inline.
          Column {
            visible: page.naming
            anchors.centerIn: parent
            width: parent.width - page.t.px(20)
            spacing: page.t.px(6)
            Rectangle {
              width: parent.width
              height: page.t.px(30)
              radius: page.t.radiusSmall
              color: page.t.glassInset
              border.width: 1
              border.color: nameInput.activeFocus ? page.t.accent : page.t.border
              TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: page.t.px(8)
                anchors.rightMargin: page.t.px(8)
                verticalAlignment: TextInput.AlignVCenter
                color: page.t.text
                font.family: page.t.font
                font.pixelSize: page.t.px(12)
                maximumLength: 30
                clip: true
                Accessible.role: Accessible.EditableText
                Accessible.name: "Theme name"
                function done(save) {
                  if (save) page.t.saveCurrent(text)
                  text = ""
                  page.naming = false
                }
                Keys.onReturnPressed: done(true)
                Keys.onEnterPressed: done(true)
                Keys.onEscapePressed: done(false)
                JText { anchors.fill: parent; visible: !nameInput.text.length; t: page.t; text: page.t.uniqueName(); size: 12; color: page.t.textFaint }
              }
            }
            JText { t: page.t; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Enter to save · Esc to cancel"; size: 10; color: page.t.textFaint }
          }
          HoverHandler { id: addHover; cursorShape: page.naming ? Qt.IBeamCursor : Qt.PointingHandCursor }
          TapHandler { enabled: !page.naming; onTapped: page.naming = true }
        }
        JText {
          anchors.top: addBox.bottom
          anchors.topMargin: page.t.px(6)
          width: parent.width
          t: page.t
          text: "Current: " + page.t.styles.filter(function(x) { return x.key === page.t.style })[0].label + (Object.keys(page.t.custom || {}).length ? " + your colors" : "")
          size: 11
          color: page.t.textFaint
        }
      }
      Connections {
        target: page
        function onNamingChanged() { if (page.naming) Qt.callLater(function() { nameInput.forceActiveFocus() }) }
      }

      Repeater {
        model: page.t.saved
        Item {
          id: stile
          required property var modelData
          required property int index
          readonly property bool active: page.t.activeSaved === index
          property bool confirm: false
          width: mine.tileW
          height: mine.tileH + page.t.px(26)
          activeFocusOnTab: page.styleTab === "mine"
          Accessible.role: Accessible.RadioButton
          Accessible.name: modelData.name + " theme"
          Accessible.checked: active
          Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { page.t.applySaved(stile.index); e.accepted = true }
            else if (e.key === Qt.Key_Delete) { if (stile.confirm) page.t.deleteSaved(stile.index); else stile.confirm = true; e.accepted = true }
            else if (e.key === Qt.Key_Escape && stile.confirm) { stile.confirm = false; e.accepted = true }
          }
          onActiveFocusChanged: if (!activeFocus) confirm = false

          Mini {
            id: smini
            width: parent.width
            height: mine.tileH
            styleKey: stile.modelData.style
            colors: stile.modelData.colors
            active: stile.active
            focused: stile.activeFocus
            TapHandler { enabled: !stile.confirm; onTapped: page.t.applySaved(stile.index) }
            HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }

            // Delete, in two steps.
            Rectangle {
              visible: (sh.hovered || stile.activeFocus) && !stile.confirm
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: page.t.px(6)
              width: page.t.px(22); height: width; radius: width / 2
              color: Qt.rgba(0, 0, 0, 0.55)
              JText { t: page.t; anchors.centerIn: parent; text: "×"; size: 13; color: "white" }
              Accessible.role: Accessible.Button
              Accessible.name: "Delete " + stile.modelData.name
              TapHandler { onTapped: stile.confirm = true }
            }
            Rectangle {
              visible: stile.confirm
              anchors.fill: parent
              radius: parent.radius
              color: Qt.rgba(0, 0, 0, 0.72)
              Column {
                anchors.centerIn: parent
                spacing: page.t.px(8)
                JText { t: page.t; anchors.horizontalCenter: parent.horizontalCenter; text: "Delete “" + stile.modelData.name + "”?"; size: 11.5; color: "white" }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: page.t.px(8)
                  Rectangle {
                    width: page.t.px(64); height: page.t.px(26); radius: page.t.px(6)
                    color: page.t.red
                    JText { t: page.t; anchors.centerIn: parent; text: "Delete"; size: 11; color: "white"; font.weight: Font.DemiBold }
                    TapHandler { onTapped: page.t.deleteSaved(stile.index) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                  }
                  Rectangle {
                    width: page.t.px(64); height: page.t.px(26); radius: page.t.px(6)
                    color: Qt.rgba(1, 1, 1, 0.15)
                    JText { t: page.t; anchors.centerIn: parent; text: "Keep"; size: 11; color: "white" }
                    TapHandler { onTapped: stile.confirm = false }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                  }
                }
              }
            }
          }
          JText {
            anchors.top: smini.bottom
            anchors.topMargin: page.t.px(6)
            width: parent.width
            t: page.t
            text: stile.modelData.name + (stile.active ? "  ✓" : "")
            size: 11.5
            font.weight: stile.active ? Font.DemiBold : Font.Normal
            color: stile.active ? page.t.text : page.t.textDim
          }
        }
      }
    }

    JText {
      visible: page.styleTab === "mine" && page.t.saved.length === 0 && !page.naming
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: parent.width * 0.7
      horizontalAlignment: Text.AlignRight
      wrapMode: Text.Wrap
      elide: Text.ElideNone
      t: page.t
      text: "Pick a preset, change any colors below, then save it here to switch back to it any time."
      size: 11
      color: page.t.textFaint
    }
  }

  // ---- Colors -----------------------------------------------------------------------------
  GlassCard {
    id: colors
    t: page.t
    shown: page.shown
    order: 4
    hoverable: false
    x: styleCard.x
    y: styleCard.height + page.gap
    width: styleCard.width
    height: page.height - y
    title: "Colors"
    action: Object.keys(page.t.custom || {}).length && page.t.activeSaved < 0 ? "Save as theme" : ""
    onActionClicked: page.startSaving()
    headerExtra: [
      JText {
        visible: Object.keys(page.t.custom || {}).length > 0
        t: page.t
        text: "Reset all"
        size: 11.5
        color: resetHover.hovered ? page.t.text : page.t.textFaint
        Accessible.role: Accessible.Button
        Accessible.name: "Reset all colors"
        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: page.t.resetColors() }
      }
    ]

    readonly property var palettes: ({
      background: ["#0b0b0e", "#111318", "#1a1b26", "#1e1e2e", "#14092b", "#f2f0eb", "#e7e0d3", "#ffffff"],
      surface: ["#15161c", "#1f2030", "#24283b", "#2d2f44", "#ffffff", "#efe9de", "#f4f4f2", "#0f0f12"],
      border: ["#ffffff", "#7aa2f7", "#bb9af7", "#2ac3de", "#888888", "#111111", "#3a332b", "#e30613"],
      accent: ["#7aa2f7", "#bb9af7", "#ff5fd2", "#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#2ac3de", "#e30613"],
      text: ["#ffffff", "#e6e6e6", "#c0caf5", "#a9b1d6", "#f7f2ff", "#111111", "#3a332b"]
    })
    // "#rrggbb", whatever alpha the color carries.
    function hex(c) {
      function two(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
      return "#" + two(c.r) + two(c.g) + two(c.b)
    }
    function current(key) {
      switch (key) {
        case "background": return page.t.base
        case "surface": return page.t.surface
        case "border": return page.t.borderStrong
        case "accent": return page.t.accent
        default: return page.t.text
      }
    }

    Column {
      width: parent.width
      spacing: page.t.px(4)

      Repeater {
        model: page.t.colorKeys
        Item {
          id: crow
          required property var modelData
          readonly property bool custom: !!(page.t.custom && page.t.custom[modelData.key])
          width: parent.width
          height: page.t.px(44)

          JText {
            id: clabel
            t: page.t
            width: page.t.px(96)
            anchors.verticalCenter: parent.verticalCenter
            text: crow.modelData.label
            size: 12.5
          }
          // The color in use now.
          Rectangle {
            id: now
            anchors.left: clabel.right
            anchors.verticalCenter: parent.verticalCenter
            width: page.t.px(30); height: width
            radius: page.t.px(6)
            color: colors.current(crow.modelData.key)
            border.width: 1
            border.color: page.t.inkA(0.25)
          }
          Row {
            id: swatches
            anchors.left: now.right
            anchors.leftMargin: page.t.px(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: page.t.px(6)
            Repeater {
              model: colors.palettes[crow.modelData.key]
              Rectangle {
                id: sw
                required property string modelData
                readonly property bool picked: crow.custom && String(page.t.custom[crow.modelData.key]).toLowerCase() === modelData.toLowerCase()
                width: page.t.px(22); height: width
                radius: width / 2
                color: modelData
                border.width: picked || sw.activeFocus ? page.t.px(2) : 1
                border.color: picked ? page.t.accent : sw.activeFocus ? page.t.text : page.t.inkA(0.25)
                scale: swh.hovered ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: Style.duration(110) } }
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: crow.modelData.label + " color " + modelData
                Keys.onPressed: function(e) { if (e.key === Qt.Key_Space || e.key === Qt.Key_Return) { page.t.setColor(crow.modelData.key, sw.modelData); e.accepted = true } }
                HoverHandler { id: swh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.t.setColor(crow.modelData.key, sw.modelData) }
              }
            }
          }
          Field {
            id: hex
            anchors.left: swatches.right
            anchors.leftMargin: page.t.px(14)
            anchors.verticalCenter: parent.verticalCenter
            width: page.t.px(96)
            text: crow.custom ? page.t.custom[crow.modelData.key] : ""
            placeholder: colors.hex(colors.current(crow.modelData.key))
            accessibleName: crow.modelData.label + " hex color"
            onSubmitted: function(v) {
              v = v.trim()
              if (v.length && v.charAt(0) !== "#") v = "#" + v
              if (/^#[0-9a-fA-F]{6}$/.test(v)) page.t.setColor(crow.modelData.key, v.toLowerCase())
              else if (!v.length) page.t.setColor(crow.modelData.key, "")
            }
          }
          JText {
            visible: crow.custom
            anchors.left: hex.right
            anchors.leftMargin: page.t.px(12)
            anchors.verticalCenter: parent.verticalCenter
            t: page.t
            text: "Reset"
            size: 11.5
            color: rh.hovered ? page.t.text : page.t.textDim
            Accessible.role: Accessible.Button
            Accessible.name: "Reset " + crow.modelData.label
            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: page.t.setColor(crow.modelData.key, "") }
          }
        }
      }
    }
  }
}
