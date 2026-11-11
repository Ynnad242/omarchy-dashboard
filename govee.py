#!/usr/bin/env python3
"""Govee bridge for the Jarvis dashboard.

Lights are driven over Govee's local LAN API (UDP, no account, no internet):
discovery on multicast 239.255.255.250:4001, commands to <light>:4003,
replies on :4002. Turn on "LAN Control" for each light in the Govee app.

Appliances (the air purifier) have no LAN API, so they go through Govee's
cloud API with the key in ~/.config/jarvis/govee.json. The key stays in this
process; the dashboard never sees it.

  govee.py serve    read JSON commands on stdin, print state as JSON lines
  govee.py scan     print the lights found on the network and exit
  govee.py cloud    print the cloud devices and their state and exit

Commands (one JSON object per line):
  {"cmd": "refresh"}
  {"cmd": "lights", "on": true}
  {"cmd": "lights", "brightness": 40}
  {"cmd": "lights", "color": [255, 120, 0]}
  {"cmd": "lights", "kelvin": 4000}
  {"cmd": "purifier", "device": "<id>", "on": false}
  {"cmd": "purifier", "device": "<id>", "mode": "<mode id>"}

Every state line looks like:
  {"type": "state", "lights": [...], "purifiers": [...], "cloud": "ok|nokey|error|off", "error": ""}
"""

import json
import math
import os
import select
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config", "jarvis", "govee.json")
STATE_FILE = os.path.join(HOME, ".local", "state", "jarvis", "home.json")

MCAST = ("239.255.255.250", 4001)
CMD_PORT = 4003
LISTEN_PORT = 4002

API = "https://openapi.api.govee.com/router/api/v1"
API_TIMEOUT = 8
API_MAX_BYTES = 1 << 20

LIGHT_SCAN_EVERY = 60
LIGHT_STATUS_EVERY = 10


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def load_config():
    try:
        with open(CONFIG) as f:
            cfg = json.load(f)
        return cfg if isinstance(cfg, dict) else {}
    except (OSError, ValueError):
        return {}


def kelvin_rgb(k):
    """Approximate the color of a white at k kelvin, for the dashboard swatch."""
    t = clamp(k, 1000, 40000) / 100.0
    if t <= 66:
        r = 255
        g = 99.4708025861 * math.log(t) - 161.1195681661
        b = 0 if t <= 19 else 138.5177312231 * math.log(t - 10) - 305.0447927307
    else:
        r = 329.698727446 * ((t - 60) ** -0.1332047592)
        g = 288.1221695283 * ((t - 60) ** -0.0755148492)
        b = 255
    return [int(clamp(r, 0, 255)), int(clamp(g, 0, 255)), int(clamp(b, 0, 255))]


# ---------------------------------------------------------------- LAN lights

class Lan:
    def __init__(self):
        self.lights = {}  # ip -> dict
        self.lock = threading.Lock()
        self.rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.rx.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.rx.bind(("", LISTEN_PORT))
        self.tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.tx.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)

    def send(self, ip, port, cmd, data):
        msg = json.dumps({"msg": {"cmd": cmd, "data": data}}).encode()
        try:
            self.tx.sendto(msg, (ip, port))
        except OSError as e:
            log("send failed", ip, e)

    def scan(self):
        self.send(MCAST[0], MCAST[1], "scan", {"account_topic": "reserve"})

    def query(self, ip=None):
        for addr in ([ip] if ip else list(self.lights)):
            self.send(addr, CMD_PORT, "devStatus", {})

    def handle(self, data, addr):
        """Fold one reply into the light table. Returns True if anything changed."""
        try:
            msg = json.loads(data.decode("utf-8", "replace"))["msg"]
            cmd, d = msg.get("cmd"), msg.get("data") or {}
        except (ValueError, KeyError, TypeError, AttributeError):
            return False
        ip = addr[0]
        with self.lock:
            if cmd == "scan":
                ip = str(d.get("ip") or ip)
                light = self.lights.setdefault(ip, {"ip": ip})
                light["sku"] = str(d.get("sku", ""))[:16]
                light["device"] = str(d.get("device", ""))[:64]
                light["seen"] = time.time()
                return True
            if cmd == "devStatus":
                light = self.lights.setdefault(ip, {"ip": ip})
                c = d.get("color") or {}
                k = int(d.get("colorTemInKelvin") or 0)
                light["on"] = bool(d.get("onOff"))
                light["brightness"] = int(clamp(int(d.get("brightness") or 0), 0, 100))
                light["kelvin"] = k
                rgb = [int(clamp(int(c.get(x) or 0), 0, 255)) for x in ("r", "g", "b")]
                light["color"] = kelvin_rgb(k) if k > 0 or rgb == [0, 0, 0] else rgb
                light["white"] = k > 0 or rgb == [0, 0, 0]
                light["seen"] = time.time()
                return True
        return False

    def drop_stale(self, age=180):
        with self.lock:
            now = time.time()
            for ip in [ip for ip, l in self.lights.items() if now - l.get("seen", now) > age]:
                del self.lights[ip]

    def snapshot(self):
        with self.lock:
            out = [{k: v for k, v in l.items() if k != "seen"} for l in self.lights.values() if "sku" in l or "on" in l]
        return sorted(out, key=lambda l: l["ip"])

    def control(self, c):
        targets = [c["ip"]] if c.get("ip") else list(self.lights)
        for ip in targets:
            if "on" in c:
                self.send(ip, CMD_PORT, "turn", {"value": 1 if c["on"] else 0})
            if "brightness" in c:
                self.send(ip, CMD_PORT, "brightness", {"value": int(clamp(int(c["brightness"]), 1, 100))})
            if "color" in c:
                r, g, b = [int(clamp(int(x), 0, 255)) for x in list(c["color"])[:3]]
                self.send(ip, CMD_PORT, "colorwc", {"color": {"r": r, "g": g, "b": b}, "colorTemInKelvin": 0})
            if "kelvin" in c:
                k = int(clamp(int(c["kelvin"]), 2000, 9000))
                r, g, b = kelvin_rgb(k)
                self.send(ip, CMD_PORT, "colorwc", {"color": {"r": r, "g": g, "b": b}, "colorTemInKelvin": k})
            # Optimistic local update so the dashboard reflects it at once.
            with self.lock:
                l = self.lights.get(ip)
                if l is not None:
                    if "on" in c: l["on"] = bool(c["on"])
                    if "brightness" in c: l["brightness"] = int(clamp(int(c["brightness"]), 1, 100))
                    if "color" in c: l["color"], l["white"], l["kelvin"] = [int(x) for x in list(c["color"])[:3]], False, 0
                    if "kelvin" in c: l["kelvin"], l["white"], l["color"] = int(c["kelvin"]), True, kelvin_rgb(int(c["kelvin"]))


# ---------------------------------------------------------- cloud appliances

class Cloud:
    def __init__(self, key):
        self.key = key
        self.devices = []  # raw device entries for purifiers
        self.names = {}  # device id -> name from the Govee app, lights included
        self.purifiers = {}  # device id -> dict for the dashboard
        self.status = "off" if not key else "ok"
        self.error = ""

    def call(self, method, path, body=None):
        req = urllib.request.Request(API + path, method=method)
        req.add_header("Govee-API-Key", self.key)
        req.add_header("Content-Type", "application/json")
        data = json.dumps(body).encode() if body is not None else None
        try:
            with urllib.request.urlopen(req, data=data, timeout=API_TIMEOUT) as r:
                raw = r.read(API_MAX_BYTES + 1)
        except urllib.error.HTTPError as e:
            raise RuntimeError("Govee API said %d %s" % (e.code, "(check the API key)" if e.code in (401, 403) else ""))
        except (urllib.error.URLError, OSError) as e:
            raise RuntimeError("Can't reach Govee: %s" % getattr(e, "reason", e))
        if len(raw) > API_MAX_BYTES:
            raise RuntimeError("Govee sent too much data")
        out = json.loads(raw.decode("utf-8", "replace"))
        if isinstance(out, dict) and out.get("code") not in (None, 200):
            raise RuntimeError("Govee: %s" % str(out.get("message") or out.get("msg") or out.get("code"))[:120])
        return out

    def list_devices(self):
        out = self.call("GET", "/user/devices")
        devs = out.get("data") or []
        self.names = {str(d.get("device")): str(d.get("deviceName") or "")[:40] for d in devs if isinstance(d, dict)}
        self.devices = [d for d in devs if isinstance(d, dict) and "air_purifier" in str(d.get("type", ""))]

    @staticmethod
    def modes_of(dev):
        """Flatten the work_mode capability into a list of pickable modes."""
        for cap in dev.get("capabilities") or []:
            if cap.get("instance") != "workMode":
                continue
            fields = {f.get("fieldName"): f for f in (cap.get("parameters") or {}).get("fields") or []}
            work = (fields.get("workMode") or {}).get("options") or []
            values = (fields.get("modeValue") or {}).get("options") or []
            sub = {str(v.get("name")): v for v in values if isinstance(v, dict)}
            modes = []
            for w in work:
                name, wv = str(w.get("name", "")), w.get("value")
                group = sub.get(name)
                if group and group.get("options"):
                    for o in group["options"]:
                        modes.append({"id": "%s:%s" % (wv, o.get("value")), "label": str(o.get("name"))[:16], "workMode": wv, "modeValue": o.get("value")})
                else:
                    default = (group or {}).get("defaultValue", 0)
                    label = "Fan" if name == "gearMode" else name
                    modes.append({"id": "%s:%s" % (wv, default), "label": label[:16], "workMode": wv, "modeValue": default})
            return modes
        return []

    def read_state(self, dev):
        out = self.call("POST", "/device/state", {
            "requestId": str(uuid.uuid4()),
            "payload": {"sku": dev.get("sku"), "device": dev.get("device")},
        })
        caps = ((out.get("payload") or {}).get("capabilities")) or []
        p = {
            "device": str(dev.get("device", ""))[:64],
            "sku": str(dev.get("sku", ""))[:16],
            "name": str(dev.get("deviceName") or dev.get("sku") or "Air purifier")[:40],
            "modes": self.modes_of(dev),
            "online": True,
            "on": False,
            "mode": "",
            "readings": {},
        }
        for cap in caps:
            inst, val = cap.get("instance"), (cap.get("state") or {}).get("value")
            if inst == "online":
                p["online"] = bool(val)
            elif inst == "powerSwitch":
                p["on"] = val == 1 or val is True
            elif inst == "workMode" and isinstance(val, dict):
                p["mode"] = "%s:%s" % (val.get("workMode"), val.get("modeValue"))
            elif str(cap.get("type", "")).endswith(".property") and isinstance(val, (int, float)):
                p["readings"][str(inst)[:32]] = val
        # A mode reported without a gear value still matches its base mode.
        if p["mode"] and not any(m["id"] == p["mode"] for m in p["modes"]):
            base = p["mode"].split(":")[0]
            for m in p["modes"]:
                if str(m["workMode"]) == base:
                    p["mode"] = m["id"]
                    break
        return p

    def refresh(self):
        if self.status == "disabled":
            return
        if not self.key:
            self.status, self.error = "nokey", ""
            return
        try:
            if not self.devices:
                self.list_devices()
            fresh = {}
            for d in self.devices:
                p = self.read_state(d)
                fresh[p["device"]] = p
            self.purifiers = fresh
            self.status, self.error = "ok", ""
        except (RuntimeError, ValueError) as e:
            self.status, self.error = "error", str(e)[:160]

    def control(self, c):
        dev = next((d for d in self.devices if d.get("device") == c.get("device")), None)
        if dev is None:
            raise RuntimeError("Unknown purifier")
        if "on" in c:
            cap = {"type": "devices.capabilities.on_off", "instance": "powerSwitch", "value": 1 if c["on"] else 0}
        elif "mode" in c:
            m = next((m for m in self.modes_of(dev) if m["id"] == c["mode"]), None)
            if m is None:
                raise RuntimeError("Unknown mode")
            cap = {"type": "devices.capabilities.work_mode", "instance": "workMode", "value": {"workMode": m["workMode"], "modeValue": m["modeValue"]}}
        else:
            return
        self.call("POST", "/device/control", {
            "requestId": str(uuid.uuid4()),
            "payload": {"sku": dev.get("sku"), "device": dev.get("device"), "capability": cap},
        })
        p = self.purifiers.get(dev.get("device"))
        if p is not None:
            if "on" in c: p["on"] = bool(c["on"])
            if "mode" in c: p["mode"], p["on"] = c["mode"], True


# ------------------------------------------------------------------- serve

def emit(lan, cloud):
    lights = lan.snapshot()
    for l in lights:
        name = cloud.names.get(l.get("device", ""))
        if name:
            l["name"] = name
    state = {
        "type": "state",
        "lights": lights,
        "purifiers": list(cloud.purifiers.values()),
        "cloud": cloud.status,
        "error": cloud.error,
        "at": int(time.time()),
    }
    line = json.dumps(state)
    print(line, flush=True)
    try:
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w") as f:
            f.write(line)
        os.replace(tmp, STATE_FILE)
    except OSError:
        pass


def serve():
    cfg = load_config()
    poll = int(clamp(int(cfg.get("purifierPollSeconds") or 60), 20, 3600))
    lan = Lan()
    # Settings can switch the cloud off; the lamps (LAN) keep working.
    cloud_on = os.environ.get("JARVIS_GOVEE_CLOUD", "1") != "0"
    cloud = Cloud(str(cfg.get("apiKey") or "").strip() if cloud_on else "")
    if not cloud_on:
        cloud.status = "disabled"

    # Show the last known state straight away while the network catches up.
    try:
        with open(STATE_FILE) as f:
            cached = json.loads(f.read())
        cached["stale"] = True
        print(json.dumps(cached), flush=True)
    except (OSError, ValueError):
        pass

    cloud_lock = threading.Lock()
    dirty = threading.Event()

    def cloud_loop():
        while True:
            with cloud_lock:
                cloud.refresh()
            dirty.set()
            time.sleep(poll)

    def cloud_control(c):
        with cloud_lock:
            try:
                cloud.control(c)
                cloud.error = ""
            except RuntimeError as e:
                cloud.error = str(e)[:160]
        dirty.set()
        # Read back what the purifier actually did.
        time.sleep(2)
        with cloud_lock:
            cloud.refresh()
        dirty.set()

    threading.Thread(target=cloud_loop, daemon=True).start()

    lan.scan()
    last_scan = last_status = time.time()
    pending_query = 0
    stdin_open = True

    while True:
        now = time.time()
        if now - last_scan > LIGHT_SCAN_EVERY:
            lan.drop_stale()
            lan.scan()
            last_scan = now
        if now - last_status > LIGHT_STATUS_EVERY:
            lan.query()
            last_status = now
        if pending_query and now >= pending_query:
            lan.query()
            pending_query = 0

        socks = [lan.rx] + ([sys.stdin] if stdin_open else [])
        ready, _, _ = select.select(socks, [], [], 0.25)
        changed = False
        for s in ready:
            if s is lan.rx:
                data, addr = lan.rx.recvfrom(4096)
                if lan.handle(data, addr):
                    changed = True
                    # A newly found light: ask how it's set.
                    if "on" not in lan.lights.get(addr[0], {}):
                        lan.query(addr[0])
            else:
                line = sys.stdin.readline()
                if not line:
                    return  # The dashboard went away.
                try:
                    c = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(c, dict):
                    continue
                if c.get("cmd") == "refresh":
                    lan.scan()
                    lan.query()
                    threading.Thread(target=lambda: (cloud_lock.acquire(), cloud.refresh(), cloud_lock.release(), dirty.set()), daemon=True).start()
                elif c.get("cmd") == "lights":
                    try:
                        lan.control(c)
                    except (ValueError, TypeError):
                        continue
                    changed = True
                    pending_query = time.time() + 0.6
                elif c.get("cmd") == "purifier":
                    threading.Thread(target=cloud_control, args=(c,), daemon=True).start()
        if changed or dirty.is_set():
            dirty.clear()
            emit(lan, cloud)


def scan_once():
    lan = Lan()
    end = time.time() + 4
    lan.scan()
    asked = set()
    while time.time() < end:
        r, _, _ = select.select([lan.rx], [], [], 0.25)
        if r:
            data, addr = lan.rx.recvfrom(4096)
            lan.handle(data, addr)
            for ip in lan.lights:
                if ip not in asked:
                    lan.query(ip)
                    asked.add(ip)
    print(json.dumps(lan.snapshot(), indent=2))


def cloud_once():
    cfg = load_config()
    cloud = Cloud(str(cfg.get("apiKey") or "").strip())
    cloud.refresh()
    print(json.dumps({"cloud": cloud.status, "error": cloud.error, "purifiers": list(cloud.purifiers.values())}, indent=2))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if what == "scan":
        scan_once()
    elif what == "cloud":
        cloud_once()
    else:
        try:
            serve()
        except KeyboardInterrupt:
            pass
