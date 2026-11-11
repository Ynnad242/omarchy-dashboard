import QtQuick
import qs.Commons

// The Tasks page: add tasks with a due day, filter them, tick, rename
// (double-click), re-date (click the date) and delete them; beside it,
// today's progress and what's coming up. Everything is saved to disk.
Item {
  id: page

  property var t
  property bool shown: false
  property ListModel todos
  property int coachSets: 0
  property var dueLabel: function(iso) { return iso }
  property var dueState: function(iso) { return "" }   // "overdue" | "today" | "soon" | ""

  signal added(string title, string due)
  signal toggled(int index)
  signal removed(int index)
  signal renamed(int index, string title)
  signal redated(int index, string due)
  signal clearDone()

  property string filter: "all"
  property string newDue: "today"
  property int rev: 0     // bumps on any change so counts re-evaluate

  Connections {
    target: page.todos
    function onDataChanged() { page.rev++ }
    function onRowsInserted() { page.rev++ }
    function onRowsRemoved() { page.rev++ }
    function onModelReset() { page.rev++ }
  }

  function isoFor(choice) {
    var d = new Date()
    if (choice === "none") return ""
    if (choice === "tomorrow") d.setDate(d.getDate() + 1)
    if (choice === "week") d.setDate(d.getDate() + ((7 - d.getDay()) % 7 || 7)) // this Sunday
    return Qt.formatDate(d, "yyyy-MM-dd")
  }
  function nextDue(iso) {
    // Clicking a date cycles today -> tomorrow -> no date -> today.
    var st = dueState(iso)
    if (iso === "" ) return isoFor("today")
    if (st === "today" || st === "overdue") return isoFor("tomorrow")
    return ""
  }
  function passes(row) {
    if (!row) return false
    var st = dueState(row.due)
    switch (filter) {
      case "today": return !row.done && (st === "today" || st === "overdue")
      case "upcoming": return !row.done && st !== "today" && st !== "overdue"
      case "done": return row.done
      default: return true
    }
  }
  function count(fn) {
    page.rev
    var c = 0
    if (!todos) return 0
    for (var i = 0; i < todos.count; i++) if (fn(todos.get(i))) c++
    return c
  }
  readonly property int todayTotal: count(function(r) { var s = dueState(r.due); return s === "today" || s === "overdue" || (r.done && r.doneAt && Qt.formatDate(new Date(r.doneAt), "yyyy-MM-dd") === Qt.formatDate(new Date(), "yyyy-MM-dd")) })
  readonly property int todayDone: count(function(r) { return r.done && r.doneAt && Qt.formatDate(new Date(r.doneAt), "yyyy-MM-dd") === Qt.formatDate(new Date(), "yyyy-MM-dd") })
  readonly property int overdue: count(function(r) { return !r.done && dueState(r.due) === "overdue" })
  readonly property int openCount: count(function(r) { return !r.done })
  readonly property int doneCount: count(function(r) { return r.done })

  function focusInput() { input.forceActiveFocus() }

  readonly property real gap: t.px(18)

  // ---- The list --------------------------------------------------------------
  GlassCard {
    id: listCard
    t: page.t
    shown: page.shown
    order: 1
    hoverable: false
    width: Math.round((page.width - page.gap) * 0.66)
    height: page.height
    title: "Tasks"
    icon: ""
    iconColor: page.t.green
    action: page.doneCount > 0 ? "Clear done" : ""
    onActionClicked: page.clearDone()

    headerExtra: [
      Segmented {
        t: page.t
        slotW: page.t.px(80)
        options: [{ key: "all", label: "All" }, { key: "today", label: "Today" }, { key: "upcoming", label: "Upcoming" }, { key: "done", label: "Done" }]
        current: page.filter
        onPicked: function(k) { page.filter = k }
      }
    ]

    Item {
      anchors.fill: parent

      // Add bar
      Rectangle {
        id: addBar
        width: parent.width
        height: page.t.px(44)
        radius: page.t.radiusSmall
        color: page.t.neu ? page.t.glassInset : page.t.inkA(input.activeFocus ? 0.075 : 0.045)
        InsetShade { t: page.t }
        border.width: 1
        border.color: input.activeFocus ? page.t.borderStrong : page.t.border
        Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }

        JText { id: plus; t: page.t; x: page.t.px(14); anchors.verticalCenter: parent.verticalCenter; text: ""; size: 11; color: page.t.green }
        TextInput {
          id: input
          anchors.left: plus.right
          anchors.leftMargin: page.t.px(12)
          anchors.right: dueChips.left
          anchors.rightMargin: page.t.px(12)
          anchors.verticalCenter: parent.verticalCenter
          color: page.t.text
          font.family: page.t.font
          font.pixelSize: page.t.px(13)
          selectionColor: page.t.alpha(page.t.accent, 0.4)
          maximumLength: 200
          Accessible.role: Accessible.EditableText
          Accessible.name: "Add a task"
          clip: true
          function submit() { if (text.trim().length) { page.added(text.trim(), page.isoFor(page.newDue)); text = "" } }
          Keys.onReturnPressed: submit()
          Keys.onEnterPressed: submit()
          Keys.onTabPressed: {
            var order = ["today", "tomorrow", "week", "none"]
            page.newDue = order[(order.indexOf(page.newDue) + 1) % order.length]
          }
          Keys.onEscapePressed: function(event) { if (text.length) { text = ""; event.accepted = true } else event.accepted = false }
          JText {
            t: page.t
            anchors.fill: parent
            visible: !input.text.length
            text: "Add a task…   (Tab changes the day)"
            size: 13
            color: page.t.textFaint
          }
        }
        Row {
          id: dueChips
          anchors.right: parent.right
          anchors.rightMargin: page.t.px(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: page.t.px(5)
          Repeater {
            model: [{ k: "today", l: "Today" }, { k: "tomorrow", l: "Tomorrow" }, { k: "week", l: "This week" }, { k: "none", l: "No date" }]
            Rectangle {
              required property var modelData
              readonly property bool on: page.newDue === modelData.k
              height: page.t.px(26)
              width: dl.implicitWidth + page.t.px(16)
              radius: height / 2
              color: on ? page.t.raised : (dh.hovered ? page.t.inkA(0.05) : "transparent")
              border.width: 1
              border.color: on ? page.t.borderStrong : "transparent"
              Behavior on color { ColorAnimation { duration: Style.duration(140) } }
              JText { id: dl; t: page.t; anchors.centerIn: parent; text: parent.modelData.l; size: 10; color: parent.on ? page.t.text : page.t.textDim }
              HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: page.newDue = parent.modelData.k }
            }
          }
        }
      }

      ListView {
        id: list
        anchors.top: addBar.bottom
        anchors.topMargin: page.t.px(12)
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        model: page.todos
        boundsBehavior: Flickable.StopAtBounds

        add: Transition {
          NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(220) }
          NumberAnimation { property: "x"; from: page.t.px(14); duration: Style.duration(240); easing.type: Easing.OutCubic }
        }
        remove: Transition {
          NumberAnimation { property: "opacity"; to: 0; duration: Style.duration(160) }
        }
        displaced: Transition { NumberAnimation { properties: "y"; duration: Style.duration(220); easing.type: Easing.OutCubic } }

        delegate: Item {
          id: row
          required property string title
          required property bool done
          required property string due
          required property int index
          readonly property bool show: { page.rev; return page.passes({ done: done, due: due }) }
          readonly property string st: page.dueState(due)
          readonly property real e: listCard.ease(listCard.progress * 1.6 - index * 0.04)
          property bool editing: false

          width: ListView.view.width
          height: show ? page.t.px(46) : 0
          opacity: show ? e : 0
          visible: height > 0.5
          clip: true
          Behavior on height { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }

          Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: page.t.px(3)
            radius: page.t.radiusSmall
            color: rh.hovered ? page.t.inkA(0.045) : "transparent"
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }
          }

          Rectangle {
            id: box
            x: page.t.px(10)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -page.t.px(1.5)
            width: page.t.px(20); height: width
            radius: page.t.px(6)
            color: row.done ? page.t.green : "transparent"
            border.width: row.done ? 0 : 1.5
            border.color: bh.hovered ? page.t.green : page.t.inkA(0.3)
            Behavior on color { ColorAnimation { duration: Style.duration(160) } }
            JText {
              t: page.t
              anchors.centerIn: parent
              text: ""
              size: 10
              color: page.t.base
              scale: row.done ? 1 : 0.4
              opacity: row.done ? 1 : 0
              Behavior on scale { NumberAnimation { duration: Style.duration(200); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
              Behavior on opacity { NumberAnimation { duration: Style.duration(140) } }
            }
            HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: page.toggled(row.index) }
          }

          JText {
            id: label
            visible: !row.editing
            t: page.t
            anchors.left: box.right
            anchors.leftMargin: page.t.px(12)
            anchors.right: dueTag.left
            anchors.rightMargin: page.t.px(12)
            anchors.verticalCenter: box.verticalCenter
            text: row.title
            size: 12.5
            color: row.done ? page.t.textFaint : page.t.text
            Behavior on color { ColorAnimation { duration: Style.duration(160) } }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              height: 1
              width: row.done ? Math.min(parent.paintedWidth, parent.width) : 0
              color: page.t.textFaint
              Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
            }
            TapHandler {
              onDoubleTapped: { row.editing = true; edit.text = row.title; edit.forceActiveFocus(); edit.selectAll() }
            }
          }
          TextInput {
            id: edit
            visible: row.editing
            anchors.fill: label
            color: page.t.text
            font.family: page.t.font
            font.pixelSize: page.t.px(12.5)
            selectionColor: page.t.alpha(page.t.accent, 0.4)
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            function finish(save) {
              if (save && text.trim().length && text.trim() !== row.title) page.renamed(row.index, text.trim())
              row.editing = false
            }
            Keys.onReturnPressed: finish(true)
            Keys.onEnterPressed: finish(true)
            Keys.onEscapePressed: finish(false)
            onActiveFocusChanged: if (!activeFocus && row.editing) finish(true)
          }

          Rectangle {
            id: dueTag
            anchors.right: del.left
            anchors.rightMargin: page.t.px(8)
            anchors.verticalCenter: box.verticalCenter
            readonly property color tone: row.done ? page.t.textFaint : row.st === "overdue" ? page.t.red : row.st === "today" ? page.t.yellow : page.t.textDim
            height: page.t.px(22)
            width: Math.max(page.t.px(60), dueText.implicitWidth + page.t.px(16))
            radius: height / 2
            color: duh.hovered ? page.t.inkA(0.06) : "transparent"
            border.width: 0
            JText { id: dueText; t: page.t; anchors.centerIn: parent; text: row.due ? page.dueLabel(row.due) : "No date"; size: 10; color: dueTag.tone }
            HoverHandler { id: duh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: page.redated(row.index, page.nextDue(row.due)) }
          }

          JText {
            id: del
            t: page.t
            anchors.right: parent.right
            anchors.rightMargin: page.t.px(12)
            anchors.verticalCenter: box.verticalCenter
            width: page.t.px(14)
            text: "×"
            size: 15
            opacity: rh.hovered ? 1 : 0
            color: xh.hovered ? page.t.red : page.t.textFaint
            Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
            HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: page.removed(row.index) }
          }

          HoverHandler { id: rh }
        }
      }

      JText {
        anchors.centerIn: list
        visible: { page.rev; return page.count(page.passes) === 0 }
        t: page.t
        text: page.filter === "done" ? "Nothing finished yet." : page.todos && page.todos.count ? "Nothing here. Nice." : "No tasks yet. Type one above and press Enter."
        size: 12
        color: page.t.textFaint
      }
    }
  }

  // ---- Today's progress -------------------------------------------------------
  GlassCard {
    id: progressCard
    t: page.t
    shown: page.shown
    order: 2
    hoverable: false
    x: listCard.width + page.gap
    width: page.width - x
    height: Math.round((page.height - page.gap) * 0.48)
    title: "Today"
    icon: ""
    iconColor: page.t.magenta

    Item {
      anchors.fill: parent
      Ring {
        id: ring
        t: page.t
        width: Math.min(parent.height, page.t.px(170))
        height: width
        anchors.verticalCenter: parent.verticalCenter
        thickness: page.t.px(10)
        value: page.todayTotal ? page.todayDone / page.todayTotal * 100 : 0
        progress: progressCard.ease(progressCard.progress * 1.3)
        color: page.t.accent
        label: page.todayDone + " of " + page.todayTotal
        Behavior on value { NumberAnimation { duration: Style.duration(400); easing.type: Easing.OutCubic } }
      }
      Column {
        anchors.left: ring.right
        anchors.leftMargin: page.t.px(28)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: page.t.px(14)
        opacity: progressCard.ease(progressCard.progress * 1.5)

        component Line: Row {
          property string glyph: ""
          property color tone: page.t.text
          property string label: ""
          property string value: ""
          spacing: page.t.px(10)
          JText { t: page.t; width: page.t.px(18); text: parent.glyph; size: 12; color: parent.tone }
          JText { t: page.t; width: page.t.px(140); text: parent.label; size: 11.5; color: page.t.textDim }
          JText { t: page.t; text: parent.value; size: 13; font.weight: Font.Bold; color: parent.tone }
        }
        Line { glyph: ""; tone: page.t.green; label: "Done today"; value: String(page.todayDone) }
        Line { glyph: ""; tone: page.t.text; label: "Still open"; value: String(page.openCount) }
        Line { glyph: ""; tone: page.overdue ? page.t.red : page.t.textFaint; label: "Overdue"; value: String(page.overdue) }
        Line { glyph: String.fromCodePoint(0xF01E5); tone: page.t.yellow; label: "Exercise sets"; value: String(page.coachSets) }
      }
    }
  }

  // ---- Coming up -------------------------------------------------------------
  GlassCard {
    id: upCard
    t: page.t
    shown: page.shown
    order: 3
    hoverable: false
    x: progressCard.x
    y: progressCard.height + page.gap
    width: progressCard.width
    height: page.height - y
    title: "Coming up"
    icon: ""
    iconColor: page.t.cyan

    readonly property var upcoming: {
      page.rev
      var out = []
      if (!page.todos) return out
      for (var i = 0; i < page.todos.count; i++) {
        var r = page.todos.get(i)
        if (!r.done && r.due) out.push({ title: r.title, due: r.due })
      }
      out.sort(function(a, b) { return a.due < b.due ? -1 : a.due > b.due ? 1 : 0 })
      return out.slice(0, 6)
    }

    Column {
      anchors.fill: parent
      spacing: page.t.px(6)
      Repeater {
        model: upCard.upcoming
        Item {
          required property var modelData
          required property int index
          width: parent.width
          height: page.t.px(30)
          opacity: upCard.ease(upCard.progress * 1.6 - index * 0.08)
          readonly property string st: page.dueState(modelData.due)
          Rectangle {
            width: page.t.px(3); height: parent.height - page.t.px(10)
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: parent.st === "overdue" ? page.t.red : parent.st === "today" ? page.t.yellow : page.t.cyan
          }
          JText { t: page.t; x: page.t.px(14); anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - page.t.px(90); text: parent.modelData.title; size: 11.5 }
          JText { t: page.t; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: page.dueLabel(parent.modelData.due); size: 10; color: page.t.textFaint }
        }
      }
      JText {
        visible: upCard.upcoming.length === 0
        t: page.t
        text: "Nothing scheduled."
        size: 11
        color: page.t.textFaint
      }
    }
  }
}
