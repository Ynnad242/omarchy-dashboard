.pragma library

// Where the cards go on Home. The layout is a list of rows, each a list of
// card keys, saved as settings.layout. Cards in a row share its width by
// weight; a row of only stat cards is short, the other rows split what's left.
// Home and the Settings preview both place cards with geometry(), and the
// preview's drag-and-drop snaps cards into rows with target() and move().

var weights = {
  "stat-screen": 1, "stat-tasks": 1, "stat-inbox": 1, "stat-stocks": 1,
  screentime: 2, today: 1,
  mail: 1.2, discord: 1, todo: 1, home: 1.05, music: 1, system: 0.75
}
var defaults = [
  ["stat-screen", "stat-tasks", "stat-inbox", "stat-stocks"],
  ["screentime", "today"],
  ["mail", "discord", "todo", "home", "music", "system"]
]
var all = [].concat.apply([], defaults)
var maxPerRow = 6
var maxRows = 4

function isStat(k) { return String(k).indexOf("stat-") === 0 }
function weight(k) { return weights[k] || 1 }
function copy(rows) { return rows.map(function(r) { return r.slice() }) }

// A saved layout, cleaned up: unknown or repeated keys dropped, and cards it
// doesn't mention yet (added in a later version) put where they'd be by default.
function normalize(saved) {
  if (!Array.isArray(saved) || !saved.length) return copy(defaults)
  var seen = {}, rows = []
  for (var i = 0; i < saved.length; i++) {
    if (!Array.isArray(saved[i])) continue
    var r = []
    for (var j = 0; j < saved[i].length; j++) {
      var k = saved[i][j]
      if (all.indexOf(k) >= 0 && !seen[k]) { seen[k] = true; r.push(k) }
    }
    if (r.length) rows.push(r)
  }
  for (var d = 0; d < defaults.length; d++)
    for (var e = 0; e < defaults[d].length; e++) {
      var key = defaults[d][e]
      if (seen[key]) continue
      seen[key] = true
      // Next to the card it follows by default, or in a row of its own.
      var prev = e > 0 ? defaults[d][e - 1] : "", placed = false
      for (var x = 0; x < rows.length && prev && !placed; x++) {
        var at = rows[x].indexOf(prev)
        if (at >= 0 && rows[x].length < maxPerRow) { rows[x].splice(at + 1, 0, key); placed = true }
      }
      if (!placed) rows.push([key])
    }
  return rows
}

function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

// The rows as they're drawn: only shown cards, no empty rows.
function visible(rows, shows) {
  return rows.map(function(r) { return r.filter(shows) }).filter(function(r) { return r.length > 0 })
}

// Boxes for each shown card: { key: {x, y, w, h, order} }, plus .rows with
// each row's band, for drop targeting.
function geometry(rows, width, top, height, gap, shortH) {
  var out = {}, bands = [], n = rows.length, tall = 0, shorts = 0, i, j
  for (i = 0; i < n; i++) { if (rows[i].every(isStat)) shorts++; else tall++ }
  var tallH = tall ? Math.max(0, (height - shorts * shortH - gap * Math.max(0, n - 1)) / tall) : 0
  var y = top, order = 1
  for (i = 0; i < n; i++) {
    var r = rows[i], h = r.every(isStat) ? shortH : tallH, sum = 0
    for (j = 0; j < r.length; j++) sum += weight(r[j])
    var unit = (width - gap * Math.max(0, r.length - 1)) / Math.max(0.01, sum), x = 0, boxes = []
    for (j = 0; j < r.length; j++) {
      var w = j === r.length - 1 ? width - x : unit * weight(r[j])
      out[r[j]] = { x: x, y: y, w: w, h: h, order: order++ }
      boxes.push(out[r[j]])
      x += w + gap
    }
    bands.push({ y: y, h: h, keys: r, boxes: boxes })
    y += h + gap
  }
  out.rows = bands
  return out
}

// Take a card out of the layout (empty rows go too).
function without(rows, key) {
  return rows.map(function(r) { return r.filter(function(k) { return k !== key }) }).filter(function(r) { return r.length > 0 })
}

// Where a card dropped at (px, py) lands, given the geometry of the layout
// without it: { row, pos } into a row, { row, newRow: true } as a new row
// before `row`, or null if that spot is full.
function target(geo, px, py) {
  var bands = geo.rows, n = bands.length
  var canNew = n < maxRows
  if (!n) return { row: 0, newRow: true }
  for (var i = 0; i < n; i++) {
    var b = bands[i], edge = Math.min(b.h * 0.25, 40)
    if (py < b.y + edge && canNew) return { row: i, newRow: true }
    if (py <= b.y + b.h - edge || (i === n - 1 && !canNew) || (py < b.y + b.h && !canNew)) {
      if (b.keys.length >= maxPerRow) return null
      var pos = 0
      for (var j = 0; j < b.boxes.length; j++) if (px > b.boxes[j].x + b.boxes[j].w / 2) pos = j + 1
      return { row: i, pos: pos }
    }
  }
  return canNew ? { row: n, newRow: true } : null
}

// Put `key` at a target. `rows` is the full layout (hidden cards too); the
// target's row and position count only shown cards, as drawn.
function move(rows, key, t, shows) {
  var full = without(rows, key)
  // Which full row each drawn row is.
  var map = []
  for (var i = 0; i < full.length; i++) if (full[i].some(shows)) map.push(i)
  if (t.newRow) {
    var at = t.row < map.length ? map[t.row] : full.length
    full.splice(at, 0, [key])
    return full
  }
  var row = full[map[t.row]]
  var shown = row.filter(shows)
  if (t.pos < shown.length) row.splice(row.indexOf(shown[t.pos]), 0, key)
  else row.splice(row.indexOf(shown[shown.length - 1]) + 1, 0, key)
  return full
}
