import QtQuick
import qs.Commons

// Settings > Accounts: everything that needs a sign-in or a permission, set
// up right here. Nothing to type in a terminal and no files to edit.
//   AI assistant  Claude or Codex, through Omarchy's own sign-in
//   Email         an address and an app password (kept in the keyring)
//   Govee         let the lamps through the firewall; the purifier's API key
// `app` is Jarvis.qml, which does the work; demo mode shows made-up accounts.
Item {
  id: pane

  property var t
  property var app
  property bool shown: false
  readonly property bool demo: app ? app.demo : false
  readonly property real gap: t.px(18)
  readonly property real colW: (width - gap * 2) / 3

  onShownChanged: if (shown && app && !demo) { app.checkAgents() }

  readonly property var agents: demo
    ? ({ claude: { installed: true, signedIn: true, plan: "Pro", email: "alex@example.com" }, codex: { installed: true, signedIn: false }, checked: true })
    : (app ? app.agents : ({}))
  readonly property var mail: demo ? ({ status: "off" }) : (app ? app.mail : ({}))
  readonly property var home: demo ? (app ? app.demoHome : ({})) : (app ? app.home : ({}))
  readonly property string provider: demo ? "claude" : (app ? app.aiProvider : "claude")

  component Status: JText {
    width: parent ? parent.width : 0
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    size: 11
    lineHeight: 1.2
  }
  component Heading: JText {
    width: parent ? parent.width : 0
    size: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 0.4
    color: pane.t.textFaint
  }
  component Link: JText {
    id: lk
    property string url: ""
    size: 11
    color: pane.t.accent
    font.underline: lkArea.containsMouse
    MouseArea { id: lkArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (/^https:\/\//.test(lk.url)) Qt.openUrlExternally(lk.url) }
  }

  // ---- AI assistant -----------------------------------------------------------
  GlassCard {
    id: aiCard
    t: pane.t
    shown: pane.shown
    order: 1
    hoverable: false
    width: pane.colW
    height: pane.height
    title: "AI assistant"

    Flickable {
      anchors.fill: parent
      contentHeight: aiCol.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: aiCol
        width: parent.width
        spacing: pane.t.px(10)

        Status {
          t: pane.t
          text: "Answers questions in the bar along the bottom, by typing or by voice. It uses the account you already have; there's no API key to set up."
          color: pane.t.textDim
        }
        SRow {
          t: pane.t
          label: "Answer with"
          Segmented {
            t: pane.t
            slotW: pane.t.px(70)
            options: [{ key: "claude", label: "Claude" }, { key: "codex", label: "Codex" }, { key: "off", label: "Off" }]
            current: pane.provider
            onPicked: function(k) { if (pane.app && !pane.demo) pane.app.setSetting("ai", k) }
          }
        }

        Repeater {
          model: [{ key: "claude", name: "Claude", by: "Anthropic", note: "Runs with every tool switched off, so it can only answer." },
                  { key: "codex", name: "Codex", by: "OpenAI", note: "Runs read-only in an empty folder and is told to only answer." }]
          Rectangle {
            id: acct
            required property var modelData
            readonly property var a: (pane.agents || {})[modelData.key] || ({})
            readonly property bool picked: pane.provider === modelData.key
            width: aiCol.width
            height: acctCol.height + pane.t.px(22)
            radius: pane.t.radiusSmall
            color: picked ? pane.t.inkA(0.05) : "transparent"
            border.width: 1
            border.color: picked ? pane.t.alpha(pane.t.accent, 0.5) : pane.t.inkA(0.10)
            Column {
              id: acctCol
              x: pane.t.px(12); y: pane.t.px(11)
              width: parent.width - pane.t.px(24) - btn.width - pane.t.px(10)
              spacing: pane.t.px(3)
              JText { t: pane.t; text: acct.modelData.name + "  ·  " + acct.modelData.by; size: 12.5; font.weight: Font.DemiBold }
              Status {
                t: pane.t
                text: !pane.agents.checked ? "Checking…"
                    : !acct.a.installed ? "Not installed on this computer."
                    : acct.a.signedIn ? "Signed in" + (acct.a.plan ? "  ·  " + acct.a.plan + " plan" : "") + (acct.a.email ? "  ·  " + acct.a.email : "")
                    : "Not signed in yet."
                color: acct.a.signedIn ? pane.t.green : pane.t.textDim
              }
              Status { t: pane.t; text: acct.modelData.note; size: 10.5; color: pane.t.textFaint }
            }
            SButton {
              id: btn
              t: pane.t
              anchors.right: parent.right
              anchors.rightMargin: pane.t.px(12)
              anchors.verticalCenter: parent.verticalCenter
              visible: pane.agents.checked && acct.a.installed && !acct.a.signedIn
              kind: acct.picked ? "primary" : "plain"
              label: "Sign in"
              busy: pane.app && pane.app.signingInUntil > 0
              busyLabel: "Waiting…"
              onClicked: if (pane.app && !pane.demo) pane.app.signInAgent(acct.modelData.key)
            }
          }
        }
        Status {
          t: pane.t
          visible: pane.app && pane.app.signingInUntil > 0
          text: "Finish signing in in the window that opened (it may open your browser). This updates by itself."
          color: pane.t.textDim
        }
        Status {
          t: pane.t
          text: "Only when you ask something: your question, the last few messages of the chat, and a short summary of the dashboard (name, open tasks, today's screen time, weather, watchlist) go to the assistant you picked."
          size: 10.5
          color: pane.t.textFaint
        }
      }
    }
  }

  // ---- Email ------------------------------------------------------------------
  property string mailProvider: "gmail"
  readonly property var mailHelp: ({
    gmail: { name: "Gmail", url: "https://myaccount.google.com/apppasswords", first: "https://myaccount.google.com/signinoptions/twosv",
             steps: "Turn on 2-Step Verification first (Google hides app passwords until you do), then create an app password named Jarvis and paste the 16 letters below. Work or school accounts may not allow this." },
    icloud: { name: "iCloud", url: "https://account.apple.com/account/manage", steps: "Sign-In and Security → App-Specific Passwords → create one named Jarvis." },
    yahoo: { name: "Yahoo", url: "https://login.yahoo.com/account/security", steps: "Account security → Generate app password → name it Jarvis." },
    fastmail: { name: "Fastmail", url: "https://app.fastmail.com/settings/security/apps", steps: "Settings → Privacy & Security → Manage app passwords → New, with IMAP access." },
    other: { name: "Other", url: "", steps: "Use your provider's IMAP server and, if it offers one, an app password instead of your main password." }
  })
  GlassCard {
    id: mailCard
    t: pane.t
    shown: pane.shown
    order: 2
    hoverable: false
    x: pane.colW + pane.gap
    width: pane.colW
    height: pane.height
    title: "Email"

    Flickable {
      anchors.fill: parent
      contentHeight: mailCol.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: mailCol
        width: parent.width
        spacing: pane.t.px(10)

        // Signed in
        Column {
          visible: pane.mail.status && pane.mail.status !== "off"
          width: parent.width
          spacing: pane.t.px(8)
          Status {
            t: pane.t
            text: (pane.mail.providerName || "Email") + "  ·  " + (pane.mail.address || "")
            size: 12.5
            font.weight: Font.DemiBold
            color: pane.t.text
          }
          Status {
            t: pane.t
            text: pane.mail.status === "ok" ? "Connected  ·  " + (pane.mail.unread || 0) + " unread"
                : pane.mail.status === "nopassword" ? "The saved password is missing. Sign out and sign in again."
                : "Can't check email: " + (pane.mail.error || "unknown error")
            color: pane.mail.status === "ok" ? pane.t.green : pane.t.red
          }
          Row {
            spacing: pane.t.px(8)
            SButton { t: pane.t; label: "Open inbox"; visible: !!pane.app && pane.app.safeUrl(pane.mail.web); onClicked: Qt.openUrlExternally(pane.mail.web) }
            SButton { t: pane.t; label: "Sign out"; kind: "danger"; onClicked: if (pane.app) pane.app.signOutMail() }
          }
          Status {
            t: pane.t
            text: "Read-only: Jarvis never marks mail as read, moves or sends anything. The password is kept in your system keyring."
            size: 10.5
            color: pane.t.textFaint
          }
        }

        // Signing in
        Column {
          visible: !pane.mail.status || pane.mail.status === "off"
          width: parent.width
          spacing: pane.t.px(10)

          Status {
            t: pane.t
            text: "Shows unread email from people on Home, and which ones need a reply. Read-only."
            color: pane.t.textDim
          }
          Segmented {
            t: pane.t
            slotW: Math.min(pane.t.px(66), (mailCol.width - pane.t.px(8)) / 5)
            options: [{ key: "gmail", label: "Gmail" }, { key: "icloud", label: "iCloud" }, { key: "yahoo", label: "Yahoo" },
                      { key: "fastmail", label: "Fastmail" }, { key: "other", label: "Other" }]
            current: pane.mailProvider
            onPicked: function(k) { pane.mailProvider = k }
          }
          Status {
            t: pane.t
            text: "1. " + pane.mailHelp[pane.mailProvider].steps
            color: pane.t.textDim
          }
          Link {
            t: pane.t
            visible: !!pane.mailHelp[pane.mailProvider].first
            text: "Turn on 2-Step Verification  ↗"
            url: pane.mailHelp[pane.mailProvider].first || ""
          }
          Link {
            t: pane.t
            visible: pane.mailHelp[pane.mailProvider].url.length > 0
            text: "Open " + pane.mailHelp[pane.mailProvider].name + "'s app password page  ↗"
            url: pane.mailHelp[pane.mailProvider].url
          }
          Status { t: pane.t; text: "2. Enter your address and that app password:"; color: pane.t.textDim }
          SField { id: mailAddr; t: pane.t; width: parent.width; placeholder: "you@" + (pane.mailProvider === "gmail" ? "gmail.com" : pane.mailProvider === "icloud" ? "icloud.com" : pane.mailProvider === "yahoo" ? "yahoo.com" : "example.com"); accessibleName: "Email address" }
          SField { id: mailPass; t: pane.t; width: parent.width; secret: true; placeholder: "App password"; accessibleName: "App password"; onAccepted: mailGo.clicked() }
          Row {
            visible: pane.mailProvider === "other"
            spacing: pane.t.px(8)
            SField { id: mailHost; t: pane.t; width: mailCol.width - mailPort.width - pane.t.px(8); placeholder: "IMAP server, e.g. imap.example.com"; accessibleName: "IMAP server" }
            SField { id: mailPort; t: pane.t; width: pane.t.px(70); placeholder: "993"; accessibleName: "Port"; maxLength: 5 }
          }
          Row {
            spacing: pane.t.px(10)
            SButton {
              id: mailGo
              t: pane.t
              kind: "primary"
              busy: pane.app && pane.app.mailLogin.busy
              busyLabel: "Checking…"
              enabled: mailAddr.text.length > 3 && mailPass.text.length > 0 && !pane.demo && pane.app.waitFor("mail") === 0
              label: pane.app && pane.app.waitFor("mail") > 0 ? "Try again in " + pane.app.waitFor("mail") + "s" : "Sign in"
              onClicked: {
                if (!pane.app) return
                pane.app.signInMail({ provider: pane.mailProvider, address: mailAddr.text.trim(), password: mailPass.text,
                                      host: mailHost.text.trim(), port: parseInt(mailPort.text) || 993,
                                      security: (parseInt(mailPort.text) || 993) === 993 ? "ssl" : "starttls" })
              }
            }
          }
          Status {
            t: pane.t
            visible: pane.app && !!pane.app.mailLogin.error
            text: pane.app ? "Couldn't sign in: " + pane.app.mailLogin.error + "." : ""
            color: pane.t.red
          }
          Status {
            t: pane.t
            text: "The password is checked with your mail server, then kept in your system keyring, not in a file. Outlook and Hotmail only allow Microsoft's own sign-in, so they aren't supported yet."
            size: 10.5
            color: pane.t.textFaint
          }
        }
      }
    }
    // Clear the password field once it's been used.
    Connections {
      target: pane.app
      ignoreUnknownSignals: true
      function onMailLoginChanged() { if (pane.app && pane.app.mailLogin.ok) { mailPass.clear(); mailAddr.clear() } }
    }
  }

  // ---- Govee ------------------------------------------------------------------
  GlassCard {
    id: goveeCard
    t: pane.t
    shown: pane.shown
    order: 3
    hoverable: false
    x: (pane.colW + pane.gap) * 2
    width: pane.width - x
    height: pane.height
    title: "Govee lamps and purifier"

    Flickable {
      anchors.fill: parent
      contentHeight: gCol.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: gCol
        width: parent.width
        spacing: pane.t.px(10)

        Status {
          t: pane.t
          visible: pane.app && !pane.app.shows("home")
          text: "The Home card is hidden (Settings → Dashboard), so Jarvis isn't looking for lamps."
          color: pane.t.yellow
        }

        Heading { t: pane.t; text: "LAMPS  (YOUR NETWORK, NO ACCOUNT)" }
        readonly property int lampCount: (pane.home.lights || []).length
        Status {
          t: pane.t
          text: gCol.lampCount > 0 ? gCol.lampCount + (gCol.lampCount === 1 ? " lamp" : " lamps") + " found. You're all set."
              : "No lamps found yet. Two things to check:"
          color: gCol.lampCount > 0 ? pane.t.green : pane.t.textDim
        }
        Status {
          t: pane.t
          visible: gCol.lampCount === 0
          text: "1. In the Govee Home app, open each light → Settings → turn on LAN Control.\n2. Let the lamps answer through Omarchy's firewall (asks for your password once):"
          color: pane.t.textDim
        }
        SButton {
          t: pane.t
          visible: gCol.lampCount === 0
          kind: "primary"
          label: pane.app && pane.app.lampsAllow.ok ? "Allowed  ✓" : "Allow lamps through the firewall"
          busy: pane.app && pane.app.lampsAllow.busy
          busyLabel: "Waiting for permission…"
          enabled: !pane.demo && !(pane.app && pane.app.lampsAllow.ok)
          onClicked: if (pane.app) pane.app.allowLamps()
        }
        Status {
          t: pane.t
          visible: pane.app && (pane.app.lampsAllow.ok || !!pane.app.lampsAllow.error)
          text: !pane.app ? "" : pane.app.lampsAllow.ok ? "Done: lamps on " + pane.app.lampsAllow.range + " can answer now. Looking for them…"
              : "Couldn't add the rule: " + pane.app.lampsAllow.error + "."
          color: pane.app && pane.app.lampsAllow.ok ? pane.t.green : pane.t.red
        }

        Item { width: 1; height: pane.t.px(4) }
        Heading { t: pane.t; text: "AIR PURIFIER  (GOVEE CLOUD)" }
        Status {
          t: pane.t
          text: pane.home.cloud === "ok" ? "Connected  ·  " + ((pane.home.purifiers || []).length || "no") + " purifier" + ((pane.home.purifiers || []).length === 1 ? "" : "s") + " on your account."
              : pane.home.cloud === "disabled" ? "Switched off under General → Online services."
              : pane.home.cloud === "error" ? "Govee: " + (pane.home.error || "not answering")
              : "Needs a free API key from the Govee Home app: Profile → Settings → Apply for API Key. It arrives by email; paste it here."
          color: pane.home.cloud === "ok" ? pane.t.green : pane.home.cloud === "error" ? pane.t.red : pane.t.textDim
        }
        Row {
          visible: pane.home.cloud !== "ok" && pane.home.cloud !== "disabled"
          spacing: pane.t.px(8)
          SField { id: gKey; t: pane.t; width: gCol.width - gSave.width - pane.t.px(8); secret: true; placeholder: "Govee API key"; accessibleName: "Govee API key"; onAccepted: gSave.clicked() }
          SButton {
            id: gSave
            t: pane.t
            kind: "primary"
            label: "Save"
            busy: pane.app && pane.app.goveeKey.busy
            busyLabel: "Checking…"
            enabled: gKey.text.trim().length > 7 && !pane.demo && pane.app.waitFor("govee") === 0
            onClicked: if (pane.app) pane.app.saveGoveeKey(gKey.text)
          }
        }
        Status {
          t: pane.t
          visible: pane.app && !!pane.app.goveeKey.error
          text: pane.app ? "Couldn't save the key: " + pane.app.goveeKey.error + "." : ""
          color: pane.t.red
        }
        SButton {
          t: pane.t
          visible: pane.home.cloud === "ok" && !pane.demo
          kind: "danger"
          label: "Remove API key"
          onClicked: if (pane.app) pane.app.clearGoveeKey()
        }
        Status {
          t: pane.t
          text: "The key is checked with Govee before it's saved, and stays on this computer, readable only by you. No Govee devices? Hide the card under Dashboard."
          size: 10.5
          color: pane.t.textFaint
        }
        Connections {
          target: pane.app
          ignoreUnknownSignals: true
          function onGoveeKeyChanged() { if (pane.app && pane.app.goveeKey.ok) gKey.clear() }
        }
      }
    }
  }
}
