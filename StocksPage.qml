import QtQuick
import QtQuick.Effects
import qs.Commons

// The Stocks page: search and your watchlist on the left, a big live chart of
// the picked stock on the right, and the day's numbers under it.
Item {
  id: page

  property var t
  property bool shown: false
  property var watchlist: []
  property var quotes: ({})
  property var failed: []          // symbols the last refresh had no data for
  property string selected: ""
  property string range: "1d"
  property var chart: null
  property bool chartLoading: false
  property string chartError: ""
  property var results: []
  property bool searching: false
  property string searchError: ""
  property bool live: false
  property int every: 60
  property real lastAt: 0
  property string error: ""

  signal searchFor(string q)
  signal add(string symbol)
  signal remove(string symbol)
  signal pick(string symbol)
  signal rangePicked(string range)

  readonly property var q: quotes[selected] || null

  function money(v, cur) {
    if (v === null || v === undefined || isNaN(v)) return "—"
    var d = Math.abs(v) >= 1000 ? 2 : (Math.abs(v) < 1 ? 4 : 2)
    return ((cur || "USD") === "USD" ? "$" : "") + Number(v).toLocaleString(Qt.locale("en_US"), "f", d)
  }
  function pct(v) { return (v >= 0 ? "+" : "") + Number(v).toFixed(2) + "%" }
  function big(v) {
    if (v === null || v === undefined || isNaN(v)) return "—"
    var a = Math.abs(v)
    if (a >= 1e12) return (v / 1e12).toFixed(2) + "T"
    if (a >= 1e9) return (v / 1e9).toFixed(2) + "B"
    if (a >= 1e6) return (v / 1e6).toFixed(2) + "M"
    if (a >= 1e3) return (v / 1e3).toFixed(1) + "K"
    return String(Math.round(v))
  }
  function focusSearch() { searchInput.forceActiveFocus() }

  readonly property real gap: t.px(18)

  // ---- Watchlist + search --------------------------------------------------
  GlassCard {
    id: listCard
    t: page.t
    shown: page.shown
    order: 1
    hoverable: false
    width: Math.round((page.width - page.gap) * 0.30)
    height: page.height
    title: "Watchlist"
    icon: "\uf201"
    iconColor: page.t.green

    headerExtra: [
      Row {
        spacing: page.t.px(6)
        Rectangle {
          width: page.t.px(7); height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: page.live ? page.t.green : page.t.textFaint
          SequentialAnimation on opacity {
            running: page.live && page.shown
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
          }
        }
        JText {
          t: page.t
          text: page.live ? "Live · every " + page.every + "s" : "Market closed"
          size: 9.5
          color: page.live ? page.t.green : page.t.textFaint
        }
      }
    ]

    Item {
      anchors.fill: parent

      // Search field
      Rectangle {
        id: searchBox
        width: parent.width
        height: page.t.px(38)
        radius: page.t.radiusSmall
        color: page.t.neu ? page.t.glassInset : page.t.inkA(searchInput.activeFocus ? 0.075 : 0.045)
        InsetShade { t: page.t }
        border.width: 1
        border.color: searchInput.activeFocus ? page.t.borderStrong : page.t.border
        Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }

        JText { id: glass; t: page.t; x: page.t.px(12); anchors.verticalCenter: parent.verticalCenter; text: ""; size: 11; color: page.t.textFaint }
        TextInput {
          id: searchInput
          anchors.left: glass.right
          anchors.leftMargin: page.t.px(10)
          anchors.right: spinner.left
          anchors.rightMargin: page.t.px(8)
          anchors.verticalCenter: parent.verticalCenter
          color: page.t.text
          font.family: page.t.font
          font.pixelSize: page.t.px(12.5)
          selectionColor: page.t.alpha(page.t.accent, 0.4)
          maximumLength: 60
          Accessible.role: Accessible.EditableText
          Accessible.name: "Search stocks"
          clip: true
          property int cursorIndex: 0
          onTextChanged: { cursorIndex = 0; debounce.restart() }
          Keys.onDownPressed: cursorIndex = Math.min(page.results.length - 1, cursorIndex + 1)
          Keys.onUpPressed: cursorIndex = Math.max(0, cursorIndex - 1)
          Keys.onReturnPressed: page.chooseResult(cursorIndex)
          Keys.onEnterPressed: page.chooseResult(cursorIndex)
          Keys.onEscapePressed: function(event) { if (text.length) { text = ""; event.accepted = true } else event.accepted = false }
          JText {
            t: page.t
            anchors.fill: parent
            visible: !searchInput.text.length
            text: "Search a stock, ETF or crypto…"
            size: 12.5
            color: page.t.textFaint
          }
        }
        JText {
          id: spinner
          t: page.t
          anchors.right: parent.right
          anchors.rightMargin: page.t.px(12)
          anchors.verticalCenter: parent.verticalCenter
          text: page.searching ? "•••" : ""
          size: 11
          color: page.t.accent
        }
        Timer { id: debounce; interval: 250; onTriggered: page.searchFor(searchInput.text) }
      }

      // Watchlist rows
      ListView {
        id: list
        anchors.top: searchBox.bottom
        anchors.topMargin: page.t.px(10)
        anchors.bottom: footerNote.top
        anchors.bottomMargin: page.t.px(6)
        width: parent.width
        clip: true
        spacing: page.t.px(3)
        model: page.watchlist
        boundsBehavior: Flickable.StopAtBounds

        add: Transition {
          NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(220) }
          NumberAnimation { property: "x"; from: page.t.px(14); duration: Style.duration(240); easing.type: Easing.OutCubic }
        }
        displaced: Transition { NumberAnimation { properties: "y"; duration: Style.duration(200); easing.type: Easing.OutCubic } }

        delegate: Rectangle {
          id: row
          required property string modelData
          required property int index
          readonly property var q: page.quotes[modelData] || null
          readonly property bool isSel: page.selected === modelData
          readonly property bool upDay: q ? q.pct >= 0 : true
          readonly property real e: listCard.ease(listCard.progress * 1.6 - index * 0.05)

          width: ListView.view.width
          height: page.t.px(56)
          radius: page.t.radiusSmall
          opacity: e
          color: isSel ? page.t.raised : (rh.hovered ? page.t.inkA(0.03) : "transparent")
          border.width: 0
          Behavior on color { ColorAnimation { duration: Style.duration(140) } }

          JText {
            id: sym
            t: page.t
            x: page.t.px(12)
            y: page.t.px(9)
            width: page.t.px(110)
            text: row.modelData
            size: 13
            font.weight: Font.Bold
          }
          JText {
            t: page.t
            x: sym.x
            anchors.top: sym.bottom
            anchors.topMargin: page.t.px(2)
            width: spark.x - x - page.t.px(8)
            text: row.q ? row.q.name : page.failed.indexOf(row.modelData) >= 0 ? "No data" : "Loading…"
            size: 9.5
            color: page.t.textFaint
          }
          Sparkline {
            id: spark
            anchors.right: priceCol.left
            anchors.rightMargin: page.t.px(10)
            anchors.verticalCenter: parent.verticalCenter
            width: page.t.px(80)
            height: page.t.px(30)
            lineWidth: 1.5
            values: row.q ? row.q.spark : []
            color: row.upDay ? page.t.green : page.t.red
            progress: listCard.progress
          }
          Column {
            id: priceCol
            anchors.right: parent.right
            anchors.rightMargin: rh.hovered ? page.t.px(34) : page.t.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: page.t.px(3)
            Behavior on anchors.rightMargin { NumberAnimation { duration: Style.duration(140) } }
            LiveNumber {
              anchors.right: parent.right
              t: page.t
              value: row.q && row.q.price !== null ? row.q.price : NaN
              format: function(v) { return page.money(v, row.q ? row.q.currency : "USD") }
              size: 12
              font.weight: Font.DemiBold
            }
            Rectangle {
              anchors.right: parent.right
              height: page.t.px(17)
              width: pctText.implicitWidth + page.t.px(10)
              radius: page.t.px(5)
              color: "transparent"
              Behavior on color { ColorAnimation { duration: Style.duration(300) } }
              JText { id: pctText; t: page.t; anchors.centerIn: parent; text: row.q ? page.pct(row.q.pct) : ""; size: 9.5; color: row.upDay ? page.t.green : page.t.red }
            }
          }
          // Remove
          JText {
            t: page.t
            anchors.right: parent.right
            anchors.rightMargin: page.t.px(12)
            anchors.verticalCenter: parent.verticalCenter
            text: "×"
            size: 15
            opacity: rh.hovered ? 1 : 0
            color: xh.hovered ? page.t.red : page.t.textFaint
            Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
            HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: page.remove(row.modelData) }
          }

          HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: page.pick(row.modelData) }
        }
      }

      JText {
        visible: page.watchlist.length === 0
        anchors.centerIn: list
        t: page.t
        text: "Search above to add stocks you follow."
        size: 11
        color: page.t.textFaint
      }

      JText {
        id: footerNote
        anchors.bottom: parent.bottom
        width: parent.width
        t: page.t
        text: page.error ? page.error
          : (page.lastAt > 0 ? "Updated " + Qt.formatTime(new Date(page.lastAt * 1000), page.t.clock24 ? "HH:mm:ss" : "h:mm:ss AP") + "  ·  " : "") + "Yahoo Finance (unofficial)"
        size: 9
        color: page.error ? page.t.red : page.t.textFaint
      }

      // Search results, dropped over the list.
      Rectangle {
        id: drop
        readonly property bool open: searchInput.text.length > 0 && (page.results.length > 0 || !page.searching)
        anchors.top: searchBox.bottom
        anchors.topMargin: page.t.px(6)
        width: parent.width
        height: open ? Math.min(resultCol.implicitHeight + page.t.px(12), page.t.px(420)) : 0
        visible: height > 1
        clip: true
        z: 10
        radius: page.t.radiusSmall
        color: Qt.tint(page.t.base, page.t.inkA(0.06))
        border.width: 1
        border.color: page.t.borderStrong
        Behavior on height { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

        Column {
          id: resultCol
          x: page.t.px(6)
          y: page.t.px(6)
          width: parent.width - page.t.px(12)
          spacing: page.t.px(2)
          JText {
            visible: page.results.length === 0
            t: page.t
            width: parent.width
            height: page.t.px(36)
            text: page.searchError ? "  Search failed: " + page.searchError : page.searching ? "  Searching…" : "  No matches"
            size: 11
            color: page.t.textFaint
          }
          Repeater {
            model: page.results
            Rectangle {
              id: res
              required property var modelData
              required property int index
              readonly property bool have: page.watchlist.indexOf(modelData.symbol) >= 0
              readonly property bool cur: index === searchInput.cursorIndex
              width: resultCol.width
              height: page.t.px(44)
              radius: page.t.px(8)
              color: cur || resh.hovered ? page.t.raised : "transparent"
              JText { id: rs; t: page.t; x: page.t.px(10); y: page.t.px(6); width: page.t.px(90); text: res.modelData.symbol; size: 12; font.weight: Font.Bold }
              JText { t: page.t; x: rs.x; anchors.top: rs.bottom; anchors.topMargin: page.t.px(1); width: parent.width - x - addTag.width - page.t.px(20); text: res.modelData.name + "  ·  " + res.modelData.exchange + " " + res.modelData.kind; size: 9.5; color: page.t.textFaint }
              JText {
                id: addTag
                t: page.t
                anchors.right: parent.right
                anchors.rightMargin: page.t.px(10)
                anchors.verticalCenter: parent.verticalCenter
                text: res.have ? " Added" : " Add"
                size: 10
                color: res.have ? page.t.green : page.t.accent
              }
              HoverHandler { id: resh; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: page.chooseResult(res.index) }
            }
          }
        }
      }
    }
  }

  function chooseResult(i) {
    if (i < 0 || i >= results.length) return
    var s = results[i].symbol
    if (watchlist.indexOf(s) < 0) add(s)
    pick(s)
    searchInput.text = ""
    searchInput.focus = false
  }

  // ---- Chart ---------------------------------------------------------------
  GlassCard {
    id: chartCard
    t: page.t
    shown: page.shown
    order: 2
    hoverable: false
    x: listCard.width + page.gap
    width: page.width - x
    height: Math.round(page.height - page.gap - page.t.px(132))

    readonly property var c: page.chart && page.chart.symbol === page.selected ? page.chart : null
    readonly property real livePrice: page.q && page.q.price !== null ? page.q.price : (c ? c.price : NaN)
    // On 1D the change is against yesterday's close; on longer ranges,
    // against the first price in view.
    readonly property real basePrice: page.range === "1d" && page.q ? page.q.prevClose : (c ? c.base : NaN)
    readonly property real chg: !isNaN(livePrice) && basePrice ? livePrice - basePrice : 0
    readonly property real chgPct: basePrice ? chg / basePrice * 100 : 0
    readonly property bool up: chg >= 0

    Item {
      anchors.fill: parent

      JText {
        id: bigSym
        t: page.t
        text: page.selected || "Pick a stock"
        size: 22
        font.weight: Font.Bold
      }
      JText {
        t: page.t
        anchors.left: bigSym.right
        anchors.leftMargin: page.t.px(12)
        anchors.baseline: bigSym.baseline
        width: Math.max(0, rangeSeg.x - x - page.t.px(12))
        text: (chartCard.c ? chartCard.c.name + (chartCard.c.exchange ? "  ·  " + chartCard.c.exchange : "") : (page.q ? page.q.name : ""))
        size: 11
        color: page.t.textDim
      }
      Segmented {
        id: rangeSeg
        t: page.t
        anchors.right: parent.right
        options: [{ key: "1d", label: "1D" }, { key: "5d", label: "5D" }, { key: "1mo", label: "1M" }, { key: "6mo", label: "6M" }, { key: "1y", label: "1Y" }, { key: "5y", label: "5Y" }]
        slotW: page.t.px(44)
        current: page.range
        onPicked: function(k) { page.rangePicked(k) }
      }

      Row {
        id: priceRow
        anchors.top: bigSym.bottom
        anchors.topMargin: page.t.px(6)
        spacing: page.t.px(14)
        LiveNumber {
          t: page.t
          value: chartCard.livePrice
          format: function(v) { return page.money(v, chartCard.c ? chartCard.c.currency : "USD") }
          size: 34
          font.weight: Font.Bold
          font.letterSpacing: -1
        }
        Column {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: page.t.px(4)
          JText {
            t: page.t
            visible: !isNaN(chartCard.livePrice) && chartCard.basePrice > 0
            text: (chartCard.up ? "▲ " : "▼ ") + Math.abs(chartCard.chg).toFixed(2) + "  (" + page.pct(chartCard.chgPct) + ")"
            size: 12.5
            font.weight: Font.DemiBold
            color: chartCard.up ? page.t.green : page.t.red
          }
          JText {
            t: page.t
            text: { switch (page.range) { case "1d": return "today"; case "5d": return "past 5 days"; case "1mo": return "past month"; case "6mo": return "past 6 months"; case "1y": return "past year"; default: return "past 5 years" } }
            size: 9.5
            color: page.t.textFaint
          }
        }
      }

      StockChart {
        id: bigChart
        t: page.t
        anchors.top: priceRow.bottom
        anchors.topMargin: page.t.px(14)
        anchors.bottom: parent.bottom
        width: parent.width
        key: page.selected + ":" + page.range
        points: chartCard.c && chartCard.c.range === page.range ? chartCard.c.points : []
        base: page.range === "1d" && page.q ? (page.q.prevClose || 0) : (chartCard.c ? chartCard.c.base || 0 : 0)
        range: page.range
        currency: chartCard.c ? chartCard.c.currency : "USD"
      }

      JText {
        anchors.centerIn: bigChart
        visible: bigChart.points.length < 2
        t: page.t
        text: page.chartError ? page.chartError : page.selected ? "Loading chart…" : "Search or pick a stock on the left."
        size: 11
        color: page.chartError ? page.t.red : page.t.textFaint
      }
    }
  }

  // ---- Stats ---------------------------------------------------------------
  GlassCard {
    id: statsCard
    t: page.t
    shown: page.shown
    order: 3
    hoverable: false
    x: chartCard.x
    y: chartCard.height + page.gap
    width: chartCard.width
    height: page.height - y
    title: "Today"
    icon: ""
    iconColor: page.t.cyan

    readonly property var c: chartCard.c

    component RangeBar: Column {
      id: rb
      property string label: ""
      property real lo: NaN
      property real hi: NaN
      property real now: NaN
      spacing: page.t.px(6)
      JText { t: page.t; text: rb.label; size: 10; color: page.t.textFaint }
      Item {
        width: parent.width
        height: page.t.px(8)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: page.t.px(4); radius: height / 2; color: page.t.inkA(0.08) }
        Rectangle {
          readonly property real f: !isNaN(rb.lo) && !isNaN(rb.hi) && rb.hi > rb.lo && !isNaN(rb.now) ? Math.max(0, Math.min(1, (rb.now - rb.lo) / (rb.hi - rb.lo))) : 0
          x: (parent.width - width) * f * statsCard.ease(statsCard.progress * 1.4)
          anchors.verticalCenter: parent.verticalCenter
          width: page.t.px(10); height: width; radius: width / 2
          color: page.t.accent
          border.width: 2; border.color: "white"
          Behavior on x { enabled: statsCard.progress >= 1; NumberAnimation { duration: Style.duration(500); easing.type: Easing.OutCubic } }
        }
      }
      Item {
        width: parent.width
        height: page.t.px(14)
        JText { t: page.t; text: page.money(rb.lo); size: 9.5; color: page.t.textDim }
        JText { t: page.t; anchors.right: parent.right; text: page.money(rb.hi); size: 9.5; color: page.t.textDim }
      }
    }

    component Stat: Column {
      property string label: ""
      property string value: ""
      spacing: page.t.px(4)
      JText { t: page.t; text: parent.label; size: 10; color: page.t.textFaint }
      JText { t: page.t; text: parent.value; size: 15; font.weight: Font.Bold }
    }

    Row {
      anchors.fill: parent
      anchors.topMargin: page.t.px(4)
      spacing: page.t.px(28)
      readonly property real colW: (width - spacing * 3) / 4
      opacity: statsCard.ease(statsCard.progress * 1.5)

      RangeBar {
        width: parent.colW
        label: "Day range"
        lo: statsCard.c && statsCard.c.dayLow !== null ? statsCard.c.dayLow : NaN
        hi: statsCard.c && statsCard.c.dayHigh !== null ? statsCard.c.dayHigh : NaN
        now: chartCard.livePrice
      }
      RangeBar {
        width: parent.colW
        label: "52-week range"
        lo: statsCard.c && statsCard.c.low52 !== null ? statsCard.c.low52 : NaN
        hi: statsCard.c && statsCard.c.high52 !== null ? statsCard.c.high52 : NaN
        now: chartCard.livePrice
      }
      Stat { width: parent.colW; label: "Previous close"; value: page.money(page.q ? page.q.prevClose : (statsCard.c ? statsCard.c.prevClose : NaN)) }
      Stat { width: parent.colW; label: "Volume"; value: statsCard.c ? page.big(statsCard.c.volume) : "—" }
    }
  }
}
