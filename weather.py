#!/usr/bin/env python3
"""Current weather for the Jarvis header, as one JSON line on stdout.

Uses the same sources as Omarchy's own weather panel, so the two agree:
the location saved in ~/.local/state/omarchy/settings/weather.json, or with
none saved, where geo.omarchy.org places this network; the forecast from
Open-Meteo (no account, no key). Units follow the saved "unit" setting, else
Fahrenheit in the US and Celsius elsewhere.
"""

import json
import os
import sys
import time
import urllib.parse
import urllib.request

HOME = os.path.expanduser("~")
SETTINGS = os.path.join(HOME, ".local", "state", "omarchy", "settings", "weather.json")
CACHE = os.path.join(HOME, ".local", "state", "jarvis", "weather.json")
TIMEOUT = 6
MAX_BYTES = 1 << 20
IMPERIAL_COUNTRIES = {"US", "LR", "MM", "BS", "BZ", "KY", "PW", "FM", "MH"}

# WMO weather code -> (label, day glyph, night glyph). Glyphs are Nerd Font
# weather icons.
CODES = {
    0: ("Clear", "", ""),
    1: ("Mostly clear", "", ""),
    2: ("Partly cloudy", "", ""),
    3: ("Cloudy", "", ""),
    45: ("Fog", "", ""),
    48: ("Fog", "", ""),
    51: ("Drizzle", "", ""),
    53: ("Drizzle", "", ""),
    55: ("Drizzle", "", ""),
    56: ("Freezing drizzle", "", ""),
    57: ("Freezing drizzle", "", ""),
    61: ("Light rain", "", ""),
    63: ("Rain", "", ""),
    65: ("Heavy rain", "", ""),
    66: ("Freezing rain", "", ""),
    67: ("Freezing rain", "", ""),
    71: ("Light snow", "", ""),
    73: ("Snow", "", ""),
    75: ("Heavy snow", "", ""),
    77: ("Snow grains", "", ""),
    80: ("Showers", "", ""),
    81: ("Showers", "", ""),
    82: ("Heavy showers", "", ""),
    85: ("Snow showers", "", ""),
    86: ("Snow showers", "", ""),
    95: ("Thunderstorm", "", ""),
    96: ("Thunderstorm", "", ""),
    99: ("Thunderstorm", "", ""),
}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "jarvis-dashboard"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        raw = r.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("response too large")
    return json.loads(raw.decode("utf-8", "replace"))


def location():
    try:
        with open(SETTINGS) as f:
            s = json.load(f)
        lat, lon = float(s.get("latitude")), float(s.get("longitude"))
        return {"name": str(s.get("name") or "")[:40], "lat": lat, "lon": lon,
                "country": str(s.get("country") or ""), "unit": str(s.get("unit") or "")}
    except (OSError, ValueError, TypeError, AttributeError):
        pass
    g = fetch("https://geo.omarchy.org/")
    unit = ""
    try:
        with open(SETTINGS) as f:
            unit = str(json.load(f).get("unit") or "")
    except (OSError, ValueError, AttributeError):
        pass
    return {"name": str(g.get("name") or "")[:40], "lat": float(g["latitude"]), "lon": float(g["longitude"]),
            "country": str(g.get("country") or ""), "unit": unit}


def describe(code, day):
    label, d, n = CODES.get(int(code), ("", "", ""))
    return label, d if day else n


def main():
    loc = location()
    imperial = loc["unit"].lower().startswith(("f", "imp")) if loc["unit"] else loc["country"].upper() in IMPERIAL_COUNTRIES
    q = urllib.parse.urlencode({
        "latitude": loc["lat"],
        "longitude": loc["lon"],
        "current": "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day",
        "hourly": "temperature_2m,weather_code,is_day,precipitation_probability",
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset",
        "forecast_days": 2,
        "timezone": "auto",
        "temperature_unit": "fahrenheit" if imperial else "celsius",
        "wind_speed_unit": "mph" if imperial else "kmh",
    })
    w = fetch("https://api.open-meteo.com/v1/forecast?" + q)
    cur, daily, hourly = w["current"], w["daily"], w["hourly"]
    label, glyph = describe(cur["weather_code"], cur.get("is_day", 1))

    # The next few hours, starting from the current one.
    now_key = cur["time"][:13]
    times = hourly["time"]
    start = next((i for i, t in enumerate(times) if t[:13] >= now_key), 0)
    hours = []
    for i in range(start + 1, min(start + 7, len(times))):
        _, g = describe(hourly["weather_code"][i], hourly["is_day"][i])
        h = int(times[i][11:13])
        hours.append({
            "label": ("12" if h % 12 == 0 else str(h % 12)) + ("a" if h < 12 else "p"),
            "temp": round(hourly["temperature_2m"][i]),
            "icon": g,
            "rain": hourly["precipitation_probability"][i] or 0,
        })

    out = {
        "type": "weather",
        "place": loc["name"],
        "unit": "F" if imperial else "C",
        "temp": round(cur["temperature_2m"]),
        "feels": round(cur["apparent_temperature"]),
        "humidity": round(cur["relative_humidity_2m"]),
        "wind": round(cur["wind_speed_10m"]),
        "windUnit": "mph" if imperial else "km/h",
        "label": label,
        "icon": glyph,
        "day": bool(cur.get("is_day", 1)),
        "high": round(daily["temperature_2m_max"][0]),
        "low": round(daily["temperature_2m_min"][0]),
        "rain": daily["precipitation_probability_max"][0] or 0,
        "sunset": str(daily["sunset"][0])[11:16],
        "sunrise": str(daily["sunrise"][1 if len(daily["sunrise"]) > 1 else 0])[11:16],
        "hours": hours,
        "at": int(time.time()),
    }
    line = json.dumps(out)
    print(line, flush=True)
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE + ".tmp", "w") as f:
            f.write(line)
        os.replace(CACHE + ".tmp", CACHE)
    except OSError:
        pass


if __name__ == "__main__":
    # Replay the last reading first so the header isn't empty while fetching.
    if len(sys.argv) > 1 and sys.argv[1] == "--cached":
        try:
            with open(CACHE) as f:
                print(f.read().strip(), flush=True)
        except OSError:
            pass
    try:
        main()
    except Exception as e:  # Any failure: say so on one line; the header keeps the last reading.
        print(json.dumps({"type": "weather-error", "error": str(e)[:160]}), flush=True)
