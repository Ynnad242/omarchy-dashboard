import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The doomscroll coach. Every few seconds it looks at the focused window and
// sorts it into slop (YouTube, TikTok, Reddit, ...), games, productive work,
// or neutral. Slop time fills a meter; games and work drain it twice as
// fast. A full meter sends one notification and sets a small upper-body
// exercise, which sits on the dashboard until you mark it done. Nothing is
// ever locked or blocked.
//
// Settings: ~/.config/jarvis/coach.json (any key below can be overridden).
// State:    ~/.local/state/jarvis/coach.json (survives shell restarts).
Item {
  id: coach

  // ---- settings ------------------------------------------------------------
  property bool enabled: true
  // Demo mode: no tracking, and the real state file is never read or written.
  property bool demo: false
  property int triggerMinutes: 15      // slop minutes before a challenge
  property int remindMinutes: 15       // more slop minutes before one reminder
  property int idleSeconds: 300        // no input this long (and no video playing) pauses the meter
  property var slopSites: [
    { name: "YouTube", match: "youtube" },
    { name: "TikTok", match: "tiktok" },
    { name: "Instagram", match: "instagram" },
    { name: "Reddit", match: "reddit" },
    { name: "X", match: "( / x( - |$)|x\\.com|twitter)" },
    { name: "Facebook", match: "facebook" },
    { name: "Twitch", match: "twitch" },
    { name: "Snapchat", match: "snapchat" }
  ]
  // Titles that are fine even on a slop site.
  property var allowTitles: ["tutorial", "lecture", "course", "how to", "documentation", "explained", "walkthrough"]
  property var productiveApps: ["code", "codium", "cursor", "zed", "ghostty", "alacritty", "kitty", "foot", "obsidian",
    "libreoffice", "hubless", "com.anthropic.claude", "jetbrains", "gimp", "inkscape", "blender", "kdenlive", "typora"]
  property var gameApps: ["steam_app_", "gamescope", "lutris", "heroic", "minecraft", "retroarch", "prismlauncher"]
  property var exercises: [
    { name: "Push-ups", lo: 10, hi: 20, unit: "push-ups", tip: "Chest to the floor, body in one straight line." },
    { name: "Dumbbell curls", lo: 10, hi: 15, unit: "curls each arm", tip: "Elbows pinned to your sides, slow on the way down." },
    { name: "Hammer curls", lo: 10, hi: 15, unit: "hammer curls each arm", tip: "Thumbs up, no swinging." },
    { name: "Pull-ups", lo: 1, hi: 5, unit: "pull-ups", tip: "Full hang at the bottom. Every rep counts." },
    { name: "Shoulder press", lo: 8, hi: 12, unit: "dumbbell shoulder presses", tip: "Press straight up, don't arch your back." },
    { name: "Dumbbell rows", lo: 8, hi: 12, unit: "rows each arm", tip: "Pull to your hip, squeeze the shoulder blade." },
    { name: "Lateral raises", lo: 10, hi: 15, unit: "lateral raises", tip: "Light weight, lift to shoulder height." },
    { name: "Tricep extensions", lo: 10, hi: 15, unit: "overhead tricep extensions", tip: "Elbows pointing up, lower behind your head." },
    { name: "Diamond push-ups", lo: 6, hi: 12, unit: "diamond push-ups", tip: "Hands together under your chest." },
    { name: "Plank", lo: 30, hi: 60, unit: "second plank", tip: "Squeeze everything, breathe." }
  ]

  // ---- live state ----------------------------------------------------------
  property real score: 0               // seconds on the meter
  property real slopMinutes: 0         // slop time since the last challenge, for the message
  property string lastSite: ""
  property var challenge: null         // { name, reps, unit, tip, site, minutes, at, swapped }
  property real sinceReminder: 0
  property bool reminded: false
  property int doneToday: 0
  property string doneDay: ""
  property string lastExercise: ""
  property string kind: "neutral"      // what the focused window is right now
  property string site: ""
  readonly property real meter: Math.min(1, score / Math.max(60, triggerMinutes * 60))

  signal openRequested()

  // The raw settings file, so the Settings page can change one key and keep
  // the rest (custom site lists, exercises) as they are.
  property var config: ({})
  function setOption(key, value) {
    var c = {}
    for (var k in coach.config) c[k] = coach.config[k]
    c[key] = value
    coach.config = c
    coach[key] = value
    configFile.setText(JSON.stringify(c, null, 2) + "\n")
  }

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/jarvis"
  readonly property string configDir: Quickshell.env("HOME") + "/.config/jarvis"

  function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }

  function classify(appId, title) {
    var a = String(appId || "").toLowerCase()
    var t = String(title || "").toLowerCase()
    for (var g = 0; g < gameApps.length; g++) if (a.indexOf(gameApps[g]) >= 0) return { kind: "game", site: "" }
    for (var p = 0; p < productiveApps.length; p++) if (a.indexOf(productiveApps[p]) >= 0) return { kind: "productive", site: "" }
    for (var s = 0; s < slopSites.length; s++) {
      var re
      try { re = new RegExp(slopSites[s].match, "i") } catch (e) { continue }
      if (re.test(t)) {
        for (var k = 0; k < allowTitles.length; k++) if (t.indexOf(String(allowTitles[k]).toLowerCase()) >= 0) return { kind: "neutral", site: "" }
        return { kind: "slop", site: slopSites[s].name }
      }
    }
    return { kind: "neutral", site: "" }
  }

  function tick(dt) {
    if (doneDay !== today()) { doneDay = today(); doneToday = 0 }
    var top = ToplevelManager.activeToplevel
    var c = top ? classify(top.appId, top.title) : { kind: "neutral", site: "" }
    kind = c.kind
    site = c.site
    if (!enabled || idle.isIdle) return

    if (c.kind === "slop") {
      lastSite = c.site
      slopMinutes += dt / 60
      if (challenge) {
        sinceReminder += dt
        if (!reminded && sinceReminder >= remindMinutes * 60) {
          reminded = true
          notify("Still owe you: " + challenge.reps + " " + challenge.unit,
                 "Another " + remindMinutes + " min on " + c.site + ". Knock them out, then mark it done in Jarvis.")
        }
      } else {
        score += dt
        if (score >= triggerMinutes * 60) trigger()
      }
    } else if (c.kind === "game" || c.kind === "productive") {
      score = Math.max(0, score - dt * 2)
      if (score === 0) slopMinutes = 0
    }
    saveSoon()
  }

  function pickExercise(avoid) {
    var pool = []
    for (var i = 0; i < exercises.length; i++) if (exercises[i].name !== avoid) pool.push(exercises[i])
    if (!pool.length) pool = exercises
    var e = pool[Math.floor(Math.random() * pool.length)]
    var reps = e.lo + Math.round(Math.random() * (e.hi - e.lo))
    // Round bigger counts to a tidy number.
    if (e.unit.indexOf("second") >= 0) reps = Math.round(reps / 15) * 15
    else if (reps >= 12) reps = Math.round(reps / 5) * 5
    return { name: e.name, reps: Math.max(e.lo, reps), unit: e.unit, tip: e.tip || "" }
  }

  function trigger() {
    var e = pickExercise(lastExercise)
    lastExercise = e.name
    e.site = lastSite || "your feed"
    e.minutes = Math.round(slopMinutes)
    e.at = Date.now()
    e.swapped = false
    challenge = e
    score = 0
    sinceReminder = 0
    reminded = false
    notify("Time to move: " + e.reps + " " + e.unit,
           e.minutes + " min on " + e.site + ". Quick set, then mark it done in Jarvis.")
    saveNow()
  }

  function complete() {
    if (!challenge) return
    challenge = null
    closeNotification()
    slopMinutes = 0
    doneToday++
    doneDay = today()
    saveNow()
  }

  // One swap per challenge, so it's a choice, not a way out.
  function swap() {
    if (!challenge || challenge.swapped) return
    var e = pickExercise(challenge.name)
    e.site = challenge.site
    e.minutes = challenge.minutes
    e.at = challenge.at
    e.swapped = true
    lastExercise = e.name
    challenge = e
    saveNow()
  }

  // For testing: drop a challenge without counting it as done.
  function testClear() { challenge = null; score = 0; slopMinutes = 0; saveNow() }

  // For testing: fill the meter now.
  function testTrigger() { lastSite = lastSite || "YouTube"; slopMinutes = Math.max(slopMinutes, triggerMinutes); trigger() }

  // ---- notification --------------------------------------------------------
  Process {
    id: notifier
    property var queue: []
    // -p prints the notification's id first, so finishing the set can close it.
    property string lastId: ""
    stdout: SplitParser { onRead: function(line) {
      var s = String(line).trim()
      if (/^\d+$/.test(s)) notifier.lastId = s
      else if (s === "open") coach.openRequested()
    } }
    onRunningChanged: if (!running && queue.length) { command = queue.shift(); running = true }
  }
  // Take the challenge's notification off screen once it's done.
  Process { id: closer }
  function closeNotification() {
    if (!notifier.lastId) return
    closer.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                      "--object-path", "/org/freedesktop/Notifications",
                      "--method", "org.freedesktop.Notifications.CloseNotification", notifier.lastId]
    closer.running = true
    notifier.lastId = ""
  }
  function notify(title, body) {
    var cmd = ["notify-send", "-p", "-a", "Jarvis", "-u", "normal", "-A", "open=Open Jarvis", title, body]
    if (notifier.running) notifier.queue.push(cmd)
    else { notifier.command = cmd; notifier.running = true }
  }

  // ---- timing --------------------------------------------------------------
  IdleMonitor {
    id: idle
    timeout: coach.idleSeconds
    respectInhibitors: true   // a playing video keeps you "active"
  }
  Timer {
    interval: 5000
    repeat: true
    running: !coach.demo
    onTriggered: coach.tick(5)
  }

  // ---- persistence ---------------------------------------------------------
  function snapshot() {
    return {
      score: score, slopMinutes: slopMinutes, lastSite: lastSite, challenge: challenge,
      sinceReminder: sinceReminder, reminded: reminded, doneToday: doneToday, doneDay: doneDay,
      lastExercise: lastExercise
    }
  }
  property bool loaded: false
  Timer { id: saveTimer; interval: 30000; onTriggered: coach.saveNow() }
  function saveSoon() { if (!saveTimer.running) saveTimer.start() }
  function saveNow() {
    if (coach.demo) return
    if (!loaded) return
    saveTimer.stop()
    stateFile.setText(JSON.stringify(snapshot()) + "\n")
  }

  FileView {
    id: stateFile
    path: coach.demo ? "" : coach.stateDir + "/coach.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var s = JSON.parse(text())
        coach.score = Number(s.score) || 0
        coach.slopMinutes = Number(s.slopMinutes) || 0
        coach.lastSite = String(s.lastSite || "")
        coach.challenge = s.challenge && s.challenge.name ? s.challenge : null
        coach.sinceReminder = Number(s.sinceReminder) || 0
        coach.reminded = s.reminded === true
        coach.doneToday = Number(s.doneToday) || 0
        coach.doneDay = String(s.doneDay || "")
        coach.lastExercise = String(s.lastExercise || "")
      } catch (e) {}
      coach.loaded = true
    }
    onLoadFailed: coach.loaded = true
  }

  FileView {
    id: configFile
    path: coach.configDir + "/coach.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var c = JSON.parse(text())
        coach.config = c
        var keys = ["enabled", "triggerMinutes", "remindMinutes", "idleSeconds", "slopSites", "allowTitles", "productiveApps", "gameApps", "exercises"]
        for (var i = 0; i < keys.length; i++) if (c[keys[i]] !== undefined) coach[keys[i]] = c[keys[i]]
      } catch (e) {
        console.warn("jarvis coach: can't read " + path + ": " + e)
      }
    }
  }

  Component.onDestruction: saveNow()
}
