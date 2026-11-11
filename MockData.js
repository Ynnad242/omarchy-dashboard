.pragma library

// Made-up data for demo mode (JARVIS_DEMO=1), used for screenshots so they
// never show anyone's real screen time, location or devices.

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function pad(n) { return (n < 10 ? "0" : "") + n }
function hhmm(min) { min = ((min % 1440) + 1440) % 1440; return pad(Math.floor(min / 60)) + ":" + pad(min % 60) }

function greeting(now) {
  var h = now.getHours()
  if (h < 5) return "Good night"
  if (h < 12) return "Good morning"
  if (h < 18) return "Good afternoon"
  return "Good evening"
}

function build(now) {
  var weekday = (now.getDay() + 6) % 7 // Monday first
  var hour = now.getHours()
  var nowMin = hour * 60 + now.getMinutes()

  var weekMinutes = [342, 287, 401, 365, 298, 455, 312]
  var dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  var week = []
  for (var i = 0; i < 7; i++)
    week.push({ label: dayLabels[i], minutes: i <= weekday ? weekMinutes[i] : 0 })
  var todayMinutes = 312
  week[weekday].minutes = todayMinutes

  var dayShape = [4, 0, 0, 0, 22, 48, 70, 54, 38, 61, 45, 30]
  var day = []
  for (var b = 0; b < 12; b++) {
    var h = b * 2
    var label = h === 0 ? "12a" : h < 12 ? h + "a" : h === 12 ? "12p" : (h - 12) + "p"
    day.push({ label: label, minutes: b <= Math.floor(hour / 2) ? dayShape[b] : 0 })
  }

  var month = []
  var weeksBack = [2104, 2380, 1966, 2251, 0]
  for (var w = 0; w < 5; w++) {
    var d = new Date(now.getTime() - (4 - w) * 7 * 86400000)
    var monday = new Date(d.getTime() - ((d.getDay() + 6) % 7) * 86400000)
    var m = w === 4 ? (weekMinutes.slice(0, weekday).reduce(function(a, c) { return a + c }, 0) + todayMinutes) : weeksBack[w]
    month.push({ label: MONTHS[monday.getMonth()] + " " + monday.getDate(), minutes: m / 7 })
  }

  // One event sits on top of "now" so the live marker always shows.
  var liveStart = Math.floor(nowMin / 30) * 30 - 30
  var today = [
    { start: hhmm(liveStart - 240), end: hhmm(liveStart - 225), title: "Daily stand-up", where: "Discord · Late Night", tone: "accent", who: ["Kai", "Rio", "+2"] },
    { start: hhmm(liveStart - 120), end: hhmm(liveStart - 60), title: "Gym — legs", where: "", tone: "green", who: [] },
    { start: hhmm(liveStart), end: hhmm(liveStart + 90), title: "Deep work: release notes", where: "~/Projects/app", tone: "magenta", who: [] },
    { start: hhmm(liveStart + 120), end: hhmm(liveStart + 150), title: "Call with Maya re: lease", where: "Phone", tone: "yellow", who: ["Maya Patel"] },
    { start: hhmm(liveStart + 210), end: hhmm(liveStart + 300), title: "Ranked with the squad", where: "Discord", tone: "cyan", who: ["Kai", "Sam", "Rio"] }
  ]

  return {
    now: now,
    greeting: greeting(now),
    chart: {
      day: { bars: day, current: Math.floor(hour / 2) },
      week: { bars: week, current: weekday },
      month: { bars: month, current: 4 },
      apps: [
        { name: "Firefox", minutes: 96, tone: "yellow" },
        { name: "Code", minutes: 72, tone: "accent" },
        { name: "Discord", minutes: 58, tone: "magenta" },
        { name: "Alacritty", minutes: 41, tone: "green" },
        { name: "Steam", minutes: 30, tone: "cyan" }
      ]
    },
    screenToday: todayMinutes,
    screenSpark: weekMinutes.slice(0, weekday + 1).concat(weekday === 0 ? [todayMinutes] : []),
    today: today,
    inbox: [
      { from: "Maya Patel", subject: "Re: Lease renewal — sign by Friday", snippet: "Hey! The landlord sent the new terms, can you look before…", time: "14m", needsReply: true, unread: true },
      { from: "GitHub", subject: "[my-app] Issue #42: Settings reset after update", snippet: "kai-dev opened an issue: After updating, the theme goes back…", time: "1h", needsReply: false, unread: true },
      { from: "Jordan Lee", subject: "Saturday plans?", snippet: "We're thinking the night market around 7, you in?", time: "3h", needsReply: true, unread: false },
      { from: "Course Portal", subject: "Assignment 4 grade posted", snippet: "Your grade for Assignment 4 is now available.", time: "5h", needsReply: false, unread: false }
    ],
    discord: {
      voice: { channel: "Late Night", server: "The Lab", members: [{ name: "Kai", speaking: true }, { name: "Rio" }, { name: "Sam" }] },
      mentions: [
        { from: "Kai", where: "#dev", text: "@you can you review my PR before tonight?", time: "5m" },
        { from: "Rio", dm: true, text: "you hopping on later?", time: "22m" },
        { from: "Sam", where: "#general", text: "@you look at the clip I just posted", time: "1h" }
      ]
    },
    todos: [
      { title: "Write the weekly update", done: false, due: "Today" },
      { title: "Fix settings reset (#42)", done: false, due: "Today" },
      { title: "Reply to Maya about the lease", done: false, due: "Today" },
      { title: "Publish v0.6.1", done: true, due: "Today" },
      { title: "Gym — legs", done: true, due: "Today" },
      { title: "Order a new desk lamp", done: false, due: "Fri" },
      { title: "Back up dotfiles", done: false, due: "" }
    ],
    stocks: [
      { sym: "NVDA", price: 142.18, change: 2.31 },
      { sym: "AAPL", price: 228.40, change: -0.42 },
      { sym: "TSLA", price: 251.09, change: 1.12 },
      { sym: "AMD", price: 156.77, change: 0.86 },
      { sym: "SPY", price: 598.12, change: 0.37 }
    ],
    stocksSpark: [0.1, -0.2, 0.3, 0.2, 0.6, 0.5, 0.9, 0.8, 1.1, 1.24],
    system: { cpu: 23, ram: 61, disk: 48, mouse: { name: "Wireless mouse", battery: 82, dpi: 1600, profile: "Profile 1" } }
  }
}

function stats(d, done, total) {
  var replies = d.inbox.filter(function(m) { return m.needsReply }).length
  var avg = 0
  for (var i = 0; i < d.stocks.length; i++) avg += d.stocks[i].change
  avg = avg / Math.max(1, d.stocks.length)
  return [
    { key: "screen", title: "Screen time today", icon: "", tone: "accent", kind: "duration", value: d.screenToday, delta: -8, deltaUnit: "%", deltaLabel: "under avg", lowerIsBetter: true, spark: d.screenSpark },
    { key: "tasks", title: "Tasks done", icon: "", tone: "green", kind: "fraction", value: done, total: total, delta: 2, deltaLabel: "vs yesterday", spark: [1, 3, 2, 4, 3, 5, done] },
    { key: "inbox", title: "Emails need a reply", icon: "", tone: "yellow", kind: "count", value: replies, delta: 1, deltaLabel: "since this morning", lowerIsBetter: true, spark: [0, 1, 1, 3, 2, 1, replies] },
    { key: "stocks", title: "Watchlist today", icon: "", tone: avg >= 0 ? "green" : "red", kind: "percent", value: avg, ticker: d.stocks, spark: d.stocksSpark }
  ]
}

function briefing(d, openTodos) {
  var next = null
  var nowMin = d.now.getHours() * 60 + d.now.getMinutes()
  for (var i = 0; i < d.today.length; i++) {
    var p = d.today[i].start.split(":")
    var s = parseInt(p[0]) * 60 + parseInt(p[1])
    if (s > nowMin) { next = d.today[i]; break }
  }
  var replies = d.inbox.filter(function(m) { return m.needsReply }).length
  var parts = []
  parts.push(openTodos + (openTodos === 1 ? " task" : " tasks") + " left")
  parts.push(replies + (replies === 1 ? " email needs" : " emails need") + " a reply")
  parts.push(d.discord.mentions.length + " Discord pings")
  return parts.join(", ") + "." + (next ? " Next up: " + next.title + " at " + next.start + "." : "")
}

function reply(q, d, openTitles) {
  var s = String(q).toLowerCase()
  var tail = "\n\n(Preview answer from sample data. Claude gets wired in during phase 3.)"
  if (/mail|inbox|email/.test(s)) {
    var need = d.inbox.filter(function(m) { return m.needsReply })
    return "Two emails need you. " + need.map(function(m) { return m.from + ": “" + m.subject + "”" }).join(", and ") +
      ". Maya's is the urgent one, the lease has to be signed by Friday. The GitHub issue (#42) lines up with a task on your list." + tail
  }
  if (/screen|time|hours/.test(s)) {
    return "You're at 5h 12m today, about 8% under your average. Firefox leads with 1h 36m, then Code at 1h 12m and Discord at 58m." + tail
  }
  return "Here's your day. You're in “Deep work: release notes” right now, then a call with Maya about the lease. Still open: " +
    openTitles.slice(0, 3).join("; ") + ". Reply to Maya first, the lease deadline is Friday, and Kai asked in #dev for a PR review." + tail
}
