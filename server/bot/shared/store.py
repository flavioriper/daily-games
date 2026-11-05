"""The shared layer's store: Postgres (pgvector) on Neon, read and written by the bot server only.

Nothing here may identify a player: no uid, no session id, no transcript. With ``dsn=None`` every read is empty and
every write a no-op (the offline and test default). If Neon is unreachable a call goes on without knowledge or style and
outcomes and suggestions are dropped, never queued on disk: every database call logs a warning without its content and
returns the empty answer.
"""
import asyncio
import datetime as dt
import logging
import re
import threading
import time
from pathlib import Path

import numpy as np

log = logging.getLogger("shared")

# The shared layer has its own embedder: the players write in en, pt and es, and the device memory's bge-small is
# English only. Both models are 384 wide. Rows and queries must come from this one, so a change here needs a re-sync.
MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
DIM = 384
_model = None
_model_lock = threading.Lock()


def embed_texts(texts: list[str]) -> np.ndarray:
    """One row per text; empty text is a zero row. Blocking: callers off the event loop use ``_embed``."""
    global _model
    with _model_lock:
        if _model is None:
            from fastembed import TextEmbedding

            _model = TextEmbedding(MODEL)
    out = np.zeros((len(texts), DIM), dtype=np.float32)
    used = [i for i, tx in enumerate(texts) if tx.strip()]
    if used:
        out[used] = np.array(list(_model.embed([texts[i] for i in used])), dtype=np.float32)
    return out

SCHEMA = Path(__file__).with_name("schema.sql")
DUP_COSINE = 0.92
KINDS = ("question", "fix", "fact", "style")
OUTCOME_KEYS = ("day", "lang", "decision", "features", "interrupted", "gap_ms", "call_s")
KNOB_PREFIX = "knob."
READ_TIMEOUT_S = 4.0
EMBED_TIMEOUT_S = 20.0
DOWN_FOR_S = 30.0  # after a database failure, reads answer empty and writes drop at once for this long


def parse_markdown(lang: str, topic: str, md: str) -> list[dict]:
    """One file a topic: ``# Title`` then paragraphs; each paragraph is one row. A soft-wrapped paragraph is one line."""
    title = ""
    rows = []
    for block in re.split(r"\n\s*\n", md.strip()):
        lines = [ln.strip() for ln in block.strip().splitlines() if ln.strip()]
        if lines and lines[0].startswith("#"):
            if not title:
                title = lines[0].lstrip("#").strip()
            lines = [ln for ln in lines if not ln.startswith("#")]
        text = " ".join(lines)
        if text:
            rows.append({"lang": lang, "topic": topic, "title": title, "text": text})
    return rows


def _vec(v) -> str:
    return "[" + ",".join(f"{float(x):.7g}" for x in np.asarray(v, dtype=np.float32).ravel()) + "]"


async def _embed(texts: list[str]) -> np.ndarray:
    return await asyncio.wait_for(asyncio.to_thread(embed_texts, texts), EMBED_TIMEOUT_S)


class SharedStore:
    def __init__(self, dsn: str | None):
        self.dsn = dsn or None
        self._pool = None
        self._opening = asyncio.Lock()
        self._down_until = 0.0

    async def warm(self) -> None:
        """Load the embedding model ahead of the first turn (off the event loop). Never raises."""
        try:
            await _embed(["warm"])
        except Exception as e:
            log.warning("shared layer warm failed: %s", type(e).__name__)

    async def _vec_of(self, what: str, text: str):
        """The embedding of one text as a vector literal, or None when it cannot be made in time."""
        try:
            return _vec((await _embed([text]))[0])
        except Exception as e:
            log.warning("shared layer %s embed failed: %s", what, type(e).__name__)
            return None

    @property
    def online(self) -> bool:
        return self.dsn is not None

    async def _get_pool(self):
        if self._pool is None:
            async with self._opening:
                if self._pool is None:
                    from psycopg_pool import AsyncConnectionPool

                    pool = AsyncConnectionPool(
                        self.dsn,
                        min_size=0,
                        max_size=4,
                        max_idle=120,
                        timeout=READ_TIMEOUT_S,
                        open=False,
                        check=AsyncConnectionPool.check_connection,
                        kwargs={"autocommit": True, "prepare_threshold": None, "connect_timeout": 5},
                    )
                    await pool.open()
                    self._pool = pool
        return self._pool

    async def close(self) -> None:
        if self._pool is not None:
            await self._pool.close()
            self._pool = None

    @property
    def down(self) -> bool:
        """A read failed within the last DOWN_FOR_S: reads answer empty and writes drop at once until then."""
        return time.monotonic() < self._down_until

    async def _run(self, what: str, fn, default=None, mark_down: bool = True):
        """Run ``fn(conn)`` on a pooled connection; any failure is logged (kind only) and answered with ``default``.
        A background write passes ``mark_down=False``: it is dropped alone, and the reads of every call (a cold compute
        waking past the timeout, a single slow insert) are not taken down with it."""
        if not self.online or self.down:
            return default
        try:
            pool = await self._get_pool()
            async with pool.connection() as conn:
                return await asyncio.wait_for(fn(conn), READ_TIMEOUT_S * 2)
        except Exception as e:
            if mark_down:
                self._down_until = time.monotonic() + DOWN_FOR_S
                log.warning("shared layer %s failed: %s (down for %.0f s)", what, type(e).__name__, DOWN_FOR_S)
            else:
                log.warning("shared layer %s failed: %s (dropped)", what, type(e).__name__)
            return default

    # reads

    async def knowledge_for(self, lang: str, text: str, k: int = 4) -> list[str]:
        if not self.online or not text.strip() or time.monotonic() < self._down_until:
            return []
        q = await self._vec_of("knowledge_for", text)
        if q is None:
            return []

        async def go(conn):
            cur = await conn.execute(
                "select text from knowledge where lang = %s and active order by embedding <=> %s::vector limit %s",
                (lang, q, k),
            )
            return [r[0] for r in await cur.fetchall()]

        return await self._run("knowledge_for", go, [])

    async def style_and_knobs_for(self, lang: str) -> tuple[list[str], dict[str, str]]:
        """One query: the short prompt notes of a language in key order, and its knobs (keys that start 'knob.')."""

        async def go(conn):
            cur = await conn.execute(
                "select key, text from style where lang = %s and active order by key", (lang,)
            )
            return [(r[0], r[1]) for r in await cur.fetchall()]

        rows = await self._run("style_for", go, [])
        notes = [tx for k, tx in rows if not k.startswith(KNOB_PREFIX)]
        knobs = {k[len(KNOB_PREFIX):]: tx for k, tx in rows if k.startswith(KNOB_PREFIX)}
        return notes, knobs

    async def style_for(self, lang: str) -> list[str]:
        return (await self.style_and_knobs_for(lang))[0]

    async def knobs_for(self, lang: str) -> dict[str, str]:
        return (await self.style_and_knobs_for(lang))[1]

    async def pending(self, limit: int = 50) -> list[dict]:
        async def go(conn):
            cur = await conn.execute(
                "select id, lang, kind, text, seen, first_day, last_day from suggestions"
                " where status = 'pending' order by seen desc, id limit %s",
                (limit,),
            )
            names = ("id", "lang", "kind", "text", "seen", "first_day", "last_day")
            return [dict(zip(names, r)) for r in await cur.fetchall()]

        return await self._run("pending", go, [])

    # writes

    async def add_outcome(self, row: dict) -> None:
        """Numbers only. A row with a key outside OUTCOME_KEYS (a uid, a text...) or a malformed value is dropped with
        a warning that names no content; this never raises."""
        try:
            extra = set(row) - set(OUTCOME_KEYS)
            if extra:
                log.warning("shared layer outcome dropped: %d key(s) outside the numbers", len(extra))
                return
            if not self.online or time.monotonic() < self._down_until:
                return
            day = row.get("day") or dt.datetime.now(dt.timezone.utc).date()
            if isinstance(day, str):
                day = dt.date.fromisoformat(day)
            vals = (
                day,
                str(row["lang"]),
                int(row["decision"]),
                [float(x) for x in row["features"]],
                bool(row["interrupted"]),
                int(row["gap_ms"]),
                int(row["call_s"]),
            )
        except Exception as e:
            log.warning("shared layer outcome dropped: malformed row (%s)", type(e).__name__)
            return

        async def go(conn):
            await conn.execute(
                "insert into turn_outcomes (day, lang, decision, features, interrupted, gap_ms, call_s)"
                " values (%s, %s, %s, %s, %s, %s, %s)",
                vals,
            )

        await self._run("add_outcome", go, mark_down=False)

    async def add_suggestion(self, lang: str, kind: str, text: str, embedding=None) -> int | None:
        """Store a pending lesson, or bump ``seen`` and ``last_day`` of a near-duplicate (cosine >= 0.92) of the same
        language and kind. Returns the row id, or None when nothing was written (offline, down, bad kind, no embedding).
        ``embedding`` is kept for the interface and ignored: the text is always embedded here, so every vector in the
        table lives in one space."""
        if not self.online or time.monotonic() < self._down_until:
            return None
        if kind not in KINDS or not isinstance(text, str) or not text.strip():
            log.warning("shared layer suggestion dropped: bad kind or empty text")
            return None
        lit = await self._vec_of("add_suggestion", text)
        if lit is None:
            return None

        async def go(conn):
            async with conn.transaction():
                cur = await conn.execute(
                    "select id from suggestions where lang = %s and kind = %s and embedding <=> %s::vector <= %s"
                    " order by embedding <=> %s::vector limit 1 for update",
                    (lang, kind, lit, 1.0 - DUP_COSINE, lit),
                )
                hit = await cur.fetchone()
                if hit:
                    await conn.execute(
                        "update suggestions set seen = seen + 1, last_day = current_date where id = %s", (hit[0],)
                    )
                    return hit[0]
                cur = await conn.execute(
                    "insert into suggestions (lang, kind, text, embedding) values (%s, %s, %s, %s::vector) returning id",
                    (lang, kind, text, lit),
                )
                return (await cur.fetchone())[0]

        return await self._run("add_suggestion", go, mark_down=False)

    async def accept(self, id: int, edited_text: str | None = None) -> bool:
        """A person accepts a pending suggestion: into ``knowledge`` as learned (question, fix, fact) or ``style``."""
        if not self.online:
            return False
        new_vec = None
        if edited_text is not None and edited_text.strip():
            new_vec = await self._vec_of("accept", edited_text)
            if new_vec is None:
                return False

        async def go(conn):
            async with conn.transaction():
                cur = await conn.execute(
                    "select lang, kind, text, embedding::text from suggestions where id = %s and status = 'pending'"
                    " for update",
                    (id,),
                )
                row = await cur.fetchone()
                if not row:
                    return False
                lang, kind, text, emb = row
                if new_vec is not None:
                    text, emb = edited_text.strip(), new_vec
                if kind == "style":
                    await conn.execute(
                        "insert into style (key, lang, text) values (%s, %s, %s)"
                        " on conflict (key, lang) do update set text = excluded.text, active = true, updated_at = now()",
                        (f"learned-{id}", lang, text),
                    )
                else:
                    await conn.execute(
                        "insert into knowledge (lang, topic, text, embedding, source)"
                        " values (%s, %s, %s, %s::vector, 'learned')",
                        (lang, kind, text, emb),
                    )
                await conn.execute(
                    "update suggestions set status = 'accepted', text = %s, embedding = %s::vector where id = %s",
                    (text, emb, id),
                )
                return True

        return bool(await self._run("accept", go, False))

    async def reject(self, id: int) -> bool:
        async def go(conn):
            cur = await conn.execute(
                "update suggestions set status = 'rejected' where id = %s and status = 'pending'", (id,)
            )
            return cur.rowcount > 0

        return bool(await self._run("reject", go, False))

    # the curated sync (tools/sync_swarm_knowledge.py)

    async def apply_schema(self) -> None:
        """Create the extension and the four tables if they are missing. Raises: a person runs this."""
        import psycopg

        async with await psycopg.AsyncConnection.connect(self.dsn, autocommit=True, connect_timeout=15) as conn:
            await conn.execute(SCHEMA.read_text())

    async def replace_curated(self, lang: str, topic: str, rows: list[dict]) -> int:
        """Replace the curated rows of one file wholesale; learned rows are left alone, and a curated row a person
        switched off stays off if the same text comes back. Raises on failure."""
        import psycopg

        vecs = await _embed([f"{r['title']}. {r['text']}" if r.get("title") else r["text"] for r in rows]) if rows else []
        async with await psycopg.AsyncConnection.connect(self.dsn, connect_timeout=15, prepare_threshold=None) as conn:
            async with conn.transaction():
                cur = await conn.execute(
                    "select text from knowledge where lang = %s and topic = %s and source = 'curated' and not active",
                    (lang, topic),
                )
                off = {r[0] for r in await cur.fetchall()}
                await conn.execute(
                    "delete from knowledge where lang = %s and topic = %s and source = 'curated'", (lang, topic)
                )
                for r, v in zip(rows, vecs):
                    await conn.execute(
                        "insert into knowledge (lang, topic, text, embedding, source, active)"
                        " values (%s, %s, %s, %s::vector, 'curated', %s)",
                        (lang, topic, r["text"], _vec(v), r["text"] not in off),
                    )
        return len(rows)

    async def prune_curated(self, keep: set[tuple[str, str]], langs: set[str] | tuple[str, ...]) -> int:
        """Delete the curated rows of files that no longer exist, in the languages given only. Raises on failure."""
        import psycopg

        async with await psycopg.AsyncConnection.connect(self.dsn, connect_timeout=15, prepare_threshold=None) as conn:
            async with conn.transaction():
                cur = await conn.execute("select distinct lang, topic from knowledge where source = 'curated'")
                gone = [(lg, tp) for lg, tp in await cur.fetchall() if lg in langs and (lg, tp) not in keep]
                for lg, tp in gone:
                    await conn.execute(
                        "delete from knowledge where lang = %s and topic = %s and source = 'curated'", (lg, tp)
                    )
        return len(gone)
