import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// The design system. A style (flat, glass, neu, clay, y2k, swiss, wabi) sets
// the canvas, surfaces, borders, text, corners, typeface and accent; any of
// background / surface / border / accent / text can then be overridden by
// hand. Both live in ~/.config/jarvis/look.json:
//   { "style": "glass", "colors": { "accent": "#ff5fd2" } }
// JARVIS_STYLE overrides the style (used for offscreen previews).
//
// Color stays meaningful: one accent for "selected / current", and green,
// red and amber only for good, bad and attention. Sizes are written for
// 1920x1080 and scaled by `u`.
QtObject {
  id: t

  property real u: 1
  function px(v) { return Math.round(v * t.u) }

  // Follows Settings > Clock everywhere a time is shown.
  property bool clock24: true
  readonly property string timeFmt: clock24 ? "HH:mm" : "h:mm AP"
  function hourLabel(h) { return clock24 ? (h < 10 ? "0" : "") + h : (h % 12 === 0 ? "12" : String(h % 12)) + (h < 12 ? "a" : "p") }

  readonly property var styles: [
    { key: "flat", label: "Flat" },
    { key: "glass", label: "Glass" },
    { key: "neu", label: "Neumorphism" },
    { key: "clay", label: "Claymorphism" },
    { key: "y2k", label: "Y2K" },
    { key: "swiss", label: "Swiss" },
    { key: "wabi", label: "Wabi-sabi" },
    { key: "omarchy", label: "Omarchy" },
    { key: "discord", label: "Discord" }
  ]
  readonly property var colorKeys: [
    { key: "background", label: "Background" },
    { key: "surface", label: "Cards" },
    { key: "border", label: "Borders" },
    { key: "accent", label: "Accent" },
    { key: "text", label: "Text" }
  ]

  property string style: Quickshell.env("JARVIS_STYLE") || "flat"
  property var custom: ({})          // hand-picked colors, by key
  // The user's own saved themes: [{ name, style, colors }], newest last.
  property var saved: []
  readonly property bool glassy: style === "glass"
  readonly property bool neu: style === "neu"
  readonly property bool clay: style === "clay"
  readonly property bool y2k: style === "y2k"
  readonly property bool swiss: style === "swiss"
  readonly property bool wabi: style === "wabi"
  readonly property bool omarchy: style === "omarchy"
  readonly property bool discord: style === "discord"

  // ---- what each style starts from ---------------------------------------------
  readonly property color themeBg: Commons.Color.background
  readonly property color themeFg: Commons.Color.foreground
  readonly property color themeAccent: Commons.Color.accent
  property color paletteGreen: "#9ece6a"
  property color paletteRed: "#f7768e"
  property color paletteYellow: "#e0af68"
  // The rest of the Omarchy theme, for the Omarchy style: colors.toml keys
  // and the window border colors from the theme's hyprland.lua.
  property var pal: ({})
  property int hyprBorder: 0

  readonly property var preset: presetFor(style)
  // Any style's recipe, so the settings page can preview styles not in use.
  function presetFor(s) {
    var bg = themeBg, fg = themeFg
    var darkText = Qt.tint(fg, Qt.rgba(1, 1, 1, 0.55))
    switch (s) {
    case "glass": return {
      dark: true, base: Qt.darker(bg, 1.75), surface: Qt.rgba(1, 1, 1, 0.06), hover: Qt.rgba(1, 1, 1, 0.085),
      raised: Qt.rgba(1, 1, 1, 0.11), border: Qt.rgba(1, 1, 1, 0.13), borderStrong: Qt.rgba(1, 1, 1, 0.24),
      text: darkText, radius: 16, small: 9, font: "Adwaita Sans" }
    // Soft UI: a light gray canvas, white highlight up-left, gray shade
    // down-right, a muted blue for anything that's on.
    case "neu": return {
      dark: false, base: "#e3e6eb", surface: "#e3e6eb", hover: "#e6e9ee", raised: "#e3e6eb",
      border: Qt.rgba(0, 0, 0, 0), borderStrong: Qt.rgba(0, 0, 0, 0.06), text: "#2c323b",
      radius: 22, small: 12, font: "Adwaita Sans", accent: "#36659d", green: "#2f8a52", red: "#c94a46", yellow: "#a8701a",
      shadowLight: "#ffffff", shadowDark: "#b4bcc8" }
    case "clay": return {
      dark: true, base: Qt.darker(bg, 1.2), surface: Qt.lighter(bg, 1.45), hover: Qt.lighter(bg, 1.55),
      raised: Qt.lighter(bg, 1.8), border: Qt.rgba(1, 1, 1, 0), borderStrong: Qt.rgba(1, 1, 1, 0.08),
      text: darkText, radius: 28, small: 14, font: "Adwaita Sans" }
    // Y2K futurism: electric cobalt, retro OS windows, a hot lime accent.
    case "y2k": return {
      dark: true, base: "#06128f", surface: Qt.rgba(0.02, 0.05, 0.30, 0.62), hover: Qt.rgba(0.03, 0.07, 0.36, 0.70),
      raised: Qt.rgba(1, 1, 1, 0.14), border: Qt.rgba(0.67, 0.78, 1, 0.55), borderStrong: "#dfe9ff",
      text: "#f4f7ff", radius: 6, small: 4, font: "Adwaita Sans", accent: "#c8ff3a",
      green: "#5dffa0", red: "#ff5c8a", yellow: "#ffe14d" }
    case "swiss": return {
      dark: false, base: "#f2f0eb", surface: "#f2f0eb", hover: "#ebe8e1", raised: "#e2ded6",
      border: "#111111", borderStrong: "#111111", text: "#111111", radius: 0, small: 0, font: "Liberation Sans",
      accent: "#e30613", green: "#1a7f37", red: "#e30613", yellow: "#a35200" }
    case "wabi": return {
      dark: false, base: "#ddd3c1", surface: "#f6f1e6", hover: "#f9f5ec", raised: "#e6ddcc",
      border: Qt.rgba(0.23, 0.19, 0.14, 0.26), borderStrong: Qt.rgba(0.23, 0.19, 0.14, 0.42), text: "#3a332b",
      radius: 5, small: 4, font: "C059", accent: "#a5623d", green: "#5f7a4a", red: "#a8553a", yellow: "#9a742b" }
    // Omarchy: this computer's own look. The Omarchy theme's colors, its
    // window border colors and border width, Hyprland's corner rounding, the
    // system font, and the wallpaper behind it all. Follows theme changes.
    case "omarchy": {
      var pb = t.pal.background || bg
      var ps = t.pal.lighter_background || Qt.lighter(pb, 1.25)
      return {
        dark: t.pal.mode !== "light", base: pb, surface: ps, hover: Qt.lighter(ps, 1.06), raised: t.pal.selection || Qt.lighter(ps, 1.12),
        border: t.pal.inactive_border || Commons.Util.alpha(fg, 0.15), borderStrong: t.pal.active_border || themeAccent,
        text: t.pal.bright_foreground || fg, radius: Commons.Style.cornerRadius / t.u, small: Commons.Style.cornerRadius / t.u,
        font: Commons.Style.font.family, borderWidth: Math.max(1, t.hyprBorder) }
    }
    // Discord: its dark theme. Chat-gray canvas, sidebar-gray cards with an
    // embed's colored bar, blurple accent, green switches, Noto Sans (the
    // fallback for Discord's own gg sans).
    case "discord": return {
      dark: true, base: "#313338", surface: "#2b2d31", hover: "#2e3035", raised: "#383a40",
      border: Qt.rgba(0, 0, 0, 0), borderStrong: Qt.rgba(1, 1, 1, 0.08), text: "#dbdee1",
      radius: 8, small: 4, font: "Noto Sans", accent: "#5865f2", green: "#23a55a", red: "#f23f43", yellow: "#f0b232" }
    default: return {
      dark: true, base: Qt.darker(bg, 1.45), surface: Qt.tint(Qt.darker(bg, 1.45), Qt.rgba(1, 1, 1, 0.035)),
      hover: Qt.tint(Qt.darker(bg, 1.45), Qt.rgba(1, 1, 1, 0.055)), raised: Qt.tint(Qt.darker(bg, 1.45), Qt.rgba(1, 1, 1, 0.07)),
      border: Qt.rgba(1, 1, 1, 0.07), borderStrong: Qt.rgba(1, 1, 1, 0.13), text: darkText, radius: 10, small: 6, font: "Adwaita Sans" }
    }
  }

  function pick(key, fallback) {
    var c = t.custom && t.custom[key]
    return (typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c)) ? c : fallback
  }

  // ---- tokens -------------------------------------------------------------------------
  readonly property bool dark: preset.dark
  readonly property color base: pick("background", preset.base)
  readonly property color surface: custom && custom.surface ? pick("surface", preset.surface) : preset.surface
  readonly property color surfaceHover: custom && custom.surface ? Qt.lighter(surface, dark ? 1.08 : 0.97) : preset.hover
  readonly property color raised: preset.raised
  readonly property color border: custom && custom.border ? alpha(pick("border", "#ffffff"), swiss ? 1 : 0.35) : preset.border
  readonly property color borderStrong: custom && custom.border ? pick("border", "#ffffff") : preset.borderStrong
  readonly property color accent: pick("accent", preset.accent || themeAccent)
  readonly property color text: pick("text", preset.text)
  // Dim and faint text still meet WCAG AA (4.5:1) on every style's cards;
  // light styles need a little more ink to get there.
  readonly property color textDim: alpha(text, dark ? 0.70 : 0.80)
  readonly property color textFaint: alpha(text, dark ? 0.60 : 0.74)
  readonly property color green: preset.green || paletteGreen
  readonly property color red: preset.red || paletteRed
  readonly property color yellow: preset.yellow || paletteYellow
  readonly property color urgent: Commons.Color.urgent

  // "Ink": hairlines, tracks and hover washes, white on dark styles and
  // black on light ones.
  function inkA(a) { return t.dark ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0, 0, 0, a * 0.9) }

  // Kept for older call sites.
  readonly property color fg: text
  readonly property color bg: base
  readonly property color magenta: textDim
  readonly property color cyan: textDim
  readonly property color glass: surface
  readonly property color glassHover: surfaceHover
  // Neumorphism lights everything from the top-left with two tones of the
  // canvas itself: a lighter one for the lit edge, a darker one for shade.
  readonly property color shadowLight: preset.shadowLight || Qt.lighter(base, 1.3)
  readonly property color shadowDark: preset.shadowDark || Qt.darker(base, 1.7)
  readonly property color glassInset: neu ? Qt.darker(base, 1.06) : clay ? Qt.darker(surface, 1.12) : inkA(dark ? 0.035 : 0.04)
  readonly property color stroke: border
  readonly property color strokeHover: borderStrong

  readonly property real borderWidth: preset.borderWidth || 1
  readonly property int radius: px(preset.radius)
  readonly property int radiusSmall: px(preset.small)
  readonly property string font: preset.font
  readonly property string mono: Commons.Style.font.family

  function alpha(c, a) { return Commons.Util.alpha(c, a) }
  // Only meaningful colors survive; everything decorative is neutral.
  function tone(name) {
    switch (name) {
      case "green": return t.green
      case "red": return t.red
      case "yellow": return t.yellow
      case "accent": return t.accent
      default: return t.textDim
    }
  }

  // ---- reading and saving look.json ----------------------------------------------------
  function setStyle(s) { t.style = s; save() }
  function setColor(key, hex) {
    var c = {}
    for (var k in t.custom) c[k] = t.custom[k]
    if (hex) c[key] = hex; else delete c[key]
    t.custom = c
    save()
  }
  function resetColors() { t.custom = ({}); save() }
  function save() {
    lookFile.setText(JSON.stringify({ style: t.style, colors: t.custom, saved: t.saved }, null, 2) + "\n")
  }

  // ---- saved themes ---------------------------------------------------------------------
  function copyColors(c) {
    var out = {}
    for (var k in (c || {})) if (/^#[0-9a-fA-F]{6}$/.test(String(c[k]))) out[k] = String(c[k]).toLowerCase()
    return out
  }
  function sameColors(a, b) {
    var x = copyColors(a), y = copyColors(b), kx = Object.keys(x), ky = Object.keys(y)
    if (kx.length !== ky.length) return false
    for (var i = 0; i < kx.length; i++) if (x[kx[i]] !== y[kx[i]]) return false
    return true
  }
  // Which saved theme is showing right now, or -1.
  readonly property int activeSaved: {
    for (var i = 0; i < t.saved.length; i++)
      if (t.saved[i].style === t.style && sameColors(t.saved[i].colors, t.custom)) return i
    return -1
  }
  function uniqueName() {
    var n = t.saved.length + 1
    while (t.saved.some(function(e) { return e.name === "My theme " + n })) n++
    return "My theme " + n
  }
  // Save the style and colors in use under a name; the same name updates it.
  function saveCurrent(name) {
    name = String(name || "").trim().slice(0, 30) || uniqueName()
    var entry = { name: name, style: t.style, colors: copyColors(t.custom) }
    var list = t.saved.slice()
    var at = -1
    for (var i = 0; i < list.length; i++) if (list[i].name === name) at = i
    if (at >= 0) list[at] = entry
    else list.push(entry)
    t.saved = list.slice(-24)
    save()
  }
  function applySaved(i) {
    var e = t.saved[i]
    if (!e) return
    t.style = e.style
    t.custom = copyColors(e.colors)
    save()
  }
  function deleteSaved(i) {
    var list = t.saved.slice()
    list.splice(i, 1)
    t.saved = list
    save()
  }

  property FileView lookFile: FileView {
    path: Quickshell.env("HOME") + "/.config/jarvis/look.json"
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: {
      try {
        var j = JSON.parse(text())
        if (!Quickshell.env("JARVIS_STYLE")) {
          for (var i = 0; i < t.styles.length; i++) if (t.styles[i].key === j.style) t.style = j.style
        }
        t.custom = j.colors && typeof j.colors === "object" ? j.colors : ({})
        var keys = t.styles.map(function(x) { return x.key })
        t.saved = (Array.isArray(j.saved) ? j.saved : []).filter(function(e) {
          return e && typeof e.name === "string" && keys.indexOf(e.style) >= 0
        }).slice(0, 24).map(function(e) { return { name: e.name.slice(0, 30), style: e.style, colors: t.copyColors(e.colors) } })
      } catch (e) {}
    }
  }

  function parseTheme(raw) {
    var p = {}
    var keys = ["mode", "background", "lighter_background", "dark_background", "selection", "muted", "foreground", "bright_foreground"]
    for (var i = 0; i < keys.length; i++) {
      var m = new RegExp("^\\s*" + keys[i] + "\\s*=\\s*\"([^\"]+)\"", "m").exec(raw)
      if (m) p[keys[i]] = m[1]
    }
    for (var k in t.pal) if (k === "active_border" || k === "inactive_border") p[k] = t.pal[k]
    t.pal = p
  }
  // hyprland.lua: local active_border_color = "#7aa2f7", inactive = "rgba(595959aa)"
  function parseBorders(raw) {
    var p = {}
    for (var k in t.pal) p[k] = t.pal[k]
    var a = /active_border_color\s*=\s*"#([0-9a-fA-F]{6})/.exec(raw)
    if (a) p.active_border = "#" + a[1]
    var n = /inactive_border_color\s*=\s*"(?:rgba\()?#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?/.exec(raw)
    if (n) p.inactive_border = n[2] ? Qt.rgba(parseInt(n[1].slice(0, 2), 16) / 255, parseInt(n[1].slice(2, 4), 16) / 255, parseInt(n[1].slice(4, 6), 16) / 255, parseInt(n[2], 16) / 255) : "#" + n[1]
    t.pal = p
  }
  property FileView hyprThemeFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/hyprland.lua"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: t.parseBorders(text())
  }
  property Process borderProc: Process {
    command: ["hyprctl", "getoption", "general:border_size", "-j"]
    running: true
    stdout: StdioCollector { onStreamFinished: { try { t.hyprBorder = JSON.parse(text).int || 0 } catch (e) {} } }
  }

  function parseColors(raw) {
    t.parseTheme(raw)
    var keys = [["green", "paletteGreen"], ["red", "paletteRed"], ["yellow", "paletteYellow"]]
    for (var i = 0; i < keys.length; i++) {
      var m = new RegExp("^\\s*" + keys[i][0] + "\\s*=\\s*\"(#[0-9a-fA-F]{6})\"", "m").exec(raw)
      if (m) t[keys[i][1]] = m[1]
    }
  }
  property FileView colorsFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: t.parseColors(text())
  }
  onThemeAccentChanged: colorsFile.reload()
}
