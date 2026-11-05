"""The player's memory, fed by the phone. It arrives in the `hello` as `memory`, lives only in RAM for the call, and every change goes back to the phone through `emit`; nothing about the player is written on the server. `DeviceStore` answers the calls `memory/turn.py` and `RecallIndex.load` make of the old Postgres store, and `DeviceHub` the ones they make of its hub."""
import asyncio
import json
from functools import lru_cache
import uuid
from datetime import datetime, timezone
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np

from memory.embed import embed
from memory.gate import GateNet, load_gate

ROOT = Path(__file__).resolve().parent.parent
LIMIT = 300  # characters; the phone drops a longer item on load, so a write never sends one
MAX_FACTS, MAX_EPISODES = 500, 200  # newest kept: a huge or hostile file must not buy unbounded embedding work or RAM


@dataclass
class Fact:
    id: str
    text: str
    embedding: np.ndarray
    since: str = ""


@dataclass
class Episode:
    id: str
    summary: str
    embedding: np.ndarray
    created_at: str


def _fits(text: str) -> str:
    text = " ".join(text.split())
    if len(text) <= LIMIT:
        return text
    cut = text[: LIMIT - 1].rsplit(" ", 1)[0]
    return cut.rstrip(" ,;:") + "…"


def _items(payload, key: str, field: str) -> list[dict]:
    rows = payload.get(key) if isinstance(payload, dict) else None
    if not isinstance(rows, list):
        return []
    ok = lambda r: isinstance(r, dict) and isinstance(r.get("id"), str) and r["id"] and isinstance(r.get(field), str) and r[field].strip() and len(r[field]) <= LIMIT
    return [r for r in rows if ok(r)]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class DeviceStore:
    """One player and one persona for one call, so the slug and user arguments the store interface carries are ignored."""

    def __init__(self, emit: Callable[[dict], None], facts: list[Fact] | None = None, episodes: list[Episode] | None = None):
        """Takes items already embedded; a payload comes in through `load`, which embeds off the event loop."""
        self.emit = emit
        self.facts, self.episodes = list(facts or []), list(episodes or [])
        self.notes: list[tuple[str, str]] = []  # (session id, text): short term is one call long and never leaves the server's RAM

    @classmethod
    async def load(cls, payload: dict | None, emit: Callable[[dict], None]) -> "DeviceStore":
        """Validated, capped to the newest MAX_FACTS and MAX_EPISODES, and embedded in one batch on a worker thread, so a big file or a first-run model download never blocks the call's loop."""
        facts = sorted(_items(payload, "facts", "text"), key=lambda f: str(f.get("since") or ""), reverse=True)[:MAX_FACTS]
        episodes = sorted(_items(payload, "episodes", "summary"), key=lambda e: str(e.get("at") or ""), reverse=True)[:MAX_EPISODES]
        texts = [f["text"] for f in facts] + [e["summary"] for e in episodes]
        vectors = await asyncio.to_thread(embed, texts) if texts else np.zeros((0, 384), np.float32)
        return cls(emit,
                   [Fact(f["id"], f["text"], vectors[i], str(f.get("since") or "")) for i, f in enumerate(facts)],
                   [Episode(e["id"], e["summary"], vectors[len(facts) + i], str(e.get("at") or "")) for i, e in enumerate(episodes)])

    def _send(self, op: str, id: str, text: str = "") -> None:
        self.emit({"type": "memory", "op": op, "id": id, "text": text})

    async def facts_for(self, slug: str, user_id: str) -> list[Fact]:
        return list(self.facts)

    async def add_fact(self, slug: str, user_id: str, text: str, embedding) -> str:
        fact = Fact(uuid.uuid4().hex, _fits(text), np.asarray(embedding, dtype=np.float32), _now())
        self.facts.insert(0, fact)
        self._send("add", fact.id, fact.text)
        return fact.id

    async def expire_fact(self, fact_id: str) -> None:
        self.facts = [f for f in self.facts if f.id != fact_id]
        self._send("forget", fact_id)

    async def forget_fact(self, slug: str, user_id: str, fact_id: str, text: str) -> None:
        """Everywhere the text was written verbatim, as the old store did; the text itself never goes back over the wire."""
        gone = [f.id for f in self.facts if f.id == fact_id or (text and f.text == text)]
        self.facts = [f for f in self.facts if f.id not in gone]
        if text:
            self.notes = [n for n in self.notes if text.lower() not in n[1].lower()]
        for i in dict.fromkeys([fact_id, *gone]):
            self._send("forget", i)

    async def add_note(self, slug: str, user_id: str, session_id: str, text: str) -> str:
        self.notes.append((session_id, text))
        return str(len(self.notes))

    async def notes_for(self, session_id: str) -> list[str]:
        return [t for s, t in self.notes if s == session_id]

    async def clear_notes(self, session_id: str) -> None:
        self.notes = [n for n in self.notes if n[0] != session_id]

    async def clear_stale_notes(self, slug: str, user_id: str) -> None:
        self.notes = []

    async def add_episode(self, slug: str, user_id: str, session_id: str, summary: str, embedding) -> None:
        await self._episode(session_id, summary, embedding, _now())

    async def update_episode(self, episode_id: str, summary: str, embedding) -> None:
        await self._episode(episode_id, summary, embedding, None)

    async def _episode(self, id: str, summary: str, embedding, at: str | None) -> None:
        """Keyed by id, so the phone's `episode` op is an upsert: a scrubbed summary replaces the old one."""
        old = next((e for e in self.episodes if e.id == id), None)
        e = Episode(id, _fits(summary), np.asarray(embedding, dtype=np.float32), at or (old.created_at if old else _now()))
        self.episodes = [e] + [x for x in self.episodes if x.id != id] if old is None else [e if x.id == id else x for x in self.episodes]
        self._send("episode", e.id, e.summary)

    async def episodes_for(self, slug: str, user_id: str) -> list[Episode]:
        return list(self.episodes)

    async def chunks_for(self, slug: str) -> list:
        return []  # documents went with the fork; RecallIndex.load still asks

    async def log_event(self, slug: str, user_id: str, body: dict) -> None:
        return None  # the event log stayed in Postgres; nothing about the player is kept on the server

    async def counts(self, slug: str, user_id: str) -> dict:
        return {"facts": len(self.facts), "notes": len(self.notes), "episodes": len(self.episodes), "documents": 0, "chunks": 0}


@lru_cache(maxsize=2)
def _shared_gate(models_dir: str) -> tuple[GateNet, dict]:
    """Read once per process: the gate is frozen (eval, no grad) and never taught here, so every call shares it."""
    return load_gate(Path(models_dir) / "gate.pt"), json.loads((Path(models_dir) / "gate-metrics.json").read_text())["thresholds"]


class DeviceHub:
    """The shared gate and the call's live index; always up, because the store is in RAM."""

    def __init__(self, store: DeviceStore, models_dir=ROOT / "models"):
        self.store, self.status = store, "up"
        self.gate, thresholds = _shared_gate(str(Path(models_dir).resolve()))
        self.thresholds = dict(thresholds)
        self.live: dict[int, tuple[str, object]] = {}

    async def ensure(self) -> bool:
        return True

    async def gate_for(self, slug: str, user_id: str) -> GateNet:
        return self.gate

    async def teach_drop(self, slug: str, user_id: str, gate: GateNet, text, prev, features) -> tuple[GateNet, dict]:
        """No per-player gate corrections: they would be data about the player kept on the server."""
        return gate, {"accepted": False, "reason": "not kept"}

    def attach(self, slug: str, index) -> int:
        key = id(index)
        self.live[key] = (slug, index)
        return key

    def detach(self, key: int) -> None:
        self.live.pop(key, None)

    def redact(self, text: str) -> None:
        return None
