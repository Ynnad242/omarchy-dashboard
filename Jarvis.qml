import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import "MockData.js" as Mock

// Jarvis: a home-screen app that lives on workspace 1. The shell starts it,
// a Hyprland rule puts its window on workspace 1, and it stays there.
// `omarchy-shell shell summon ynnad.jarvis` (Super+Shift+J) jumps to it,
// and reopens it if it was closed.
//
// Live data (stocks, lamps, weather) only refreshes while workspace 1 is on
// screen. The doomscroll coach runs all the time. Coming back after a minute
// or more away replays the entrance; quick switches just show it.
Item {
  id: root

  // The window always exists, so to the shell this plugin is always "open".
  readonly property bool opened: true
  readonly property bool onScreen: win.visible && !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === 1
  property bool live: false
  property real leftAt: 0
  property int page: 0
  readonly property bool homeShown: root.live && root.page === 0
  property string range: "week"
  property var dash: Mock.build(new Date())
  property date now: new Date()
  property int doneCount: 0
  property int todoTotal: 0
  property string briefingTyped: ""
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/jarvis"
  readonly property string configDir: Quickshell.env("HOME") + "/.config/jarvis"

  // Until someone types their name in Settings, the greeting says "User".
  readonly property string defaultName: "User"
  readonly property string userName: root.demo ? "Alex" : (root.settings.name ? root.settings.name : root.defaultName)

  // Demo mode (JARVIS_DEMO=1): every card shows made-up data from
  // MockData.js and nothing is saved. Used for README screenshots, so they
  // never show anyone's real screen time, location or devices.
  readonly property bool demo: Quickshell.env("JARVIS_DEMO") === "1"
  readonly property var demoWeather: ({ type: "weather", place: "Springfield", unit: "F", temp: 64, feels: 62, humidity: 48, wind: 6,
    windUnit: "mph", label: "Partly cloudy", icon: "\ue302", day: true, high: 70, low: 51, rain: 10,
    hours: [{ label: "5p", hour: 17, temp: 63, icon: "\ue302" }, { label: "6p", hour: 18, temp: 61, icon: "\ue302" }, { label: "7p", hour: 19, temp: 59, icon: "\ue37e" },
            { label: "8p", hour: 20, temp: 57, icon: "\ue37e" }, { label: "9p", hour: 21, temp: 55, icon: "\ue379" }] })
  readonly property var demoHome: ({ cloud: "ok", error: "",
    lights: [{ ip: "demo-1", name: "Desk lamp", on: true, brightness: 80, kelvin: 2700, white: true, color: [255, 166, 87] },
             { ip: "demo-2", name: "Floor lamp", on: true, brightness: 45, kelvin: 0, white: false, color: [122, 162, 247] }],
    purifiers: [{ device: "demo", name: "Air purifier", online: true, on: true, mode: "1:2",
      modes: [{ id: "1:1", label: "Low" }, { id: "1:2", label: "Medium" }, { id: "1:3", label: "High" }, { id: "5:0", label: "Sleep" }, { id: "3:0", label: "Auto" }],
      readings: { airQuality: 1, filterLifeTime: 87 } }] })

  // ---- settings (~/.config/jarvis/settings.json) ---------------------------------
  // name, clock24, seconds, and the online services: stocks, weather, goveeCloud.
  property var settings: ({})
  FileView {
    id: settingsFile
    path: root.configDir + "/settings.json"
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: { try { var j = JSON.parse(text()); if (j && typeof j === "object") root.settings = j } catch (e) {} }
  }
  function setSetting(key, value) {
    var s = {}
    for (var k in root.settings) s[k] = root.settings[k]
    s[key] = value
    root.settings = s
    settingsFile.setText(JSON.stringify(s, null, 2) + "\n")
    if (key === "weather" && value === false) root.weather = null
    if (key === "weather" && value === true) root.refreshWeather(true)
    if (key === "goveeCloud" && govee.running) { govee.running = false; Qt.callLater(function() { govee.running = root.onScreen }) }
  }

  // Erase what Jarvis has recorded: screen time, coach history, caches.
  Process { id: eraseProc }
  function eraseData() {
    eraseProc.command = ["rm", "-f", root.stateDir + "/screentime.json", root.stateDir + "/coach.json",
                         root.stateDir + "/weather.json", root.stateDir + "/home.json"]
    eraseProc.running = true
    screenTime.days = ({})
    screenTime.rev++
    doomCoach.testClear()
    doomCoach.doneToday = 0
    doomCoach.lastSite = ""
  }
  // Only real things: tasks due and the weather (no calendar is linked yet).
  readonly property string briefing: root.demo ? "2 tasks due today  \u00b7  64\u00b0 and partly cloudy  \u00b7  stand-up at 9:30" : realBriefing
  readonly property string realBriefing: {
    root.todoRev
    var due = 0
    for (var i = 0; i < todoModel.count; i++) {
      var r = todoModel.get(i)
      var st = root.dueState(r.due)
      if (!r.done && (st === "today" || st === "overdue")) due++
    }
    var parts = [due === 0 ? "Nothing due today" : due + (due === 1 ? " task" : " tasks") + " due today"]
    if (root.weather) parts.push(root.weather.temp + "\u00b0 and " + String(root.weather.label).toLowerCase())
    return parts.join("  \u00b7  ")
  }
  onBriefingChanged: if (!briefingTimer.running && root.briefingTyped.length > 0) root.briefingTyped = root.briefing

  readonly property var pages: [
    { label: "Home", icon: "" },
    { label: "Tasks", icon: "" },
    { label: "Stocks", icon: "\uf201" },
    { label: "Settings", icon: "\uf013" }
  ]

  // ---- shell contract ---------------------------------------------------------
  function open(payloadJson) {
    if (!win.visible) win.visible = true
    Hyprland.dispatch('hl.dsp.focus({ workspace = "1" })')
    Qt.callLater(function() { stage.forceActiveFocus() })
  }
  // Nothing to close any more: "hide" just goes back to the Home page.
  function close() { root.page = 0 }
  function toggle() { root.open("{}") }

  onOnScreenChanged: {
    root.announce()
    if (onScreen) {
      root.now = new Date()
      root.dash = Mock.build(root.now)
      root.refreshWeather(false)
      if (!root.live || Date.now() - root.leftAt > 60000) replay()
      Qt.callLater(function() { stage.forceActiveFocus() })
    } else {
      root.leftAt = Date.now()
      chat.clear()
    }
  }
  // Tell other plugins (the Discord overlay) when Jarvis is on screen, so
  // their floating widgets can stand aside. Memory-only, in $XDG_RUNTIME_DIR.
  FileView {
    id: onScreenFile
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/jarvis-onscreen"
    printErrors: false
  }
  function announce() { onScreenFile.setText(root.onScreen ? "1\n" : "0\n") }
  Timer { interval: 0; running: true; onTriggered: root.announce() }
  Component.onDestruction: onScreenFile.setText("0\n")

  function replay() {
    root.live = false
    root.briefingTyped = ""
    Qt.callLater(function() { root.live = true })
  }

  // ---- Govee lamps + air purifier (govee.py) -----------------------------------
  property var home: ({ lights: [], purifiers: [], cloud: "off", error: "" })
  function homeSend(c) { if (govee.running) govee.write(JSON.stringify(c) + "\n") }
  Process {
    id: govee
    command: ["setpriv", "--pdeathsig", "TERM", "python3", "-I",
      Qt.resolvedUrl("govee.py").toString().replace(/^(file|qs):\/\//, ""), "serve"]
    running: root.onScreen
    stdinEnabled: true
    // Settings can switch the purifier's cloud connection off.
    environment: ({ JARVIS_GOVEE_CLOUD: root.settings.goveeCloud === false ? "0" : "1" })
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var s = JSON.parse(line)
          if (s && s.type === "state") root.home = s
        } catch (e) {}
      }
    }
  }

  // ---- Weather (weather.py, Open-Meteo) ----------------------------------------
  property var weather: null
  property real weatherAt: 0
  Process {
    id: weatherProc
    command: ["python3", "-I", Qt.resolvedUrl("weather.py").toString().replace(/^(file|qs):\/\//, ""), "--cached"]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var w = JSON.parse(line)
          if (w && w.type === "weather") { root.weather = w; root.weatherAt = Date.now() }
        } catch (e) {}
      }
    }
  }
  function refreshWeather(force) {
    if (root.demo) { root.weather = root.demoWeather; return }
    if (weatherProc.running || root.settings.weather === false) return
    if (force || Date.now() - root.weatherAt > 10 * 60 * 1000) weatherProc.running = true
  }
  Timer {
    interval: 15 * 60 * 1000
    repeat: true
    running: root.onScreen
    onTriggered: root.refreshWeather(true)
  }

  // ---- Stocks (stocks.py, Yahoo Finance) ---------------------------------------
  property var watchlist: []
  property var quotes: ({})
  property bool stocksLive: false
  property int stocksEvery: 60
  property real stocksAt: 0
  property string stocksError: ""
  property string stockSel: ""
  property string stockRange: "1d"
  property var stockChart: null
  property string stockChartError: ""
  property var stocksFailed: []
  property string stockSearchError: ""
  property var stockResults: []
  property bool stockSearching: false
  property int searchId: 0
  property int chartId: 0
  property bool watchReady: false

  function stocksSend(c) { if (stocksProc.running) stocksProc.write(JSON.stringify(c) + "\n") }
  function sendWatch() { stocksSend({ cmd: "watch", symbols: root.watchlist }) }
  function requestChart() {
    if (!root.stockSel) return
    root.chartId++
    root.stockChartError = ""
    stocksSend({ cmd: "chart", symbol: root.stockSel, range: root.stockRange, id: root.chartId })
  }
  function searchStocks(q) {
    root.searchId++
    root.stockSearchError = ""
    if (!String(q).trim()) { root.stockResults = []; root.stockSearching = false; return }
    root.stockSearching = true
    stocksSend({ cmd: "search", q: q, id: root.searchId })
  }
  function addStock(s) {
    if (root.watchlist.indexOf(s) >= 0) return
    root.watchlist = root.watchlist.concat([s])
    saveWatchlist()
    sendWatch()
  }
  function removeStock(s) {
    root.watchlist = root.watchlist.filter(function(x) { return x !== s })
    saveWatchlist()
    sendWatch()
    if (root.stockSel === s) pickStock(root.watchlist.length ? root.watchlist[0] : "")
  }
  function pickStock(s) {
    root.stockSel = s
    root.stockChart = null
    requestChart()
  }
  function handleStocks(line) {
    var m
    try { m = JSON.parse(line) } catch (e) { return }
    if (m.type === "quotes") {
      var merged = {}
      for (var k in root.quotes) merged[k] = root.quotes[k]
      for (var s in m.quotes) merged[s] = m.quotes[s]
      root.quotes = merged
      root.stocksLive = m.live === true
      root.stocksEvery = m.every || 60
      root.stocksAt = m.at || 0
      root.stocksError = Object.keys(m.quotes).length === 0 && m.errors && m.errors.length ? "Can't reach Yahoo Finance right now" : ""
      root.stocksFailed = (m.errors || []).map(function(e) { return String(e).split(":")[0] })
    } else if (m.type === "search") {
      if (m.id !== root.searchId) return
      root.stockResults = m.results || []
      root.stockSearching = false
    } else if (m.type === "chart") {
      if (m.id !== root.chartId) return
      root.stockChart = m
    } else if (m.type === "error") {
      if (m.of === "chart" && m.id === root.chartId) root.stockChartError = "Couldn't load the chart: " + m.error
      if (m.of === "search" && m.id === root.searchId) { root.stockResults = []; root.stockSearching = false; root.stockSearchError = m.error }
    }
  }
  Process {
    id: stocksProc
    command: ["setpriv", "--pdeathsig", "TERM", "python3", "-I",
      Qt.resolvedUrl("stocks.py").toString().replace(/^(file|qs):\/\//, ""), "serve"]
    running: root.onScreen && root.watchReady && root.settings.stocks !== false
    stdinEnabled: true
    onRunningChanged: if (running) Qt.callLater(function() { root.sendWatch(); root.requestChart() })
    stdout: SplitParser { onRead: function(line) { root.handleStocks(line) } }
  }
  // Keep the open chart moving while the market is open.
  Timer {
    interval: root.stocksEvery * 1000
    repeat: true
    running: root.onScreen && root.page === 2 && root.stocksLive && (root.stockRange === "1d" || root.stockRange === "5d")
    onTriggered: root.requestChart()
  }

  FileView {
    id: stocksFile
    // Demo mode never reads or writes the real watchlist.
    path: root.demo ? "" : root.configDir + "/stocks.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var w = JSON.parse(text()).watchlist
        root.watchlist = Array.isArray(w) ? w.filter(function(s) { return /^[A-Za-z0-9.^=\-]{1,15}$/.test(s) }) : []
      } catch (e) { root.watchlist = [] }
      root.stockSel = root.watchlist.length ? root.watchlist[0] : ""
      root.watchReady = true
    }
    onLoadFailed: {
      root.watchlist = ["NVDA", "AAPL", "TSLA", "AMD", "SPY"]
      root.stockSel = "NVDA"
      root.watchReady = true
      root.saveWatchlist()
    }
  }
  function saveWatchlist() {
    if (!root.watchReady || root.demo) return
    stocksFile.setText(JSON.stringify({ watchlist: root.watchlist }, null, 2) + "\n")
  }

  // The Home stat card shows the real watchlist once quotes arrive.
  readonly property var stats: {
    root.todoRev
    screenTime.rev
    var s = Mock.stats(root.dash, root.doneCount, root.todoTotal)
    if (root.demo) return s
    var mins = screenTime.minutesToday()
    var avg = screenTime.averageBefore(7)
    s[0] = { key: "screen", title: "Screen time today", icon: "\uf017", tone: "accent", kind: "duration", value: mins,
             spark: screenTime.lastDays(7), lowerIsBetter: true, deltaUnit: "%", deltaLabel: "vs your average" }
    if (avg > 0) s[0].delta = Math.round((mins - avg) / avg * 100)
    var doneToday = root.doneOn(root.isoDay(0)), doneYday = root.doneOn(root.isoDay(-1))
    var dueToday = root.todayItems.length
    var spark = []
    for (var k = 6; k >= 0; k--) spark.push(root.doneOn(root.isoDay(-k)))
    s[1] = { key: "tasks", title: "Done today", icon: "\uf0ae", tone: "green", kind: "fraction", value: doneToday,
             total: doneToday + dueToday, delta: doneToday - doneYday, deltaLabel: "vs yesterday", spark: spark }
    s[2] = { key: "inbox", title: "Gmail", icon: "\uf0e0", tone: "yellow", kind: "text", text: "Not linked", value: 0, spark: [] }
    var rows = [], sum = 0
    for (var i = 0; i < root.watchlist.length; i++) {
      var q = root.quotes[root.watchlist[i]]
      if (q && q.price !== null) { rows.push({ sym: q.symbol, price: q.price, change: q.pct }); sum += q.pct }
    }
    if (rows.length) {
      var first = root.quotes[root.watchlist[0]]
      var mean = sum / rows.length
      s[3] = { key: "stocks", title: "Watchlist today", icon: "", tone: mean >= 0 ? "green" : "red", kind: "percent",
               value: mean, ticker: rows, spark: first && first.spark && first.spark.length > 1 ? first.spark : s[3].spark }
    }
    return s
  }

  // ---- Screen time (real, from the focused window) -------------------------------
  ScreenTime { id: screenTime }

  // ---- CPU / RAM / disk, every 3s while on screen ---------------------------------
  property var sys: ({ cpu: 0, ram: 0, disk: 0 })
  property var cpuPrev: null
  Process {
    id: sysProc
    command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -P / | tail -1"]
    property var lines: []
    stdout: SplitParser { onRead: function(l) { sysProc.lines.push(l) } }
    onRunningChanged: if (!running && lines.length) { root.readSys(lines); lines = [] }
  }
  function readSys(lines) {
    var cpu = root.sys.cpu, ram = root.sys.ram, disk = root.sys.disk, total = 0, avail = 0
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i]
      if (l.indexOf("cpu ") === 0) {
        var n = l.trim().split(/\s+/).slice(1).map(Number)
        var idle = n[3] + (n[4] || 0), all = n.reduce(function(a, b) { return a + b }, 0)
        if (root.cpuPrev) {
          var dAll = all - root.cpuPrev.all, dIdle = idle - root.cpuPrev.idle
          if (dAll > 0) cpu = Math.round(100 * (1 - dIdle / dAll))
        }
        root.cpuPrev = { all: all, idle: idle }
      } else if (l.indexOf("MemTotal:") === 0) total = parseInt(l.split(/\s+/)[1])
      else if (l.indexOf("MemAvailable:") === 0) avail = parseInt(l.split(/\s+/)[1])
      else {
        var m = /(\d+)%/.exec(l)
        if (m) disk = parseInt(m[1])
      }
    }
    if (total > 0) ram = Math.round(100 * (1 - avail / total))
    root.sys = { cpu: cpu, ram: ram, disk: disk }
  }
  Timer { interval: 3000; repeat: true; triggeredOnStart: true; running: root.onScreen; onTriggered: if (!sysProc.running) sysProc.running = true }

  // ---- Discord ------------------------------------------------------------------
  // Pings and DMs: Discord's desktop notifications, read from Omarchy's
  // notification store (live + history). Voice: the voice bridge from the
  // ynnad.discord-stream plugin (Discord's local RPC), run while on screen.
  readonly property string notifDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  property var discordPings: []
  property var discordVoice: null
  function relTime(ts) {
    var s = Math.max(0, Date.now() / 1000 - ts)
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    return Math.floor(s / 86400) + "d"
  }
  function readPings() {
    var rows = []
    try { var live = JSON.parse(notifLive.text()); if (Array.isArray(live)) rows = rows.concat(live) } catch (e) {}
    try { var hist = JSON.parse(notifHistory.text()); if (Array.isArray(hist)) rows = rows.concat(hist) } catch (e) {}
    var seen = {}, out = [], dayAgo = Date.now() / 1000 - 86400
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (!r || !/discord|vesktop|webcord/i.test(String(r.app || "") + " " + String(r.source || ""))) continue
      var ts = Number(r.ts) || 0
      if (ts < dayAgo) continue
      var key = String(r.key || r.originalId || "") + ":" + ts
      if (seen[key]) continue
      seen[key] = true
      // Discord titles look like "Name (#channel, Server)" for servers, "Name" for DMs.
      var sum = String(r.summary || "").slice(0, 120)
      var m = /^(.*?) \((#[^,]+), (.+)\)$/.exec(sum)
      out.push({ from: m ? m[1] : sum, where: m ? m[2] + " \u00b7 " + m[3] : "", dm: !m,
                 text: String(r.rawBody || r.body || "").replace(/<[^>]*>/g, "").slice(0, 200), ts: ts })
    }
    out.sort(function(a, b) { return b.ts - a.ts })
    root.discordPings = out.slice(0, 20)
  }
  FileView { id: notifHistory; path: root.notifDir + "/history.json"; watchChanges: true; printErrors: false; onFileChanged: reload(); onLoaded: root.readPings() }
  FileView { id: notifLive; path: root.notifDir + "/live.json"; watchChanges: true; printErrors: false; onFileChanged: reload(); onLoaded: root.readPings() }
  Timer { interval: 30000; repeat: true; running: root.onScreen; onTriggered: root.readPings() }  // keeps "5m ago" fresh

  // Live voice state, shared by the ynnad.discord-stream overlay (which holds
  // the one Discord RPC connection) through a file in $XDG_RUNTIME_DIR.
  FileView {
    id: discordVoiceFile
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/discord-voice.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var v = JSON.parse(text())
        if (!v.connected || !v.channel) { root.discordVoice = null; return }
        var mem = (v.members || []).map(function(x) { return { name: x.name, speaking: x.speaking === true, avatar: x.avatar || "", muted: x.muted === true } })
        root.discordVoice = { channel: v.channel, server: "", members: mem }
      } catch (e) {}
    }
    onLoadFailed: root.discordVoice = null
  }

  // ---- Coach ------------------------------------------------------------------
  Coach {
    id: doomCoach
    demo: root.demo
    onOpenRequested: root.open("{}")
  }
  // `omarchy-shell shell call ynnad.jarvis setPage 2` opens a page from scripts.
  function setPage(p) { var n = parseInt(p); if (n >= 0 && n < root.pages.length) root.page = n; return String(root.page) }
  function testCoach() { doomCoach.testTrigger(); return "ok" }
  function testCoachClear() { doomCoach.testClear(); return "ok" }
  // Save a picture of the dashboard (used by the offscreen style previews).
  function snapshot(path) { stage.grabToImage(function(r) { r.saveToFile(path) }); return "ok" }

  // ---- To-dos (saved to ~/.local/state/jarvis/todos.json) ----------------------
  // Roles: title, done, due ("yyyy-MM-dd" or ""), created, doneAt (ms).
  ListModel { id: todoModel }
  Component.onCompleted: if (root.demo) {
    var d = root.dash.todos
    for (var i = 0; i < d.length; i++)
      todoModel.append({ title: d[i].title, done: d[i].done, due: d[i].due === "Today" ? root.isoDay(0) : d[i].due ? root.isoDay(3) : "",
                         created: 0, doneAt: d[i].done ? Date.now() : 0 })
    root.todosReady = true
    root.weather = root.demoWeather
    root.watchlist = ["NVDA", "AAPL", "TSLA", "AMD", "SPY"]
    root.stockSel = "NVDA"
    root.watchReady = true
    root.recount()
  }
  property bool todosReady: false
  property int todoRev: 0
  FileView {
    id: todosFile
    path: root.demo ? "" : root.stateDir + "/todos.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var a = JSON.parse(text())
        for (var i = 0; i < a.length && i < 1000; i++) {
          if (!a[i] || typeof a[i].title !== "string") continue
          todoModel.append({ title: a[i].title.slice(0, 200), done: a[i].done === true, due: /^\d{4}-\d{2}-\d{2}$/.test(String(a[i].due || "")) ? String(a[i].due) : "",
                             created: Number(a[i].created) || 0, doneAt: Number(a[i].doneAt) || 0 })
        }
      } catch (e) { console.warn("jarvis: can't read todos.json: " + e) }
      root.todosReady = true
      root.recount()
    }
    onLoadFailed: { root.todosReady = true; root.recount() }
  }
  function saveTodos() {
    root.recount()
    if (!root.todosReady || root.demo) return
    var a = []
    for (var i = 0; i < todoModel.count; i++) {
      var r = todoModel.get(i)
      a.push({ title: r.title, done: r.done, due: r.due, created: r.created, doneAt: r.doneAt })
    }
    todosFile.setText(JSON.stringify(a, null, 1) + "\n")
  }
  function recount() {
    root.todoRev++
    var c = 0
    for (var i = 0; i < todoModel.count; i++) if (todoModel.get(i).done) c++
    root.doneCount = c
    root.todoTotal = todoModel.count
  }
  function demoReply(q) {
    var s = String(q).toLowerCase()
    var tail = "\n\n(Answered from the data on this computer: Claude is switched off in Settings.)"
    if (/screen|time|hours|app/.test(s)) {
      var top = screenTime.topApps(3).map(function(a) { return a.name + " " + Math.round(a.minutes) + "m" })
      return "Screen time today: " + Math.round(screenTime.minutesToday()) + " min" + (top.length ? ", mostly " + top.join(", ") : "") + "." + tail
    }
    var open = root.todayItems.map(function(t) { return t.title })
    return (open.length ? "Due today: " + open.join("; ") + "." : "Nothing's due today.") +
      (root.weather ? " It's " + root.weather.temp + "\u00b0 and " + String(root.weather.label).toLowerCase() + "." : "") +
      tail
  }
  // What Claude is told about the dashboard with each question. Kept short:
  // tasks, screen time, weather, the watchlist and the exercise coach.
  function claudeContext() {
    var L = []
    L.push("Name: " + root.userName + ". Now: " + Qt.formatDateTime(new Date(), "dddd d MMMM yyyy, " + theme.timeFmt) + ".")
    var open = [], doneToday = 0
    for (var i = 0; i < todoModel.count; i++) {
      var r = todoModel.get(i)
      if (!r.done) open.push(r.title + (r.due ? " (" + root.dueLabel(r.due).toLowerCase() + ")" : ""))
      else if (r.doneAt && Qt.formatDate(new Date(r.doneAt), "yyyy-MM-dd") === root.isoDay(0)) doneToday++
    }
    L.push("Open tasks: " + (open.length ? open.slice(0, 15).join("; ") : "none") + ". Finished today: " + doneToday + ".")
    if (!root.demo) {
      var top = screenTime.topApps(5).map(function(a) { return a.name + " " + Math.round(a.minutes) + "m" })
      L.push("Screen time today: " + Math.round(screenTime.minutesToday()) + " min" + (top.length ? " (" + top.join(", ") + ")" : "") + ".")
    }
    if (root.weather) L.push("Weather: " + root.weather.temp + "\u00b0" + (root.weather.unit || "") + ", " + root.weather.label +
                             ", high " + root.weather.high + ", low " + root.weather.low + (root.weather.place ? ", in " + root.weather.place : "") + ".")
    var q = root.watchlist.map(function(s) { var x = root.quotes[s]; return x && x.price != null ? s + " " + Number(x.price).toFixed(2) + " (" + (x.pct >= 0 ? "+" : "") + Number(x.pct || 0).toFixed(2) + "% today)" : null })
      .filter(function(x) { return x })
    if (q.length) L.push("Watchlist: " + q.join(", ") + ".")
    if (doomCoach.challenge) L.push("Exercise coach: waiting on " + doomCoach.challenge.reps + " " + doomCoach.challenge.name + ".")
    L.push("Not connected: email, calendar.")
    return L.join("\n")
  }
  function openTodoTitles() {
    var out = []
    for (var i = 0; i < todoModel.count; i++) if (!todoModel.get(i).done) out.push(todoModel.get(i).title)
    return out
  }
  function todoAdd(title, due) { todoModel.insert(0, { title: title, done: false, due: due || "", created: Date.now(), doneAt: 0 }); saveTodos() }
  function todoToggle(i) { var d = !todoModel.get(i).done; todoModel.setProperty(i, "done", d); todoModel.setProperty(i, "doneAt", d ? Date.now() : 0); saveTodos() }
  function todoRemove(i) { todoModel.remove(i); saveTodos() }
  function todoRename(i, t) { todoModel.setProperty(i, "title", t); saveTodos() }
  function todoRedate(i, iso) { todoModel.setProperty(i, "due", iso); saveTodos() }
  function todoClearDone() { for (var i = todoModel.count - 1; i >= 0; i--) if (todoModel.get(i).done) todoModel.remove(i); saveTodos() }

  readonly property var todayItems: {
    root.todoRev
    var out = []
    for (var i = 0; i < todoModel.count; i++) {
      var r = todoModel.get(i)
      var st = root.dueState(r.due)
      if (!r.done && (st === "today" || st === "overdue"))
        out.push({ start: "", end: "", title: r.title, kind: "task", tone: st === "overdue" ? "red" : "yellow", where: st === "overdue" ? "Overdue" : "Due today", who: [] })
    }
    return out
  }
  function doneOn(iso) {
    var c = 0
    for (var i = 0; i < todoModel.count; i++) {
      var r = todoModel.get(i)
      if (r.done && r.doneAt && Qt.formatDate(new Date(r.doneAt), "yyyy-MM-dd") === iso) c++
    }
    return c
  }

  function isoDay(offset) { var d = new Date(); d.setDate(d.getDate() + (offset || 0)); return Qt.formatDate(d, "yyyy-MM-dd") }
  function dueState(iso) {
    if (!iso) return ""
    var today = isoDay(0)
    return iso < today ? "overdue" : iso === today ? "today" : "soon"
  }
  function dueLabel(iso) {
    if (!iso) return ""
    if (iso === isoDay(0)) return "Today"
    if (iso === isoDay(1)) return "Tomorrow"
    if (iso < isoDay(0)) return "Overdue"
    var d = new Date(iso + "T12:00:00")
    return iso <= isoDay(6) ? Qt.formatDate(d, "dddd") : Qt.formatDate(d, "MMM d")
  }

  // ---- clock + briefing ---------------------------------------------------------
  Theme {
    id: theme
    // Scale with the window. When width is the limit (a half-width tile),
    // shrink more gently so text stays readable; height can't give, or cards
    // would overflow on short screens.
    readonly property real wfit: win.width / 1920
    readonly property real hfit: win.height / 1080
    u: Math.max(0.6, Math.min(wfit < 1 ? Math.pow(wfit, 0.55) : wfit, hfit))
    clock24: root.settings.clock24 !== false
  }
  Timer {
    interval: 1000
    repeat: true
    running: root.onScreen
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }
  Timer {
    id: briefingTimer
    interval: 14
    repeat: true
    running: root.live && root.onScreen && root.briefingTyped.length < root.briefing.length
    onTriggered: root.briefingTyped = root.briefing.slice(0, root.briefingTyped.length + 2)
  }

  // ---- the window -----------------------------------------------------------------
  FloatingWindow {
    id: win
    title: "Jarvis"
    visible: true
    color: theme.base
    implicitWidth: 1600
    implicitHeight: 900

    FocusScope {
      id: stage
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (event.key === Qt.Key_Escape) {
          root.page = 0
          event.accepted = true
        } else if (event.text === "/") {
          chat.focusInput()
          event.accepted = true
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
          root.page = event.key - Qt.Key_1
          event.accepted = true
        } else if (event.key === Qt.Key_T) {
          if (root.page === 1) tasksPage.focusInput()
          else { root.page = 0; todoCard.focusInput() }
          event.accepted = true
        } else if (event.key === Qt.Key_V) {
          if (root.page !== 0) root.page = 0
          chat.toggleVoice()
          event.accepted = true
        } else if (event.key === Qt.Key_S) {
          root.page = 2
          Qt.callLater(function() { stocksPage.focusSearch() })
          event.accepted = true
        }
      }

      Aurora {
        anchors.fill: parent
        t: theme
        running: root.onScreen
        opacity: root.live ? 1 : 0
        scale: root.live ? 1 : 1.03
        Behavior on opacity { NumberAnimation { duration: Style.duration(root.live ? 220 : 150); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Style.duration(420); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
      }

      // Clicking empty space drops focus out of any text field.
      MouseArea {
        anchors.fill: parent
        onClicked: stage.forceActiveFocus()
      }

      NavRail {
        id: rail
        t: theme
        z: 20            // above the cards, so its hover labels aren't hidden
        shown: root.live
        x: theme.px(28)
        anchors.verticalCenter: parent.verticalCenter
        items: root.pages
        current: root.page
        onPicked: function(i) { root.page = i }
      }

      Item {
        id: pageArea
        x: rail.x + rail.width + theme.px(28)
        y: theme.px(30)
        width: parent.width - x - theme.px(36)
        height: parent.height - y - theme.px(26)

        readonly property real gap: theme.px(18)
        readonly property real headerH: theme.px(96)
        readonly property real kpiH: theme.px(132)
        readonly property real chatH: theme.px(58)
        readonly property real rest: height - headerH - kpiH - chatH - gap * 4
        readonly property real mainH: Math.round(rest * 0.5)
        readonly property real lowerH: rest - mainH
        readonly property real pageY: headerH + gap
        readonly property real pageH: height - headerH - chatH - gap * 2

        // ---- header (every page) ----
        Item {
          id: header
          width: parent.width
          height: pageArea.headerH
          opacity: root.live ? 1 : 0
          property real rise: root.live ? 0 : theme.px(14)
          transform: Translate { y: header.rise }
          Behavior on opacity { NumberAnimation { duration: Style.duration(root.live ? 260 : 120); easing.type: Easing.OutCubic } }
          Behavior on rise { NumberAnimation { duration: Style.duration(320); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

          JText {
            id: hello
            t: theme
            text: root.dash.greeting + ", " + root.userName
            size: 24
            font.weight: Font.DemiBold
            font.letterSpacing: -0.4
          }
          JText {
            id: dateLine
            t: theme
            anchors.top: hello.bottom
            anchors.topMargin: theme.px(4)
            text: Qt.formatDate(root.now, "dddd, d MMMM") + "  ·  " + (root.page === 1 ? "your tasks" : root.page === 2 ? "markets" : root.page === 3 ? "settings" : "here's what's happening today")
            size: 12
            color: theme.textDim
          }
          Row {
            id: briefingRow
            anchors.top: dateLine.bottom
            anchors.topMargin: theme.px(12)
            spacing: theme.px(10)
            opacity: challengeBanner.active ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
            Rectangle {
              visible: false
              height: theme.px(22)
              width: 0
              radius: height / 2
              color: theme.alpha(theme.accent, 0.16)
              border.width: 1
              border.color: theme.alpha(theme.accent, 0.4)
              JText { id: tag; t: theme; anchors.centerIn: parent; text: String.fromCodePoint(0xF0674) + " JARVIS"; size: 9.5; font.weight: Font.Bold; color: theme.accent; font.letterSpacing: 1 }
            }
            JText {
              t: theme
              height: theme.px(22)
              width: (weatherBlock.visible ? weatherBlock.x : pageArea.width * 0.75) - theme.px(150)
              color: theme.textDim
              text: root.briefingTyped + (doomCoach.meter >= 0.5 && !doomCoach.challenge ? "   ·   scroll meter " + Math.round(doomCoach.score / 60) + "/" + doomCoach.triggerMinutes + " min" : "")
              size: 12.5
            }
          }

          ChallengeBanner {
            id: challengeBanner
            t: theme
            coach: doomCoach
            anchors.top: dateLine.bottom
            anchors.topMargin: theme.px(8)
            width: Math.min(theme.px(900), (weatherBlock.visible ? weatherBlock.x : pageArea.width * 0.75) - theme.px(40))
          }

          Item {
            id: weatherBlock
            visible: !!root.weather
            anchors.right: clockCol.left
            anchors.rightMargin: theme.px(28)
            anchors.top: parent.top
            width: theme.px(330)
            height: parent.height

            Rectangle {
              anchors.right: parent.right
              anchors.rightMargin: -theme.px(14)
              y: theme.px(6)
              width: 1
              height: theme.px(70)
              color: theme.inkA(0.08)
            }
            JText {
              id: wIcon
              t: theme
              y: theme.px(2)
              text: root.weather ? root.weather.icon : ""
              size: 24
              color: theme.textDim
            }
            JText {
              id: wTemp
              t: theme
              anchors.left: wIcon.right
              anchors.leftMargin: theme.px(12)
              anchors.verticalCenter: wIcon.verticalCenter
              text: root.weather ? root.weather.temp + "°" : ""
              size: 26
              font.weight: Font.Medium
              font.letterSpacing: -0.6
            }
            Column {
              anchors.left: wTemp.right
              anchors.leftMargin: theme.px(12)
              anchors.right: parent.right
              anchors.verticalCenter: wIcon.verticalCenter
              spacing: theme.px(2)
              JText {
                t: theme
                width: parent.width
                text: root.weather ? root.weather.label + "  ·  H " + root.weather.high + "°  L " + root.weather.low + "°" : ""
                size: 11
              }
              JText {
                t: theme
                width: parent.width
                text: root.weather ? root.weather.place + "  ·  feels " + root.weather.feels + "°" + (root.weather.rain > 0 ? "  ·  " + root.weather.rain + "% rain" : "") : ""
                size: 9.5
                color: theme.textFaint
              }
            }
            Row {
              anchors.left: parent.left
              anchors.top: wIcon.bottom
              anchors.topMargin: theme.px(8)
              spacing: theme.px(14)
              Repeater {
                model: root.weather ? root.weather.hours.slice(0, 5) : []
                Row {
                  required property var modelData
                  required property int index
                  spacing: theme.px(4)
                  opacity: root.live ? 1 : 0
                  Behavior on opacity { SequentialAnimation { PauseAnimation { duration: Style.duration(root.live ? 300 + index * 40 : 0) } NumberAnimation { duration: Style.duration(200) } } }
                  JText { t: theme; text: modelData.hour !== undefined ? theme.hourLabel(modelData.hour) : modelData.label; size: 9.5; color: theme.textFaint }
                  JText { t: theme; text: modelData.icon; size: 10; color: theme.textDim }
                  JText { t: theme; text: modelData.temp + "°"; size: 10 }
                }
              }
            }
          }

          Column {
            id: clockCol
            anchors.right: parent.right
            anchors.top: parent.top
            JText {
              anchors.right: parent.right
              t: theme
              text: Qt.formatTime(root.now, root.settings.clock24 === false ? "h:mm AP" : "hh:mm")
              size: 30
              font.weight: Font.Medium
              font.letterSpacing: -0.6
            }
            Row {
              anchors.right: parent.right
              spacing: theme.px(6)
              JText { visible: root.settings.seconds !== false; t: theme; text: Qt.formatTime(root.now, "ss") + "s"; size: 11; color: theme.textFaint }
              JText { t: theme; text: "·  " + Qt.formatDate(root.now, "yyyy") + "  ·  week " + weekNo(root.now); size: 11; color: theme.textFaint
                function weekNo(d) {
                  var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
                  var day = t.getUTCDay() || 7
                  t.setUTCDate(t.getUTCDate() + 4 - day)
                  var y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
                  return Math.ceil(((t - y) / 86400000 + 1) / 7)
                }
              }
            }
          }
        }

        // ---- Home page ----

        Row {
          id: kpis
          y: pageArea.pageY
          width: parent.width
          height: pageArea.kpiH
          spacing: pageArea.gap
          readonly property real cardW: (width - spacing * 3) / 4
          Repeater {
            model: 4
            StatCard {
              required property int index
              readonly property var modelData: root.stats[index]
              t: theme
              model: modelData
              width: kpis.cardW
              height: kpis.height
              shown: root.homeShown
              order: 1 + index
              onClicked: { if (modelData.key === "tasks") root.page = 1; else if (modelData.key === "stocks") root.page = 2 }
            }
          }
        }

        ScreenTimeCard {
          id: chart
          t: theme
          y: kpis.y + kpis.height + pageArea.gap
          width: Math.round((pageArea.width - pageArea.gap) * 0.66)
          height: pageArea.mainH
          chartData: root.demo ? root.dash.chart : screenTime.chart()
          range: root.range
          shown: root.homeShown
          order: 5
          onRangePicked: function(r) { root.range = r }
        }
        TodayCard {
          t: theme
          x: chart.width + pageArea.gap
          y: chart.y
          width: pageArea.width - x
          height: pageArea.mainH
          items: root.demo ? root.dash.today : root.todayItems
          calendarNote: root.demo ? "" : "Calendar isn't linked yet. Tasks due today show here."
          shown: root.homeShown
          order: 6
        }

        Item {
          id: lower
          y: chart.y + chart.height + pageArea.gap
          width: parent.width
          height: pageArea.lowerH
          readonly property var weights: [1.2, 1.0, 1.0, 1.05, 0.75]
          readonly property real unit: (width - pageArea.gap * 4) / (1.2 + 1.0 + 1.0 + 1.05 + 0.75)

          InboxCard {
            id: inbox
            t: theme
            width: lower.unit * lower.weights[0]
            height: lower.height
            mails: root.demo ? root.dash.inbox : []
            emptyText: "Gmail isn't linked yet.\nImportant email will show up here."
            shown: root.homeShown
            order: 7
          }
          DiscordCard {
            id: discordCard
            t: theme
            x: inbox.x + inbox.width + pageArea.gap
            width: lower.unit * lower.weights[1]
            height: lower.height
            discord: root.demo ? root.dash.discord : ({ voice: root.discordVoice, mentions: root.discordPings.map(function(p) {
              return { from: p.from, where: p.where, dm: p.dm, text: p.text, time: root.relTime(p.ts) } }) })
            shown: root.homeShown
            order: 8
          }
          TodoCard {
            id: todoCard
            t: theme
            x: discordCard.x + discordCard.width + pageArea.gap
            width: lower.unit * lower.weights[2]
            height: lower.height
            todos: todoModel
            dueLabel: function(iso) { return root.dueLabel(iso) }
            dueState: function(iso) { return root.dueState(iso) }
            shown: root.homeShown
            order: 9
            action: "All tasks"
            onActionClicked: root.page = 1
            onToggled: function(i) { root.todoToggle(i) }
            onAdded: function(text) { root.todoAdd(text, root.isoDay(0)) }
            onRemoved: function(i) { root.todoRemove(i) }
          }
          HomeCard {
            id: homeCard
            t: theme
            x: todoCard.x + todoCard.width + pageArea.gap
            width: lower.unit * lower.weights[3]
            height: lower.height
            home: root.demo ? root.demoHome : root.home
            send: function(c) { root.homeSend(c) }
            shown: root.homeShown
            order: 10
          }
          SystemCard {
            t: theme
            x: homeCard.x + homeCard.width + pageArea.gap
            width: lower.width - x
            height: lower.height
            system: root.demo ? root.dash.system : ({ cpu: root.sys.cpu, ram: root.sys.ram, disk: root.sys.disk, mouse: null })
            shown: root.homeShown
            order: 11
          }
        }

        // ---- Tasks page ----
        TasksPage {
          id: tasksPage
          t: theme
          y: pageArea.pageY
          width: parent.width
          height: pageArea.pageH
          shown: root.live && root.page === 1
          todos: todoModel
          coachSets: doomCoach.doneToday
          dueLabel: function(iso) { return root.dueLabel(iso) }
          dueState: function(iso) { return root.dueState(iso) }
          onAdded: function(title, due) { root.todoAdd(title, due) }
          onToggled: function(i) { root.todoToggle(i) }
          onRemoved: function(i) { root.todoRemove(i) }
          onRenamed: function(i, title) { root.todoRename(i, title) }
          onRedated: function(i, due) { root.todoRedate(i, due) }
          onClearDone: root.todoClearDone()
        }

        // ---- Stocks page ----
        StocksPage {
          id: stocksPage
          t: theme
          y: pageArea.pageY
          width: parent.width
          height: pageArea.pageH
          shown: root.live && root.page === 2
          watchlist: root.watchlist
          quotes: root.quotes
          failed: root.stocksFailed
          selected: root.stockSel
          range: root.stockRange
          chart: root.stockChart
          chartError: root.stockChartError
          results: root.stockResults
          searching: root.stockSearching
          searchError: root.stockSearchError
          live: root.stocksLive
          every: root.stocksEvery
          lastAt: root.stocksAt
          error: root.stocksError
          onSearchFor: function(q) { root.searchStocks(q) }
          onAdd: function(s) { root.addStock(s) }
          onRemove: function(s) { root.removeStock(s) }
          onPick: function(s) { root.pickStock(s) }
          onRangePicked: function(r) { root.stockRange = r; root.stockChart = null; root.requestChart() }
        }

        // ---- Settings page ----
        SettingsPage {
          id: settingsPage
          t: theme
          y: pageArea.pageY
          width: parent.width
          height: pageArea.pageH
          shown: root.live && root.page === 3
          // Demo mode never shows the real settings (your name, for one).
          settings: root.demo ? ({}) : root.settings
          coach: doomCoach
          defaultName: root.defaultName
          onSetSetting: function(k, v) { root.setSetting(k, v) }
          onEraseData: root.eraseData()
        }

        ChatBar {
          id: chat
          t: theme
          z: 5
          y: pageArea.height - pageArea.chatH
          width: parent.width
          height: pageArea.chatH
          shown: root.live
          order: 12
          replyFor: function(q) { return root.demoReply(q) }
          contextFor: function() { return root.claudeContext() }
          claudeOn: root.settings.claude !== false
          demo: root.demo
          workDir: root.stateDir
          onEscaped: stage.forceActiveFocus()
        }
      }
    }
  }
}
