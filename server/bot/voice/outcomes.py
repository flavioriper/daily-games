"""One `turn_outcomes` row per bot turn, for the shared layer (spec amendment 2026-11-05): numbers only.

A row is the turn's decision as one integer, Jev's feature vector, whether the person spoke over the voice, the gap from
the voice stopping to the person's next speech, and on the last row of the call its length. It never holds the person's
words, a uid, a session id or a time finer than the day. A row is written when the person next speaks (or at the end of
the call), in the background: a slow or absent database never holds the call up, and nothing is queued on disk.
"""
import asyncio
import datetime as dt
import time

from policy.labels import HEADS

_tasks: set[asyncio.Task] = set()  # writes still in flight after their call has ended


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
    def __init__(self, shared, lang: str, clock=time.monotonic):
        self.shared, self.lang, self.clock = shared, lang, clock
        self._row: dict | None = None  # the last bot turn, until the person speaks again
        self._speaking, self._done_at = False, None
        self._writes: list[asyncio.Task] = []

    @property
    def online(self) -> bool:
        return bool(self.shared is not None and getattr(self.shared, "online", False))

    def on_event(self, event: dict) -> None:
        """The steer's turn event: only the decision and the features are read from it."""
        if event.get("kind") != "turn" or not self.online:
            return
        self._flush(gap_ms=-1)  # a turn that never got an answer from the person
        features = event.get("raw_features") or []
        self._row = {"decision": decision_code(event.get("decision") or {}), "features": [float(x) for x in features], "interrupted": False}
        self._done_at = None

    def speaking(self) -> None:
        self._speaking = True

    def done(self) -> None:
        self._speaking, self._done_at = False, self.clock()

    def interrupt(self) -> None:
        """The phone's tap or a barge-in: the person cut the voice off."""
        if self._row is not None and (self._speaking or self._done_at is None):
            self._row["interrupted"] = True

    def heard(self) -> None:
        """The person started speaking: the last turn's row is complete."""
        if self._row is None:
            return
        if self._speaking or self._done_at is None:  # over the voice, or before it said anything
            self._row["interrupted"] = True
            self._flush(gap_ms=0)
        else:
            self._flush(gap_ms=round((self.clock() - self._done_at) * 1000))

    async def end(self, call_s: float) -> None:
        """The call's last row carries its length; a call with no bot turn writes nothing."""
        self._flush(gap_ms=-1, call_s=call_s)

    async def drain(self, timeout: float = 10.0) -> None:
        if self._writes:
            await asyncio.wait(self._writes, timeout=timeout)

    def _flush(self, gap_ms: int, call_s: float = 0) -> None:
        row, self._row = self._row, None
        if row is None or not self.online:
            return
        row.update(day=dt.datetime.now(dt.timezone.utc).date(), lang=self.lang, gap_ms=int(gap_ms), call_s=int(round(call_s)))
        task = asyncio.ensure_future(self.shared.add_outcome(row))
        self._writes.append(task)
        _tasks.add(task)
        task.add_done_callback(_tasks.discard)
