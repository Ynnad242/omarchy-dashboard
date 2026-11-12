#!/usr/bin/env python3
"""Keep Jarvis up to date from GitHub, printing one JSON line.

  update.py check   is there a newer version on GitHub?
  update.py apply   update now (through `omarchy plugin update`, which checks
                    the new files and rolls back if they're broken)

Jarvis is installed by `omarchy plugin add`, which makes the plugin folder a
git checkout of the repository. Updates only ever fast-forward to what's on
GitHub; if the folder has local edits or its own commits, nothing is touched.
The result of the last apply is kept in ~/.local/state/jarvis/update.json, so
Jarvis can say how it went after it reloads.
"""

import json
import os
import subprocess
import sys
import time

DIR = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(os.path.expanduser("~"), ".local", "state", "jarvis", "update.json")
ENV = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_SSH_COMMAND=os.environ.get("GIT_SSH_COMMAND", "ssh -oBatchMode=yes"),
           LC_ALL="C")


def out(**kw):
    print(json.dumps(kw), flush=True)


def git(*args, timeout=30):
    r = subprocess.run(["git", "-C", DIR, *args], capture_output=True, text=True, env=ENV, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip().splitlines()[-1:] or ["git failed"])
    return r.stdout


def manifest(text):
    try:
        m = json.loads(text)
        return str(m.get("version", "")), str(m.get("id", "ynnad.jarvis"))
    except ValueError:
        return "", "ynnad.jarvis"


def current():
    try:
        with open(os.path.join(DIR, "manifest.json")) as f:
            return manifest(f.read())
    except OSError:
        return "", "ynnad.jarvis"


def last_apply():
    try:
        with open(STATE) as f:
            j = json.load(f)
        return j if isinstance(j, dict) else {}
    except (OSError, ValueError):
        return {}


def save_apply(**kw):
    os.makedirs(os.path.dirname(STATE), mode=0o700, exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(kw, f)
    os.replace(tmp, STATE)


def friendly(e):
    s = str(e).lower()
    if "could not resolve" in s or "unable to access" in s or "network" in s or "timed out" in s or "timeout" in s:
        return "Can't reach GitHub right now"
    return "Couldn't check for updates"


def check():
    """Fetch and compare. Returns a dict describing what an update would do."""
    ver, pid = current()
    base = {"current": ver, "id": pid, "checked": int(time.time() * 1000), "last": last_apply()}
    if not os.path.isdir(os.path.join(DIR, ".git")):
        return dict(base, status="nogit", available=False,
                    error="Installed without git, so it can't update itself. Reinstall with omarchy plugin add.")
    try:
        git("fetch", "--quiet", "origin", "HEAD", timeout=40)
        head = git("rev-parse", "HEAD").strip()
        new = git("rev-parse", "FETCH_HEAD").strip()
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as e:
        return dict(base, status="error", available=False, error=friendly(e))
    if head == new:
        return dict(base, status="current", available=False, latest=ver)
    latest, _ = manifest(git("show", "FETCH_HEAD:manifest.json"))
    notes = [s for s in git("log", "--format=%s", "-n", "6", "HEAD..FETCH_HEAD").splitlines() if s.strip()]
    ancestor = subprocess.run(["git", "-C", DIR, "merge-base", "--is-ancestor", "HEAD", "FETCH_HEAD"], env=ENV).returncode == 0
    if not ancestor:
        # Our own commits that GitHub doesn't have (a developer's checkout).
        return dict(base, status="local", available=False, latest=latest or ver,
                    error="This copy has its own changes, so it isn't updated automatically")
    if git("status", "--porcelain", "--untracked-files=no").strip():
        return dict(base, status="local", available=True, canApply=False, latest=latest or ver, notes=notes,
                    error="Files in the Jarvis folder were edited, so it can't update safely")
    return dict(base, status="available", available=True, canApply=True, latest=latest or ver, notes=notes)


def apply():
    c = check()
    if not c.get("canApply"):
        out(**c)
        return
    before = c["current"]
    r = subprocess.run(["omarchy-plugin-update", c["id"], "--yes"], capture_output=True, text=True, env=ENV, timeout=180)
    ok = r.returncode == 0
    after, _ = current()
    err = "" if ok else ((r.stderr or r.stdout).strip().splitlines() or ["Update failed"])[-1]
    if "rolled back" in err:
        err = "The new version didn't pass Omarchy's checks, so the old one was kept"
    elif not ok:
        err = "Update failed: " + err.replace("omarchy-plugin-update: ", "")
    save_apply(ok=ok, before=before, after=after if ok else before, error=err, at=int(time.time() * 1000), seen=False,
               notes=c.get("notes", []) if ok else [])
    out(status="updated" if ok else "error", available=not ok, current=after, latest=c.get("latest"), error=err)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    try:
        if cmd == "check":
            out(**check())
        elif cmd == "apply":
            apply()
        else:
            out(status="error", error="unknown command")
            sys.exit(2)
    except Exception as e:  # never crash without a JSON line Jarvis can show
        out(status="error", available=False, current=current()[0], error=friendly(e))


if __name__ == "__main__":
    main()
