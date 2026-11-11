#!/usr/bin/env python3
"""Stock data for the Jarvis dashboard, from Yahoo Finance's public chart and
search endpoints (no account or key; unofficial, so it can change or rate
limit). Runs while the dashboard is open.

  stocks.py serve           JSON commands on stdin, JSON lines on stdout
  stocks.py quote NVDA      print one quote and exit
  stocks.py search nvidia   print search results and exit

Commands:
  {"cmd": "watch", "symbols": ["NVDA", "AAPL"]}       quotes now and every 60s
  {"cmd": "search", "q": "nvidia", "id": 3}
  {"cmd": "chart", "symbol": "NVDA", "range": "1mo", "id": 4}

Output lines carry "type": "quotes" | "search" | "chart" | "error".
"""

import json
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (X11; Linux x86_64) jarvis-dashboard"
TIMEOUT = 8
MAX_BYTES = 4 << 20
SYMBOL = re.compile(r"^[A-Za-z0-9.^=\-]{1,15}$")
RANGES = {  # range -> interval
    "1d": "5m", "5d": "15m", "1mo": "60m", "6mo": "1d", "1y": "1d", "5y": "1wk",
}
LIVE_EVERY = 15
CLOSED_EVERY = 60
KINDS = {"EQUITY", "ETF", "INDEX", "CRYPTOCURRENCY", "MUTUALFUND"}

out_lock = threading.Lock()


def emit(obj):
    with out_lock:
        print(json.dumps(obj), flush=True)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        raw = r.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("response too large")
    return json.loads(raw.decode("utf-8", "replace"))


def friendly(e):
    """An error a person can read, instead of "<urlopen error [Errno 111]...>"."""
    if isinstance(e, urllib.error.HTTPError):
        if e.code == 404:
            return "no data for this symbol"
        if e.code == 429:
            return "Yahoo Finance is busy, trying again shortly"
        return "Yahoo Finance answered with an error (%d)" % e.code
    if isinstance(e, (urllib.error.URLError, TimeoutError, OSError)):
        return "can't reach Yahoo Finance (offline?)"
    return str(e)[:160]


def num(v):
    return float(v) if isinstance(v, (int, float)) else None


def chart_raw(symbol, rng):
    if not SYMBOL.match(symbol):
        raise ValueError("bad symbol")
    q = urllib.parse.urlencode({"range": rng, "interval": RANGES[rng], "includePrePost": "false"})
    d = fetch("https://query1.finance.yahoo.com/v8/finance/chart/%s?%s" % (urllib.parse.quote(symbol), q))
    res = ((d.get("chart") or {}).get("result") or [None])[0]
    if not res:
        err = ((d.get("chart") or {}).get("error") or {}).get("description") or "no data"
        raise ValueError(str(err)[:120])
    return res


def series(res):
    ts = res.get("timestamp") or []
    closes = (((res.get("indicators") or {}).get("quote") or [{}])[0].get("close")) or []
    pts = [[int(t), round(float(c), 4)] for t, c in zip(ts, closes) if isinstance(c, (int, float))]
    return pts


def market_open(meta):
    reg = (meta.get("currentTradingPeriod") or {}).get("regular") or {}
    s, e = reg.get("start"), reg.get("end")
    now = time.time()
    return bool(s and e and s <= now <= e)


def quote(symbol):
    res = chart_raw(symbol, "1d")
    m = res.get("meta") or {}
    pts = series(res)
    price = num(m.get("regularMarketPrice")) or (pts[-1][1] if pts else None)
    prev = num(m.get("chartPreviousClose")) or num(m.get("previousClose"))
    change = (price - prev) if price is not None and prev else 0.0
    pct = (change / prev * 100) if prev else 0.0
    # A light sparkline: at most 48 points.
    step = max(1, -(-len(pts) // 48))
    spark = [p[1] for p in pts[::step]]
    if pts and (not spark or spark[-1] != pts[-1][1]):
        spark.append(pts[-1][1])
    return {
        "symbol": str(m.get("symbol") or symbol)[:15],
        "name": str(m.get("longName") or m.get("shortName") or symbol)[:60],
        "price": price,
        "prevClose": prev,
        "change": round(change, 4),
        "pct": round(pct, 3),
        "currency": str(m.get("currency") or "")[:6],
        "open": market_open(m),
        "spark": spark,
    }


def chart(symbol, rng):
    res = chart_raw(symbol, rng)
    m = res.get("meta") or {}
    pts = series(res)
    price = num(m.get("regularMarketPrice")) or (pts[-1][1] if pts else None)
    base = num(m.get("chartPreviousClose")) if rng == "1d" else (pts[0][1] if pts else None)
    base = base or num(m.get("previousClose"))
    # Keep the chart light: at most ~400 points.
    step = max(1, len(pts) // 400)
    slim = pts[::step]
    if pts and slim[-1] != pts[-1]:
        slim.append(pts[-1])
    return {
        "symbol": str(m.get("symbol") or symbol)[:15],
        "name": str(m.get("longName") or m.get("shortName") or symbol)[:60],
        "exchange": str(m.get("fullExchangeName") or m.get("exchangeName") or "")[:30],
        "currency": str(m.get("currency") or "")[:6],
        "price": price,
        "base": base,
        "change": round((price - base), 4) if price is not None and base else 0,
        "pct": round((price - base) / base * 100, 3) if price is not None and base else 0,
        "dayHigh": num(m.get("regularMarketDayHigh")),
        "dayLow": num(m.get("regularMarketDayLow")),
        "high52": num(m.get("fiftyTwoWeekHigh")),
        "low52": num(m.get("fiftyTwoWeekLow")),
        "volume": num(m.get("regularMarketVolume")),
        "prevClose": num(m.get("chartPreviousClose")) or num(m.get("previousClose")),
        "open": market_open(m),
        "points": slim,
    }


def search(q):
    q = str(q).strip()[:60]
    if not q:
        return []
    url = "https://query1.finance.yahoo.com/v1/finance/search?" + urllib.parse.urlencode(
        {"q": q, "quotesCount": 8, "newsCount": 0, "listsCount": 0})
    d = fetch(url)
    out = []
    for r in d.get("quotes") or []:
        sym = str(r.get("symbol") or "")
        if not SYMBOL.match(sym) or str(r.get("quoteType")) not in KINDS:
            continue
        out.append({
            "symbol": sym,
            "name": str(r.get("longname") or r.get("shortname") or sym)[:60],
            "exchange": str(r.get("exchDisp") or r.get("exchange") or "")[:20],
            "kind": str(r.get("typeDisp") or r.get("quoteType") or "")[:16],
        })
    return out[:8]


def serve():
    pool = ThreadPoolExecutor(max_workers=6)
    watch = {"symbols": [], "rev": 0}
    wake = threading.Event()

    def refresh_quotes():
        syms = list(watch["symbols"])
        quotes, errors = {}, []
        futures = {s: pool.submit(quote, s) for s in syms}
        for s, f in futures.items():
            try:
                quotes[s] = f.result()
            except Exception as e:
                errors.append("%s: %s" % (s, friendly(e)))
        any_open = any(q.get("open") for q in quotes.values())
        emit({"type": "quotes", "quotes": quotes, "errors": errors, "live": any_open,
              "every": LIVE_EVERY if any_open else CLOSED_EVERY, "at": int(time.time())})
        return any_open

    # Live while a market is open: every 15s, else every minute.
    state = {"open": False}

    def quote_loop():
        while True:
            wake.wait(LIVE_EVERY if state["open"] else CLOSED_EVERY)
            wake.clear()
            if watch["symbols"]:
                state["open"] = refresh_quotes()

    threading.Thread(target=quote_loop, daemon=True).start()

    def run(kind, fn, *args, **extra):
        def job():
            try:
                emit(dict(type=kind, **extra, **fn(*args)))
            except Exception as e:
                emit(dict(type="error", of=kind, error=friendly(e), **extra))
        pool.submit(job)

    for line in sys.stdin:
        try:
            c = json.loads(line)
        except ValueError:
            continue
        if not isinstance(c, dict):
            continue
        cmd = c.get("cmd")
        rid = c.get("id", 0)
        if cmd == "watch":
            syms = [s for s in (c.get("symbols") or []) if isinstance(s, str) and SYMBOL.match(s)][:40]
            watch["symbols"] = syms
            wake.set()
        elif cmd == "search":
            q = str(c.get("q") or "")
            run("search", lambda q=q: {"q": q, "results": search(q)}, id=rid)
        elif cmd == "chart":
            sym, rng = str(c.get("symbol") or ""), str(c.get("range") or "1d")
            if rng not in RANGES:
                rng = "1d"
            run("chart", lambda s=sym, r=rng: {"range": r, **chart(s, r)}, id=rid)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if what == "quote" and len(sys.argv) > 2:
        print(json.dumps(quote(sys.argv[2]), indent=2))
    elif what == "search" and len(sys.argv) > 2:
        print(json.dumps(search(" ".join(sys.argv[2:])), indent=2))
    else:
        try:
            serve()
        except KeyboardInterrupt:
            pass
