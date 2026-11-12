# Jarvis

**[Install](#install)** · [Set it up](#set-it-up) · [Keys](#use) · [Privacy](#privacy)

A home screen for [Omarchy](https://omarchy.org) that lives on workspace 1:
screen time, tasks, live stocks, weather, your email, Govee lamps and air
purifier, Discord, an exercise coach that nudges you off doomscrolling, and a
bar along the bottom for asking Claude or Codex, by typing or by voice. It runs
inside the Omarchy shell as the `ynnad.jarvis` plugin.

![Jarvis home screen](docs/home-flat.png)

| Tasks | Stocks | Settings |
|---|---|---|
| ![Tasks](docs/tasks.png) | ![Stocks](docs/stocks.png) | ![Settings](docs/settings.png) |

Nine styles, switchable in Settings, with your own colors on top: flat, glass,
neumorphism, claymorphism, Y2K, Swiss, wabi-sabi, **Omarchy** (matches your
desktop: your Omarchy theme's colors, font, corners and wallpaper, and follows
theme changes) and **Discord** (Discord's dark theme, embeds and all).

![All nine styles](docs/styles.jpg)

![Jarvis in the Y2K style](docs/home-y2k.png)

Screenshots use made-up demo data. **Not finished yet**, and labeled as such
on screen: the calendar (only tasks show on Today).

## Install

You need [Omarchy](https://omarchy.org); everything else Jarvis uses comes with
it. Open a terminal (Super+Enter) and run:

```bash
omarchy plugin add https://github.com/Ynnad242/omarchy-dashboard --enable
```

Omarchy asks you to confirm, since this is code from outside Omarchy; answer
yes. Jarvis opens and moves itself to workspace 1, where it stays. Press
**Super+1** to get to it.

That's the only command. Everything else is in Jarvis's Settings (press **4**).

## Set it up

Nothing here needs a terminal or a config file: you sign in, or click Allow.
Cards for things you haven't set up yet say what's missing and where to go.

**Settings → General**
- Your name, 12- or 24-hour clock, the exercise coach.
- **Shortcut**: one click adds Super+Shift+J to jump to Jarvis from anywhere
  (only if that key is free on your computer).
- **Online services**: a switch for each one Jarvis talks to (see Privacy).

**Settings → Accounts**
- **AI assistant**: pick Claude or Codex and click *Sign in*. Omarchy's own
  sign-in opens (it may open your browser); Jarvis notices when you're done.
  Claude runs with every tool switched off, so it can only answer; Codex runs
  read-only in an empty folder. For voice, Jarvis uses Omarchy's dictation tool
  (Voxtype); if it isn't installed yet, clicking the mic opens its installer.
- **Email**: pick Gmail, iCloud, Yahoo, Fastmail or Other, follow the link to
  make an app password, and sign in with your address and that password. It's
  checked with your mail server, then kept in your system keyring. Read-only:
  Jarvis never marks mail as read, moves or sends anything. (Outlook and
  Hotmail only allow Microsoft's own sign-in, so they aren't supported yet.)
- **Govee**: lamps are found on your network automatically. If none show up,
  turn on *LAN Control* for each light in the Govee Home app, then click
  *Allow lamps through the firewall* (asks for your password once). For the air
  purifier, paste the free API key from the Govee Home app (Profile → Settings
  → Apply for API Key); it's checked with Govee before it's saved.

**Settings → Dashboard**: switch off any card you don't want, and the rest of
Home fills the space. No Govee devices? Switch off *Home*. Don't follow
stocks? Switch off the watchlist and the Stocks page. Hidden cards also stop
their background work.

**Settings → Look**: the nine styles, your own colors, and themes you save.

**Discord** pings and DMs come from Discord's desktop notifications (Discord →
User Settings → Notifications → Enable Desktop Notifications). The live voice
strip needs the [ynnad.discord-stream](https://github.com/Ynnad242/omarchy-discord-overlay)
overlay, which shares its voice state with Jarvis and hides its floating
widgets while Jarvis is on screen.

**Exercise coach**: on by default. After 15 minutes on YouTube, TikTok,
Instagram, Reddit, X, Facebook, Twitch or Snapchat you get one notification and
a short upper-body set to do; nothing is ever locked. When you've done it, hold
*Done* and it goes away.

## Use

| Key | Does |
|---|---|
| Super+1, or your shortcut | Go to Jarvis |
| 1 2 3 4 | Home, Tasks, Stocks, Settings |
| Esc | Back to Home |
| / | Type a question for the assistant |
| V | Ask by voice (press again to send) |
| T | Add a task |
| S | Search stocks |
| Tab, Space, arrows | Move between and change controls in Settings |

Under Settings → Look, **Presets** are the nine built-in looks and **Yours**
holds themes you save: pick a preset, change any colors, then "Save current" (or
"Save as theme" on the Colors card) to switch back to it any time. Saved themes
stay on your computer.

## Update

Jarvis updates itself. It checks GitHub when it starts and every 6 hours, and
installs a new version right away at start, or later once you leave workspace
1, then tells you with a notification. Settings → General shows your version,
has an *Update* button, and lets you turn automatic updates off. Updates go
through `omarchy plugin update`, which checks the new files and keeps the old
version if anything is wrong. If you edited Jarvis's files yourself, it won't
overwrite them.

## Uninstall

```bash
omarchy plugin remove ynnad.jarvis
```

If you added the shortcut, delete the Jarvis line at the end of
`~/.config/hypr/bindings.lua`. To remove your Jarvis data too (tasks, screen
time, settings), sign out of email under Settings → Accounts first (that clears
its keyring entry), then:

```bash
rm -rf ~/.local/state/jarvis ~/.config/jarvis
```

## Privacy

Everything Jarvis records stays on this computer. There is no Jarvis account,
no analytics and no tracking; the only things sent anywhere are listed under
online services below.

**Stored locally**

| File | What |
|---|---|
| `~/.local/state/jarvis/screentime.json` | Seconds per app (or known site, like YouTube) per day, last 60 days |
| `~/.local/state/jarvis/coach.json` | The exercise coach's meter, current challenge, sets done today |
| `~/.local/state/jarvis/todos.json` | Your tasks |
| `~/.local/state/jarvis/weather.json`, `home.json` | Caches of the last weather and lamp/purifier state |
| `~/.config/jarvis/settings.json`, `look.json`, `coach.json`, `stocks.json` | Your settings, style, saved themes and watchlist |
| `~/.config/jarvis/govee.json` | Your Govee API key (readable only by you) |
| `~/.config/jarvis/mail.json` | Your email address and mail server (readable only by you); the password is in the system keyring, not here |

Screen time records the focused app's name. For browsers it records only which
known site the tab is on (YouTube, GitHub, ...), not page titles; Steam games
are recorded by their window title, which is the game's name.

**Read locally, never stored or sent**

- Omarchy's notification history, filtered to Discord, for pings and DMs.
- Your Discord voice channel, shared by the `ynnad.discord-stream` overlay
  through `$XDG_RUNTIME_DIR/discord-voice.json` (memory only).
- CPU, memory and disk usage from `/proc` and `df`.

**Online services** (only while workspace 1 is on screen, and the AI assistant
only when you ask it something; each can be switched off in Settings)

| Service | Sent | Why |
|---|---|---|
| Yahoo Finance (`query1.finance.yahoo.com`) | Your watchlist symbols and searches | Prices and charts. Unofficial public endpoints, no key. |
| Open-Meteo (`api.open-meteo.com`) | Rough coordinates | Weather. |
| geo.omarchy.org | Your IP address (as with any request) | Your rough location, if none is saved in Omarchy's weather settings. Same source as Omarchy's weather panel. |
| Govee cloud (`openapi.api.govee.com`) | Your API key, device IDs, commands | The air purifier. Lamps use the local network only. |
| Your mail server (e.g. `imap.gmail.com`) | Your address and app password, over TLS | Unread email, read-only. Only after you sign in. |
| Anthropic (Claude) or OpenAI (Codex), through their command-line tools | Your question, the last few turns of the chat, and a short summary of the dashboard (your name, open tasks, today's screen time and top apps, weather, watchlist prices) | Answers in the bar along the bottom. Only when you ask something. Your account's terms apply. |

**Delete your data**: Settings → General → hold "Erase" removes screen
time, coach history and caches. To remove everything, delete
`~/.local/state/jarvis` and `~/.config/jarvis`.

## Security

- **No secrets in files you'd share.** The email password lives in your system
  keyring; the Govee key in `~/.config/jarvis/govee.json`, readable only by
  you; Jarvis's folders are private to you (`chmod 700`). Nothing secret is
  in this repository or its history.
- **Nothing you type reaches a shell.** Questions, addresses and keys go to the
  helpers as arguments or on stdin, never pasted into a command line. Text from
  outside (email, Discord, stock names) is always shown as plain text.
- **No server.** Jarvis listens on nothing except UDP 4002 for your lamps'
  replies, and only accepts those from private addresses, about the sender
  itself, up to 32 lamps.
- **Everything online uses HTTPS** (IMAP over TLS), with size limits on
  replies and timeouts. Purifier commands are spaced out, and sign-in retries
  back off after a failure so your mail provider doesn't lock you out.
- **The AI can't act.** Claude runs with every tool switched off; Codex runs
  in a read-only sandbox in an empty folder. They get only the summary listed
  under Privacy, never your email.
- **Links** Jarvis opens are `https://` pages only.
- Like any shell plugin, Jarvis's functions can be called by other programs
  running as you (`omarchy-shell shell call`); those programs could already
  read and change your files, so this isn't a boundary.

Found a problem? Open an issue on GitHub.


With each style's default colors, text meets WCAG AA contrast (4.5:1) on cards; controls in
Settings work from the keyboard, and controls carry names for screen readers.
Most motion follows Omarchy's animation setting (`omarchy toggle animations`).

## Licenses

Jarvis's code is MIT licensed (see `LICENSE`). It bundles no fonts or images;
it uses fonts already on the system: Adwaita Sans (SIL OFL 1.1), JetBrainsMono
Nerd Font (SIL OFL 1.1, icons MIT/OFL), Liberation Sans (SIL OFL 1.1), C059 (URW base35,
AGPL-3.0 with font exception). Data from Yahoo Finance, Open-Meteo and Govee
is subject to their own terms; Jarvis is for personal use. Stock data comes
from Yahoo Finance's public, unofficial endpoints, which can change or stop
working without notice.

Jarvis is not affiliated with or endorsed by Discord, Govee, Yahoo, Open-Meteo
or Omarchy.

## Development

- `JARVIS_DEMO=1` in the shell's environment shows made-up data everywhere and
  saves nothing (used for the screenshots).
- `JARVIS_STYLE=glass` (etc.) forces a style.
- `omarchy-shell shell call ynnad.jarvis setPage 2` opens a page;
  `omarchy-shell shell call ynnad.jarvis testCoach ''` fires an exercise
  challenge, and `testCoachClear` clears it.
