#!/usr/bin/env python3
"""Small setup steps Settings can run for you, each printing one JSON line.

  setup.py shortcut-status   is the Jarvis shortcut in bindings.lua, and is
                             Super+Shift+J free?
  setup.py shortcut-add      add Super+Shift+J to ~/.config/hypr/bindings.lua
                             (only if that key is free and it isn't there yet)
"""

import json
import os
import subprocess
import sys

BINDINGS = os.path.join(os.path.expanduser("~"), ".config", "hypr", "bindings.lua")
LINE = 'o.bind("SUPER + SHIFT + J", "Jarvis", [[omarchy-shell shell summon ynnad.jarvis \'{}\']])'
SUPER, SHIFT = 64, 1


def out(**kw):
    print(json.dumps(kw))


def ours():
    try:
        with open(BINDINGS) as f:
            return "ynnad.jarvis" in f.read()
    except OSError:
        return False


def key_taken():
    """True if Super+Shift+J already does something else."""
    try:
        binds = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=5).stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return False
    for b in binds:
        mine = "ynnad.jarvis" in str(b.get("arg", "")) or b.get("description") == "Jarvis"
        if b.get("modmask") == SUPER | SHIFT and str(b.get("key", "")).upper() == "J" and not mine:
            return True
    return False


def status():
    out(type="shortcut", added=ours(), taken=key_taken(), exists=os.path.exists(BINDINGS))


def add():
    if ours():
        return out(type="shortcut", added=True, ok=True)
    if not os.path.exists(BINDINGS):
        return out(type="shortcut", added=False, ok=False, error="couldn't find ~/.config/hypr/bindings.lua")
    if key_taken():
        return out(type="shortcut", added=False, ok=False, error="Super+Shift+J already does something else on this computer")
    with open(BINDINGS, "a") as f:
        f.write("\n-- Jarvis: jump to the dashboard (added from Jarvis's Settings).\n" + LINE + "\n")
    out(type="shortcut", added=True, ok=True)


if __name__ == "__main__":
    {"shortcut-add": add}.get(sys.argv[1] if len(sys.argv) > 1 else "", status)()
