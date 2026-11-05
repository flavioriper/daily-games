"""One `turn_outcomes` row per bot turn, for the shared layer (spec amendment 2026-11-05): numbers only.

A row is the turn's decision as one integer, Jev's feature vector, whether the person spoke over the voice, the gap from
the voice stopping to the person's next speech, and on the last row of the call its length. It never holds the person's
words, a uid, a session id or a time finer than the day. A row is written when the next one closes (or at the end of
the call), in the background: a slow or absent database never holds the call up, and nothing is queued on disk.
"""
import asyncio
import datetime as dt
import logging
import time

from policy.labels import HEADS

log = logging.getLogger("outcomes")
_tasks: set[asyncio.Task] = set()  # writes still in flight after their call has ended


def pending_tasks() -> set[asyncio.Task]:
    return {t for t in _tasks if not t.done()}


async def cancel_pending(timeout: float = 2.0) -> None:
    """Server shutdown: rows still being written get `timeout` to land, then are dropped, never queued."""
    left = pending_tasks()
    if not left:
        return
    _done, late = await asyncio.wait(left, timeout=timeout)
    for t in late:
        t.cancel()
    if late:
        await asyncio.wait(late, timeout=timeout)


def decision_code(decision: dict) -> int:
    """stance, register, warmth and ack as one mixed-radix integer, 0..71 in HEADS order; -1 for an unknown value."""
    code = 0
    for head, values in HEADS.items():
        value = decision.get(head)
        if value not in values:
            return -1
        code = code * len(values) + values.index(value)
    return code


class Outcomes:
    """Rows are written one behind: a closed row waits until the next one closes, so the call's length can go on the
    last row even when the person spoke after it. Every method is safe to call from the call's hot path: none raises."""

    def __init__(self, shared, lang: str, clock=time.monotonic):
        self.shared, self.lang, self.clock = shared, lang, clock
        self._row: dict | None = None  # the last bot turn, until the person speaks again
        self._closed: dict | None = None  # a finished row, written when the next one closes or at the end
        self._speaking, self._spoke, self._done_at = False, False, None
        self._writes: list[asyncio.Task] = []

    @property
    def online(self) -> bool:
        return bool(self.shared is not None and getattr(self.shared, "online", False))

    def on_event(self, event: dict) -> None:
        """The steer's turn event: only the decision and the features are read from it."""
        try:
            if event.get("kind") != "turn" or not self.online:
                return
            decision, features = event.get("decision"), event.get("raw_features") or []
            row = {"decision": decision_code(decision if isinstance(decision, dict) else {}), "features": [float(x) for x in features], "interrupted": False}
        except Exception:
            log.warning("turn outcome skipped: malformed turn event")
            return
        if self._row is not None:
            self._close(gap_ms=-1)  # a turn the person never answered
        self._row = row
        self._spoke, self._done_at = self._speaking, None  # an ack clip may already be playing

    def speaking(self) -> None:
        self._speaking = self._spoke = True

    def done(self) -> None:
        self._speaking, self._done_at = False, self.clock()

    def interrupt(self) -> None:
        """The phone's tap: the voice is cut off, whether or not its stop frame ever arrives."""
        if self._row is not None and self._speaking:
            self._row["interrupted"] = True
        self._stop()

    def heard(self) -> None:
        """The person started speaking: the last turn's row is complete."""
        if self._row is not None:
            if self._speaking or self._row["interrupted"]:  # over the voice
                self._row["interrupted"] = True
                self._close(gap_ms=0)
            elif not self._spoke:  # the voice never started (a hold, a tool, a clip only): no gap to measure
                self._close(gap_ms=-1)
            else:
                self._close(gap_ms=round((self.clock() - self._done_at) * 1000))
        self._stop()

    async def end(self, call_s: float) -> None:
        """The call's last row carries its length; a call with no bot turn writes nothing."""
        try:
            if self._row is not None:
                self._close(gap_ms=-1)
            if self._closed is not None:
                self._closed["call_s"] = int(round(call_s))
                self._write(self._closed)
                self._closed = None
        except Exception:
            log.warning("turn outcome end failed")

    async def drain(self, timeout: float = 10.0) -> None:
        if self._writes:
            await asyncio.wait(self._writes, timeout=timeout)

    def _stop(self) -> None:
        if self._speaking:
            self._speaking, self._done_at = False, self.clock()

    def _close(self, gap_ms: int) -> None:
        row, self._row = self._row, None
        row.update(day=dt.datetime.now(dt.timezone.utc).date(), lang=self.lang, gap_ms=int(gap_ms), call_s=0)
        if self._closed is not None:
            self._write(self._closed)
        self._closed = row

    def _write(self, row: dict) -> None:
        if not self.online:
            return
        task = asyncio.ensure_future(self.shared.add_outcome(row))
        self._writes.append(task)
        _tasks.add(task)
        task.add_done_callback(_tasks.discard)
