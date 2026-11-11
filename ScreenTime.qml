import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Real screen time. Every 5 seconds it credits the focused window's app with
// 5 seconds, unless you've been idle for 5 minutes (a playing video counts as
// active). Browser time goes to the site when it's a known one ("YouTube"),
// else to the browser. Days are kept for 60 days in
// ~/.local/state/jarvis/screentime.json as
//   { "days": { "2026-11-10": { "apps": { "Ghostty": 1234, ... }, "hours": [24 x seconds] } } }
Item {
  id: st

  property var days: ({})
  property int rev: 0                   // bumps on every tick so views re-read
  property bool loaded: false
  readonly property string path: Quickshell.env("HOME") + "/.local/state/jarvis/screentime.json"

  readonly property var names: ({
    "chromium": "Chromium", "google-chrome": "Chrome", "firefox": "Firefox", "brave-browser": "Brave", "zen": "Zen",
    "com.mitchellh.ghostty": "Ghostty", "alacritty": "Alacritty", "kitty": "Kitty", "foot": "Foot",
    "discord": "Discord", "com.anthropic.claude": "Claude", "code": "VS Code", "cursor": "Cursor",
    "steam": "Steam", "obsidian": "Obsidian", "spotify": "Spotify", "org.quickshell": "Jarvis",
    "nautilus": "Files", "org.gnome.nautilus": "Files", "hubless": "Hubless", "sober": "Roblox",
    "org.vinegarhq.sober": "Roblox", "mpv": "mpv", "vlc": "VLC", "obs": "OBS"
  })
  readonly property var browsers: ["chromium", "google-chrome", "firefox", "brave-browser", "zen", "vivaldi"]
  readonly property var sites: [
    ["YouTube", "youtube"], ["TikTok", "tiktok"], ["Instagram", "instagram"], ["Reddit", "reddit"],
    ["X", " / x( - |$)|x\\.com|twitter"], ["Twitch", "twitch"], ["Netflix", "netflix"], ["GitHub", "github"],
    ["Gmail", "gmail|inbox \\("], ["ChatGPT", "chatgpt"], ["Claude", "claude"], ["Roblox", "roblox"]
  ]

  function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }

  function appName(appId, title) {
    var a = String(appId || "").toLowerCase()
    var t = String(title || "").toLowerCase()
    if (a.indexOf("steam_app_") === 0) return String(title || "Game").slice(0, 40)
    if (browsers.indexOf(a) >= 0) {
      for (var i = 0; i < sites.length; i++) {
        try { if (new RegExp(sites[i][1], "i").test(t)) return sites[i][0] } catch (e) {}
      }
    }
    if (names[a]) return names[a]
    var tail = a.split(".").pop()
    return tail ? tail.charAt(0).toUpperCase() + tail.slice(1) : "Other"
  }

  function tick(dt) {
    if (!loaded || idle.isIdle) return
    var top = ToplevelManager.activeToplevel
    if (!top) return
    var name = appName(top.appId, top.title)
    var key = today()
    var d = days[key] || { apps: {}, hours: [] }
    if (!d.hours || d.hours.length !== 24) { d.hours = []; for (var h = 0; h < 24; h++) d.hours.push(0) }
    d.apps[name] = (d.apps[name] || 0) + dt
    d.hours[new Date().getHours()] += dt
    days[key] = d
    rev++
    dirty = true
  }

  // ---- queries for the cards -----------------------------------------------------
  function totalOn(key) {
    var d = days[key]
    if (!d) return 0
    var s = 0
    for (var a in d.apps) s += d.apps[a]
    return s
  }
  function minutesToday() { rev; return totalOn(today()) / 60 }
  function topApps(n) {
    rev
    var d = days[today()]
    if (!d) return []
    var list = []
    for (var a in d.apps) list.push({ name: a, minutes: d.apps[a] / 60 })
    list.sort(function(x, y) { return y.minutes - x.minutes })
    var tones = ["accent", "n", "n", "n", "n"]
    list = list.slice(0, n)
    for (var i = 0; i < list.length; i++) list[i].tone = tones[i % tones.length]
    return list
  }
  function isoOffset(n) { var d = new Date(); d.setDate(d.getDate() + n); return Qt.formatDate(d, "yyyy-MM-dd") }
  // Minutes on each of the last `n` days, oldest first, today last.
  function lastDays(n) {
    rev
    var out = []
    for (var i = n - 1; i >= 0; i--) out.push(totalOn(isoOffset(-i)) / 60)
    return out
  }
  // Average daily minutes over the days before today that have any data.
  function averageBefore(n) {
    rev
    var s = 0, c = 0
    for (var i = 1; i <= n; i++) { var m = totalOn(isoOffset(-i)); if (m > 0) { s += m; c++ } }
    return c ? s / c / 60 : -1
  }
  function chart() {
    rev
    var now = new Date()
    var d = days[today()] || { hours: [] }
    var hours = d.hours && d.hours.length === 24 ? d.hours : []
    var day = []
    for (var b = 0; b < 12; b++) {
      var h = b * 2
      var label = h === 0 ? "12a" : h < 12 ? h + "a" : h === 12 ? "12p" : (h - 12) + "p"
      day.push({ label: label, minutes: ((hours[h] || 0) + (hours[h + 1] || 0)) / 60 })
    }
    var weekday = (now.getDay() + 6) % 7
    var names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    var week = []
    for (var w = 0; w < 7; w++) week.push({ label: names[w], minutes: totalOn(isoOffset(w - weekday)) / 60 })
    var month = []
    for (var k = 4; k >= 0; k--) {
      var tot = 0, n = 0
      for (var j = 0; j < 7; j++) {
        var off = -(k * 7) - weekday + j
        if (off > 0) continue
        tot += totalOn(isoOffset(off)); n++
      }
      var mon = new Date(); mon.setDate(mon.getDate() - k * 7 - weekday)
      month.push({ label: Qt.formatDate(mon, "MMM d"), minutes: n ? tot / 60 / n : 0 })
    }
    return {
      day: { bars: day, current: Math.floor(now.getHours() / 2) },
      week: { bars: week, current: weekday },
      month: { bars: month, current: 4 },
      apps: topApps(5)
    }
  }

  // ---- timing + storage -----------------------------------------------------------
  IdleMonitor { id: idle; timeout: 300; respectInhibitors: true }
  Timer { interval: 5000; repeat: true; running: true; onTriggered: st.tick(5) }

  property bool dirty: false
  Timer { interval: 60000; repeat: true; running: true; onTriggered: st.save() }
  function save() {
    if (!loaded || !dirty) return
    // Keep the last 60 days.
    var keep = {}, cutoff = isoOffset(-60)
    for (var k in days) if (k >= cutoff) keep[k] = days[k]
    days = keep
    file.setText(JSON.stringify({ days: days }) + "\n")
    dirty = false
  }
  FileView {
    id: file
    path: st.path
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try { var j = JSON.parse(text()); if (j && j.days) st.days = j.days } catch (e) {}
      st.loaded = true
      st.rev++
    }
    onLoadFailed: { st.loaded = true }
  }
  Component.onDestruction: save()
}
