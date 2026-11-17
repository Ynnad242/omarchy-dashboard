import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons

// What's playing, with back / play-pause / next and a seekable progress bar.
// Talks to Spotify (or any other player) through MPRIS, the desktop's standard
// media-control interface, so there's nothing to sign in to. If Spotify isn't
// installed or open, the card offers to install or open it.
GlassCard {
  id: card

  property bool demo: false
  property bool live: true                 // only poll while on screen

  title: "Music"

  // ---- the player ------------------------------------------------------------
  readonly property var players: Mpris.players ? Mpris.players.values : []
  // Prefer Spotify; otherwise whatever is playing; otherwise anything with a track.
  readonly property var player: {
    var ps = players, best = null, i
    for (i = 0; i < ps.length; i++) if (isSpotify(ps[i]) && ps[i].trackTitle) return ps[i]
    for (i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
    for (i = 0; i < ps.length; i++) if (ps[i].trackTitle && !best) best = ps[i]
    return best
  }
  function isSpotify(p) { return !!p && (String(p.identity).toLowerCase().indexOf("spotify") >= 0 || String(p.desktopEntry).toLowerCase().indexOf("spotify") >= 0) }

  property real demoPos: 74
  readonly property var track: demo ? ({ title: "Midnight Drive", artist: "Neon Coast", art: "", length: 214, pos: demoPos, playing: true,
                                         prev: true, next: true, seek: true, source: "Spotify" })
    : player ? ({ title: player.trackTitle || "", artist: player.trackArtist || "", art: player.trackArtUrl || "",
                  length: player.lengthSupported ? player.length : 0, pos: player.positionSupported ? player.position : 0,
                  playing: player.isPlaying, prev: player.canGoPrevious, next: player.canGoNext, seek: player.canSeek && player.lengthSupported,
                  source: player.identity || "" })
    : null

  // MPRIS doesn't push the position, so ask for it while something plays.
  Timer {
    interval: 1000; repeat: true
    running: card.live && !card.demo && !!card.player && card.player.isPlaying
    onTriggered: card.player.positionChanged()
  }

  // ---- Spotify installed? ------------------------------------------------------
  property bool installed: true
  property bool checked: false
  Process {
    id: which
    command: ["sh", "-c", "command -v spotify || command -v spotify-launcher"]
    onExited: function(code) { card.installed = code === 0; card.checked = true }
  }
  // Check now, and keep checking while the installer may be running.
  Timer {
    interval: 5000; repeat: true; triggeredOnStart: true
    running: card.live && !card.demo && (!card.checked || !card.installed)
    onTriggered: if (!which.running) which.running = true
  }
  function install() { Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy pkg add spotify-launcher"]) }
  function openSpotify() { Quickshell.execDetached(["sh", "-c", "command -v spotify >/dev/null && exec setsid -f spotify || exec setsid -f spotify-launcher"]) }

  function fmt(s) {
    s = Math.max(0, Math.floor(s || 0))
    var m = Math.floor(s / 60), r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }
  function toggle() { if (card.demo) return; if (card.player && card.player.canTogglePlaying) card.player.togglePlaying() }
  function back() { if (!card.demo && card.player && card.player.canGoPrevious) card.player.previous() }
  function skip() { if (!card.demo && card.player && card.player.canGoNext) card.player.next() }
  function seekTo(frac) {
    if (card.demo || !card.player || !card.track.seek) return
    card.player.position = Math.max(0, Math.min(1, frac)) * card.track.length
  }

  // ---- now playing ----------------------------------------------------------------
  Item {
    id: body
    anchors.fill: parent
    visible: !!card.track && card.track.title.length > 0
    opacity: card.ease(card.progress * 1.4)

    // As big as the space above the progress bar allows.
    readonly property real artD: Math.max(card.t.px(40), Math.min(card.t.px(112), width * 0.42,
                                                                   height - controls.height - bar.height - card.t.px(22)))

    Rectangle {
      id: art
      width: body.artD; height: width
      radius: card.t.radiusSmall
      color: card.t.glassInset
      clip: true
      InsetShade { t: card.t }
      JText { t: card.t; anchors.centerIn: parent; text: String.fromCodePoint(0xF075A); size: 20; color: card.t.textFaint; visible: cover.status !== Image.Ready }
      Image {
        id: cover
        anchors.fill: parent
        source: card.track && /^(https:|file:)/.test(card.track.art) ? card.track.art : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 160; sourceSize.height: 160
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.duration(260) } }
      }
    }
    Column {
      anchors.left: art.right
      anchors.leftMargin: card.t.px(12)
      anchors.right: parent.right
      anchors.verticalCenter: art.verticalCenter
      spacing: card.t.px(3)
      JText {
        width: parent.width
        t: card.t
        text: card.track ? card.track.title : ""
        size: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      JText {
        width: parent.width
        t: card.t
        text: card.track ? card.track.artist : ""
        size: 10.5
        color: card.t.textDim
        elide: Text.ElideRight
      }
      JText {
        width: parent.width
        t: card.t
        visible: !!card.track && card.track.source.length > 0 && !/spotify/i.test(card.track.source)
        text: card.track ? "on " + card.track.source : ""
        size: 9
        color: card.t.textFaint
        elide: Text.ElideRight
      }
    }

    // Progress: click or drag to jump.
    Item {
      id: bar
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: controls.top
      anchors.bottomMargin: card.t.px(8)
      height: card.t.px(26)
      visible: !!card.track && card.track.length > 0
      readonly property real frac: card.track && card.track.length > 0 ? Math.min(1, card.track.pos / card.track.length) : 0
      readonly property real shown: seekArea.pressed ? seekArea.dragFrac : frac

      Rectangle {
        id: rail
        y: card.t.px(4)
        width: parent.width
        height: card.t.px(seekArea.containsMouse || seekArea.pressed ? 5 : 4)
        radius: height / 2
        color: card.t.inkA(0.10)
        Behavior on height { NumberAnimation { duration: Style.duration(120) } }
        Rectangle {
          width: Math.max(parent.height, parent.width * bar.shown)
          height: parent.height
          radius: parent.radius
          color: card.t.text
        }
      }
      Rectangle {
        x: rail.width * bar.shown - width / 2
        anchors.verticalCenter: rail.verticalCenter
        width: card.t.px(11); height: width; radius: width / 2
        color: card.t.text
        visible: !!card.track && card.track.seek
        opacity: seekArea.containsMouse || seekArea.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
      }
      JText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        t: card.t
        text: card.fmt(seekArea.pressed ? seekArea.dragFrac * card.track.length : card.track ? card.track.pos : 0)
        size: 9; color: card.t.textFaint
        font.features: { "tnum": 1 }
      }
      JText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        t: card.t
        text: card.track ? card.fmt(card.track.length) : ""
        size: 9; color: card.t.textFaint
        font.features: { "tnum": 1 }
      }
      MouseArea {
        id: seekArea
        anchors.fill: parent
        anchors.bottomMargin: card.t.px(10)
        enabled: !!card.track && card.track.seek
        hoverEnabled: true
        preventStealing: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        property real dragFrac: 0
        onPressed: function(m) { dragFrac = Math.max(0, Math.min(1, m.x / width)) }
        onPositionChanged: function(m) { if (pressed) dragFrac = Math.max(0, Math.min(1, m.x / width)) }
        onReleased: card.seekTo(dragFrac)
      }
    }

    Row {
      id: controls
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      spacing: card.t.px(18)

      component Ctl: Rectangle {
        id: ctl
        property string glyph: ""
        property bool big: false
        property bool can: true
        property string name: ""
        signal hit()
        width: card.t.px(big ? 44 : 34); height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: big ? card.t.text : (ma.containsMouse && can ? card.t.inkA(0.08) : "transparent")
        opacity: can ? 1 : 0.35
        scale: ma.pressed && can ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        Accessible.role: Accessible.Button
        Accessible.name: name
        JText {
          anchors.centerIn: parent
          t: card.t
          text: ctl.glyph
          size: ctl.big ? 18 : 15
          color: ctl.big ? card.t.base : card.t.text
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: ctl.can ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (ctl.can) ctl.hit() }
      }

      Ctl { glyph: String.fromCodePoint(0xF04AE); name: "Previous"; can: !!card.track && card.track.prev; onHit: card.back() }
      Ctl { big: true; glyph: card.track && card.track.playing ? String.fromCodePoint(0xF03E4) : String.fromCodePoint(0xF040A)
            name: card.track && card.track.playing ? "Pause" : "Play"; onHit: card.toggle() }
      Ctl { glyph: String.fromCodePoint(0xF04AD); name: "Next"; can: !!card.track && card.track.next; onHit: card.skip() }
    }
  }

  // ---- nothing playing ----------------------------------------------------------
  Column {
    anchors.centerIn: parent
    width: parent.width
    spacing: card.t.px(10)
    visible: !body.visible
    opacity: card.ease(card.progress * 1.4)
    JText {
      anchors.horizontalCenter: parent.horizontalCenter
      t: card.t
      text: String.fromCodePoint(0xF075A)
      size: 22
      color: card.t.textFaint
    }
    JText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      t: card.t
      text: !card.checked ? "" : !card.installed ? "Spotify isn't installed" : card.player ? "Nothing playing" : "Spotify isn't open"
      size: 11
      color: card.t.textDim
      wrapMode: Text.WordWrap
    }
    SButton {
      anchors.horizontalCenter: parent.horizontalCenter
      t: card.t
      visible: card.checked && (!card.installed || !card.player)
      kind: "primary"
      label: card.installed ? "Open Spotify" : "Install Spotify"
      onClicked: card.installed ? card.openSpotify() : card.install()
    }
    SButton {
      anchors.horizontalCenter: parent.horizontalCenter
      t: card.t
      visible: card.checked && !!card.player && card.player.canPlay
      label: "Play"
      onClicked: card.player.play()
    }
  }
}
