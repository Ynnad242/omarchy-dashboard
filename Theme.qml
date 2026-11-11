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

  readonly property var styles: [
    { key: "flat", label: "Flat" },
    { key: "glass", label: "Glass" },
    { key: "neu", label: "Neumorphism" },
    { key: "clay", label: "Claymorphism" },
    { key: "y2k", label: "Y2K" },
    { key: "swiss", label: "Swiss" },
    { key: "wabi", label: "Wabi-sabi" }
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
  readonly property bool glassy: style === "glass"
  readonly property bool neu: style === "neu"
  readonly property bool clay: style === "clay"
  readonly property bool y2k: style === "y2k"
  readonly property bool swiss: style === "swiss"
  readonly property bool wabi: style === "wabi"

  // ---- what each style starts from ---------------------------------------------
  readonly property color themeBg: Commons.Color.background
  readonly property color themeFg: Commons.Color.foreground
  readonly property color themeAccent: Commons.Color.accent
  property color paletteGreen: "#9ece6a"
  property color paletteRed: "#f7768e"
  property color paletteYellow: "#e0af68"

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
    lookFile.setText(JSON.stringify({ style: t.style, colors: t.custom }, null, 2) + "\n")
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
      } catch (e) {}
    }
  }

  function parseColors(raw) {
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
