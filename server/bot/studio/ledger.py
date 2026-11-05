"""Usage ledger (spec section 9): every billed unit with its price, cost None when unpriced."""
import json
import os
import shutil
import sqlite3
import tempfile
import threading
import time
from pathlib import Path
from collections import Counter
from typing import NamedTuple

from studio.prices import Prices

DAYS = 30


class Row(NamedTuple):
    kind: str
    cost_usd: float | None


def llm_cost(prices: Prices, provider: str, model: str, u: dict) -> float | None:
    p = lambda unit: prices.price(provider, model, unit)
    input_, output = p("input_mtok"), p("output_mtok")
    if input_ is None or output is None:
        return None
    read, write = u.get("cache_read_input_tokens") or 0, u.get("cache_creation_input_tokens") or 0
    prompt = u.get("prompt_tokens") or 0
    if u.get("gross"):  # OpenAI-compatible services count the cache inside prompt_tokens
        prompt -= read + write
    cost = prompt * input_ + read * (p("cache_read_mtok") or input_) + write * (p("cache_write_mtok") or input_) + (u.get("completion_tokens") or 0) * output
    return cost / 1e6


def unit_cost(prices: Prices, kind: str, provider: str, model: str, u: dict) -> float | None:
    if kind in ("llm", "compile", "memory"):
        return llm_cost(prices, provider, model, u)
    if kind == "stt":
        rate = prices.price(provider, model, "minute")
        return None if rate is None else u["seconds"] / 60 * rate
    if kind in ("tts", "clip"):
        rate = prices.price(provider, model, "1k_chars")
        return None if rate is None else u["characters"] / 1000 * rate
    if kind == "jev":
        rate = prices.price(provider, model, "call")
        return None if rate is None else u["calls"] * rate
    raise ValueError(f"unknown kind {kind!r}")


class Ledger:
    """`dest`, when set, is where save() copies the rows (the bot keeps them in RAM and copies them to the bucket at each
    call end, off the event loop, so a record() never waits on a network mount)."""

    def __init__(self, path, prices: Prices, dest=None):
        self.prices, self.dest = prices, Path(dest) if dest else None
        self._db = sqlite3.connect(path, check_same_thread=False)
        self._db.execute(
            "CREATE TABLE IF NOT EXISTS usage (id INTEGER PRIMARY KEY, ts REAL, user_id TEXT, persona TEXT, session_id TEXT, kind TEXT, provider TEXT, model TEXT, units_json TEXT, cost_usd REAL, source TEXT)"
        )
        self._lock = threading.Lock()
        self._saving = threading.Lock()  # one copy at a time; record() only ever waits for the in-RAM backup, never the copy
        self._closed = False

    def restore(self, src) -> None:
        """Load the rows of an earlier copy (the process's start), so a save never overwrites history with less."""
        source = sqlite3.connect(str(src))
        try:
            with self._lock:
                source.backup(self._db)
        finally:
            source.close()

    def save(self, dest=None) -> bool:
        """Copy every row to `dest` (default self.dest) with sqlite's backup API: into a local file first, under the row
        lock (fast, RAM to local disk), then onto `dest` outside it. Blocking: call it with asyncio.to_thread."""
        dest = Path(dest) if dest else self.dest
        if dest is None:
            return False
        with self._saving:
            if self._closed:
                return False
            fd, tmp = tempfile.mkstemp(suffix=".sqlite")
            os.close(fd)
            try:
                local = sqlite3.connect(tmp)
                try:
                    with self._lock:
                        self._db.backup(local)
                finally:
                    local.close()
                part = dest.with_name(dest.name + ".part")
                shutil.copyfile(tmp, part)
                os.replace(part, dest)  # a reader never sees half a file
            finally:
                os.unlink(tmp)
        return True

    def close(self) -> None:
        with self._saving, self._lock:
            if not self._closed:
                self._closed = True
                self._db.close()

    def record(self, *, user_id, persona, session_id, kind, provider, model, units: dict, source: str) -> Row:
        cost = unit_cost(self.prices, kind, provider, model, units)
        with self._lock:
            self._db.execute(
                "INSERT INTO usage (ts, user_id, persona, session_id, kind, provider, model, units_json, cost_usd, source) VALUES (?,?,?,?,?,?,?,?,?,?)",
                (time.time(), user_id, persona, session_id, kind, provider, model, json.dumps(units), cost, source),
            )
            self._db.commit()
        return Row(kind, cost)

    def _rows(self, where: str, arg) -> list[tuple]:
        with self._lock:
            return self._db.execute(f"SELECT ts, kind, provider, model, units_json, cost_usd FROM usage WHERE {where}", (arg,)).fetchall()

    def session_total(self, session_id: str) -> dict:
        by: Counter = Counter()
        unpriced = set()
        for _, kind, _, _, _, cost in self._rows("session_id = ?", session_id):
            if cost is None:
                unpriced.add(kind)
            else:
                by[kind] += cost
        return {"by_kind": dict(by), "total": sum(by.values()), "unpriced": sorted(unpriced)}

    def per_minute(self, session_id: str, window_s: float = 60) -> float:
        since = time.time() - window_s
        return sum(r[5] or 0 for r in self._rows("session_id = ?", session_id) if r[0] >= since) * 60 / window_s

    def _minutes(self, rows) -> float:
        return sum(json.loads(r[4]).get("seconds", 0) for r in rows if r[1] == "stt") / 60

    def user_total(self, user_id: str) -> dict:
        rows = self._rows("user_id = ?", user_id)
        return {"minutes": round(self._minutes(rows), 2), "cost_usd": sum(r[5] or 0 for r in rows)}

    def sessions(self, user_id: str) -> list[dict]:
        with self._lock:
            ids = self._db.execute("SELECT session_id, persona, MIN(ts), SUM(COALESCE(cost_usd, 0)) FROM usage WHERE user_id = ? GROUP BY session_id ORDER BY 3 DESC", (user_id,)).fetchall()
        return [{"session_id": s, "persona": p, "started": t, "cost_usd": c} for s, p, t, c in ids]

    def daily(self, user_id: str, days: int = 7, tz: str = "UTC") -> list[dict]:
        """Call minutes and cost per local day, oldest first, today last; days with nothing are zeros."""
        from datetime import datetime, timedelta
        from zoneinfo import ZoneInfo

        zone = ZoneInfo(tz)
        today = datetime.now(zone).date()
        out = {today - timedelta(days=i): {"minutes": 0.0, "cost_usd": 0.0} for i in range(days)}
        for ts, kind, _, _, units, cost in self._rows("user_id = ?", user_id):
            day = datetime.fromtimestamp(ts, zone).date()
            if day in out:
                out[day]["cost_usd"] += cost or 0
                if kind == "stt":
                    out[day]["minutes"] += json.loads(units).get("seconds", 0) / 60
        return [{"day": d.isoformat(), "weekday": d.strftime("%a")[:2], "minutes": round(v["minutes"], 2), "cost_usd": v["cost_usd"]} for d, v in sorted(out.items())]

    def first_seen(self, user_id: str) -> float | None:
        with self._lock:
            return self._db.execute("SELECT MIN(ts) FROM usage WHERE user_id = ?", (user_id,)).fetchone()[0]

    def projection(self, user_id: str, minutes_per_day: list[int]) -> list[dict]:
        """Monthly cost from this user's own measured mix. Call minutes come from STT seconds; one-off costs (compile, clips) are left out."""
        rows = [r for r in self._rows("user_id = ?", user_id) if r[1] not in ("compile", "clip")]
        minutes = self._minutes(rows)
        per_min = sum(r[5] or 0 for r in rows) / minutes if minutes else None
        return [{"minutes_per_day": m, "per_minute_usd": per_min, "monthly_usd": None if per_min is None else per_min * m * DAYS} for m in minutes_per_day]

    def what_if(self, session_id: str, brain_keys: list[str], tts_keys: list[str]) -> list[dict]:
        """The same units repriced with one other brain or one other TTS."""
        rows = self._rows("session_id = ?", session_id)

        def repriced(swap_kind: str, provider: str, model: str) -> float | None:
            total = 0.0
            for _, kind, p, m, units, cost in rows:
                c = unit_cost(self.prices, kind, provider, model, json.loads(units)) if kind == swap_kind else cost
                if c is None and (kind == swap_kind or kind != "jev"):
                    return None
                total += c or 0
            return total

        out = []
        for swap_kind, keys in (("llm", brain_keys), ("tts", tts_keys)):
            for key in keys:
                provider, model = key.split(":", 1)
                out.append({"key": key, "kind": swap_kind, "cost_usd": repriced(swap_kind, provider, model)})
        return out


def open_ledger(dest, prices_path) -> Ledger:
    """The process's one ledger (the bot): rows in RAM, copied to `dest` by save(). An earlier copy at `dest` is read
    back first; one that cannot be read is left alone and never overwritten: this process then keeps its rows in RAM only."""
    ledger = Ledger(":memory:", Prices.shared(prices_path), dest=dest)
    if dest and Path(dest).exists():
        try:
            ledger.restore(dest)
        except Exception as e:
            import logging

            logging.getLogger("ledger").warning(f"ledger restore failed, not saving over it: {type(e).__name__}")
            ledger.dest = None
    return ledger
