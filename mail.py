#!/usr/bin/env python3
"""Jarvis mail: your recent important email over IMAP, read-only.

  mail.py login     sign in; reads {"provider", "address", "password",
                    "host", "port", "security"} as JSON on stdin, checks it
                    against the server, then keeps the password in the system
                    keyring (Secret Service, via secret-tool) and the rest in
                    ~/.config/jarvis/mail.json. Prints one JSON line.
  mail.py logout    forget the account and its password.
  mail.py serve     JSON lines on stdout, a refresh every 2 minutes and on
                    "refresh" from stdin.
  mail.py once      one fetch, printed.

The mailbox is opened read-only, so nothing is ever marked as read, moved or
sent. Only Python's standard library and secret-tool are used.
"""

import email
import email.header
import email.policy
import email.utils
import html
import imaplib
import json
import os
import re
import socket
import ssl
import subprocess
import sys
import threading
import time

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config", "jarvis", "mail.json")
SERVICE = "jarvis-mail"
EVERY = 120
TIMEOUT = 20

# Providers that still allow IMAP with an app password. Outlook.com and
# Microsoft 365 only allow OAuth now, so they aren't offered.
PROVIDERS = {
    "gmail": {"name": "Gmail", "host": "imap.gmail.com", "port": 993, "security": "ssl",
              "web": "https://mail.google.com/mail/u/0/#inbox"},
    "icloud": {"name": "iCloud Mail", "host": "imap.mail.me.com", "port": 993, "security": "ssl",
               "web": "https://www.icloud.com/mail"},
    "yahoo": {"name": "Yahoo Mail", "host": "imap.mail.yahoo.com", "port": 993, "security": "ssl",
              "web": "https://mail.yahoo.com/"},
    "fastmail": {"name": "Fastmail", "host": "imap.fastmail.com", "port": 993, "security": "ssl",
                 "web": "https://app.fastmail.com/mail/Inbox/"},
    "other": {"name": "Email", "host": "", "port": 993, "security": "ssl", "web": ""},
}

AUTOMATED = re.compile(r"(^|[.\-_+])(no-?reply|do-?not-?reply|notifications?|notify|mailer-daemon|postmaster|"
                       r"bounce|alerts?|updates?|news(letter)?|marketing|support|billing|receipts?|info)([.\-_+@]|$)", re.I)


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def load_config():
    try:
        with open(CONFIG) as f:
            c = json.load(f)
        return c if isinstance(c, dict) and c.get("address") and c.get("host") else None
    except (OSError, ValueError):
        return None


def save_config(c):
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    tmp = CONFIG + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(c, f, indent=2)
        f.write("\n")
    os.replace(tmp, CONFIG)


def keyring_get(address):
    try:
        r = subprocess.run(["secret-tool", "lookup", "service", SERVICE, "account", address],
                           capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 and r.stdout else None


def keyring_set(address, password):
    r = subprocess.run(["secret-tool", "store", "--label", "Jarvis mail (%s)" % address,
                        "service", SERVICE, "account", address],
                       input=password, capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        raise RuntimeError("couldn't save the password to the keyring: " + (r.stderr.strip() or "secret-tool failed"))


def keyring_clear(address):
    subprocess.run(["secret-tool", "clear", "service", SERVICE, "account", address],
                   capture_output=True, timeout=15)


def friendly(e):
    s = str(e)
    if isinstance(e, imaplib.IMAP4.error):
        low = s.lower()
        if "auth" in low or "credentials" in low or "invalid" in low or "login" in low or "password" in low:
            return "the server didn't accept that address and app password"
        return "the mail server said: " + s[:120]
    if isinstance(e, (socket.gaierror,)):
        return "can't find that mail server (offline, or a typo in the server name?)"
    if isinstance(e, (socket.timeout, TimeoutError)):
        return "the mail server didn't answer in time"
    if isinstance(e, ssl.SSLError):
        return "couldn't make a secure connection to the mail server"
    if isinstance(e, OSError):
        return "can't reach the mail server (offline?)"
    return s[:160]


def connect(c, password):
    host, port = c["host"], int(c.get("port") or 993)
    ctx = ssl.create_default_context()
    if c.get("security") == "starttls":
        m = imaplib.IMAP4(host, port, timeout=TIMEOUT)
        m.starttls(ssl_context=ctx)
    else:
        m = imaplib.IMAP4_SSL(host, port, ssl_context=ctx, timeout=TIMEOUT)
    m.login(c["address"], password)
    return m


def decode(v):
    if not v:
        return ""
    try:
        return str(email.header.make_header(email.header.decode_header(str(v)))).strip()
    except Exception:
        return str(v).strip()


def snippet_of(msg):
    try:
        part = msg.get_body(preferencelist=("plain", "html"))
        if part is None:
            return ""
        text = part.get_content()
        if part.get_content_type() == "text/html":
            text = re.sub(r"(?is)<(script|style).*?</\1>", " ", text)
            text = html.unescape(re.sub(r"<[^>]+>", " ", text))
    except Exception:
        return ""
    lines = [l for l in text.splitlines() if l.strip() and not l.lstrip().startswith(">")]
    text = " ".join(" ".join(lines).split())
    return text[:180]


def parse_message(raw, me):
    """One message's row for the inbox card, from its raw bytes."""
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    name, addr = email.utils.parseaddr(decode(msg.get("From")))
    to = [a.lower() for _, a in email.utils.getaddresses([decode(msg.get("To"))])]
    try:
        ts = int(email.utils.parsedate_to_datetime(msg.get("Date")).timestamp())
    except Exception:
        ts = int(time.time())
    automated = bool(msg.get("List-Id") or msg.get("List-Unsubscribe")
                     or str(msg.get("Precedence", "")).lower() in ("bulk", "list", "junk")
                     or str(msg.get("Auto-Submitted", "no")).lower() != "no"
                     or AUTOMATED.search(addr.split("@")[0] if addr else ""))
    subject = decode(msg.get("Subject")) or "(no subject)"
    snip = snippet_of(msg)
    personal = not automated
    return {
        "from": name or addr or "Unknown",
        "fromAddr": addr,
        "subject": subject[:200],
        "snippet": snip,
        "ts": ts,
        "unread": True,
        "personal": personal,
        # A person writing to you directly, asking something.
        "needsReply": personal and me in to and ("?" in subject or "?" in snip),
    }


def fetch(c, password):
    m = connect(c, password)
    try:
        m.select("INBOX", readonly=True)
        typ, data = m.search(None, "UNSEEN")
        unread = len(data[0].split()) if typ == "OK" and data and data[0] else 0
        since = time.strftime("%d-%b-%Y", time.localtime(time.time() - 7 * 86400))
        if "gmail.com" in c["host"]:
            # Gmail's own sorting: unread, primary inbox, last week.
            typ, data = m.search(None, "X-GM-RAW", '"in:inbox is:unread category:primary newer_than:7d"')
        else:
            typ, data = m.search(None, "UNSEEN", "SINCE", since)
        recent_ids = data[0].split() if typ == "OK" and data and data[0] else []
        ids = recent_ids[-25:]
        me = c["address"].lower()
        out = []
        for i in reversed(ids):
            typ, parts = m.fetch(i, "(BODY.PEEK[]<0.40000>)")
            raw = next((p[1] for p in parts if isinstance(p, tuple)), None)
            if not raw:
                continue
            row = parse_message(raw, me)
            if row:
                out.append(row)
        # People first, then everything else; newest first within each.
        out.sort(key=lambda r: (not r["personal"], -r["ts"]))
        # "recent": unread from the last week (Gmail: Primary only), which says
        # more than an all-time unread count in the thousands.
        return {"unread": unread, "recent": len(recent_ids), "mails": out[:10]}
    finally:
        try:
            m.logout()
        except Exception:
            pass


def state(c, **kw):
    p = PROVIDERS.get(c.get("provider") or "other", PROVIDERS["other"]) if c else PROVIDERS["other"]
    base = {"type": "mail", "provider": (c or {}).get("provider", ""), "providerName": p["name"],
            "address": (c or {}).get("address", ""), "web": p["web"], "at": int(time.time())}
    base.update(kw)
    return base


def once():
    c = load_config()
    if not c:
        return state(None, status="off")
    pw = keyring_get(c["address"])
    if not pw:
        return state(c, status="nopassword", error="the saved password is missing; sign in again")
    try:
        return state(c, status="ok", **fetch(c, pw))
    except Exception as e:
        return state(c, status="error", error=friendly(e))


def login():
    try:
        req = json.loads(sys.stdin.readline() or "{}")
    except ValueError:
        req = {}
    provider = str(req.get("provider") or "other")
    p = PROVIDERS.get(provider, PROVIDERS["other"])
    address = str(req.get("address") or "").strip()
    password = str(req.get("password") or "").replace(" ", "") if provider == "gmail" else str(req.get("password") or "")
    c = {"provider": provider, "address": address,
         "host": str(req.get("host") or p["host"]).strip(),
         "port": int(req.get("port") or p["port"]),
         "security": "starttls" if req.get("security") == "starttls" else p["security"]}
    if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", address):
        return emit({"type": "login", "ok": False, "error": "that doesn't look like an email address"})
    if not password:
        return emit({"type": "login", "ok": False, "error": "enter the app password"})
    if not c["host"]:
        return emit({"type": "login", "ok": False, "error": "enter your mail server (IMAP)"})
    try:
        m = connect(c, password)
        m.select("INBOX", readonly=True)
        m.logout()
    except Exception as e:
        return emit({"type": "login", "ok": False, "error": friendly(e)})
    try:
        old = load_config()
        if old and old.get("address") != address:
            keyring_clear(old["address"])
        keyring_set(address, password)
        save_config(c)
    except Exception as e:
        return emit({"type": "login", "ok": False, "error": str(e)[:200]})
    emit({"type": "login", "ok": True, "address": address})


def logout():
    c = load_config()
    if c:
        keyring_clear(c["address"])
    try:
        os.remove(CONFIG)
    except OSError:
        pass
    emit({"type": "logout", "ok": True})


def serve():
    wake = threading.Event()

    def reader():
        for line in sys.stdin:
            if line.strip() == "refresh":
                wake.set()
        os._exit(0)

    threading.Thread(target=reader, daemon=True).start()
    while True:
        emit(once())
        wake.wait(EVERY)
        wake.clear()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "once"
    if cmd == "login":
        login()
    elif cmd == "logout":
        logout()
    elif cmd == "serve":
        serve()
    else:
        print(json.dumps(once(), indent=2))
