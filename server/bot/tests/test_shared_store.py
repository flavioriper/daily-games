"""The shared layer's store. Offline tests always run; database tests only with SWARM_TEST_DSN (a dev Neon branch)."""
import importlib.util
import os
import re
import sys
import time
from pathlib import Path

import numpy as np
import pytest

import shared.store as store_mod
from shared.store import DIM, SharedStore, embed_texts as embed, parse_markdown

KNOWLEDGE = Path(__file__).resolve().parent.parent / "knowledge"
DSN = os.environ.get("SWARM_TEST_DSN")
needs_db = pytest.mark.skipif(not DSN, reason="SWARM_TEST_DSN not set")


async def test_offline_store_is_empty():
    s = SharedStore(None)
    assert await s.knowledge_for("en", "how do hints work") == []
    assert await s.style_for("en") == []
    assert await s.knobs_for("en") == {}
    assert await s.pending(10) == []
    await s.add_outcome({"lang": "en", "decision": 1, "features": [0.1], "interrupted": False, "gap_ms": 5, "call_s": 9})
    assert await s.add_suggestion("en", "fact", "A fact.", np.zeros(DIM)) is None
    assert await s.accept(1) is False
    assert await s.reject(1) is False


async def test_outcome_drops_anything_but_numbers_without_raising(caplog):
    s = SharedStore("postgresql://nobody@127.0.0.1:1/none")  # would fail if it ever tried to write
    good = {"lang": "en", "decision": 1, "features": [0.1], "interrupted": False, "gap_ms": 1, "call_s": 1}
    await s.add_outcome({**good, "uid": "u-secret"})  # an unknown key: dropped, the value never logged
    await s.add_outcome({**good, "decision": "not a number"})
    await s.add_outcome({"lang": "en"})
    await s.add_outcome(None)
    assert "u-secret" not in caplog.text and s._down_until == 0.0  # none of them reached the database


async def test_unreachable_database_answers_empty_then_stays_down(monkeypatch):
    monkeypatch.setattr(store_mod, "READ_TIMEOUT_S", 0.5)
    s = SharedStore("postgresql://nobody@127.0.0.1:1/none?connect_timeout=1")
    assert await s.knowledge_for("en", "hello there") == []
    assert s._down_until > time.monotonic()
    t0 = time.monotonic()  # inside the memo every call answers at once
    assert await s.knowledge_for("en", "hello again") == []
    assert await s.style_for("en") == [] and await s.pending(5) == []
    await s.add_outcome({"lang": "en", "decision": 1, "features": [0.1], "interrupted": False, "gap_ms": 5, "call_s": 9})
    assert await s.add_suggestion("en", "fact", "A fact.") is None
    assert time.monotonic() - t0 < 0.2
    await s.close()


async def test_a_failing_embedder_is_guarded(monkeypatch):
    def boom(texts):
        raise RuntimeError("no model")

    monkeypatch.setattr(store_mod, "embed_texts", boom)
    s = SharedStore("postgresql://nobody@127.0.0.1:1/none")
    assert await s.knowledge_for("en", "hello") == []
    assert await s.add_suggestion("en", "fact", "A fact.") is None
    assert await s.accept(1, "edited") is False
    assert s._down_until == 0.0  # an embedder failure is not a database outage


async def test_a_slow_embedder_times_out(monkeypatch):
    monkeypatch.setattr(store_mod, "EMBED_TIMEOUT_S", 0.2)
    monkeypatch.setattr(store_mod, "embed_texts", lambda texts: time.sleep(1) or None)
    s = SharedStore("postgresql://nobody@127.0.0.1:1/none")
    t0 = time.monotonic()
    assert await s.knowledge_for("en", "hello") == []
    assert time.monotonic() - t0 < 0.8


def _tool():
    path = Path(__file__).resolve().parents[3] / "tools" / "sync_swarm_knowledge.py"
    if not path.exists():
        pytest.skip("the tools folder is not beside the server")
    spec = importlib.util.spec_from_file_location("sync_swarm_knowledge", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


async def test_sync_refuses_to_wipe(tmp_path, monkeypatch):
    tool = _tool()
    monkeypatch.setenv("NEON_SWARM_URL", "postgresql://nobody@127.0.0.1:1/none")  # never reached
    monkeypatch.setattr(sys, "argv", ["sync", "--knowledge", str(tmp_path)])  # no files at all
    assert await tool.main() == 1
    (tmp_path / "en").mkdir()
    (tmp_path / "en" / "a.md").write_text("# A\n\nOne.\n")  # pt and es are missing
    monkeypatch.setattr(sys, "argv", ["sync", "--knowledge", str(tmp_path)])
    assert await tool.main() == 1
    for lang in ("pt", "es"):
        (tmp_path / lang).mkdir()
        (tmp_path / lang / "a.md").write_text("# A\n")  # a file with no paragraphs
    assert await tool.main() == 1
    monkeypatch.setattr(sys, "argv", ["sync", "--dry-run", "--knowledge", str(tmp_path)])
    assert await tool.main() == 1  # even a dry run says so


def test_markdown_rows():
    md = "# Hints\n\nThe bulb gives a hint\nwhen you are stuck.\n\n\nUndo is the turned-back arrow.\n"
    rows = parse_markdown("en", "play", md)
    assert rows == [
        {"lang": "en", "topic": "play", "title": "Hints", "text": "The bulb gives a hint when you are stuck."},
        {"lang": "en", "topic": "play", "title": "Hints", "text": "Undo is the turned-back arrow."},
    ]


def test_knowledge_files_are_parallel_and_clean():
    topics = {lang: sorted(p.stem for p in (KNOWLEDGE / lang).glob("*.md")) for lang in ("en", "pt", "es")}
    assert topics["en"] == topics["pt"] == topics["es"] and topics["en"]
    for t in topics["en"]:
        counts = {lang: len(parse_markdown(lang, t, (KNOWLEDGE / lang / f"{t}.md").read_text())) for lang in topics}
        assert len(set(counts.values())) == 1 and counts["en"] > 0, (t, counts)
        for lang in topics:
            for r in parse_markdown(lang, t, (KNOWLEDGE / lang / f"{t}.md").read_text()):
                assert r["title"] and len(r["text"]) < 700
                if t != "swarm":
                    assert "peeplet" not in r["text"].lower(), (lang, t)
                if t == "swarm":
                    assert "peeplet" in " ".join(x["text"] for x in parse_markdown(lang, t, (KNOWLEDGE / lang / "swarm.md").read_text())).lower()


def test_every_registry_board_is_in_the_knowledge():
    path = Path(__file__).resolve().parents[3] / "ui" / "registry.gd"
    if not path.exists():
        pytest.skip("the game's registry is not beside the server")
    reg = path.read_text()

    titles = re.findall(r'"title": "([^"]+)",\s*"blurb"', reg)
    text = " ".join(p.read_text() for p in (KNOWLEDGE / "en").glob("boards-*.md"))
    assert len(titles) == 44
    for t in titles:
        assert f"{t}. " in text, t


# database tests -------------------------------------------------------------------------------------------------

L = "xx"  # a test language: rows are deleted around every test


@pytest.fixture
async def db():
    s = SharedStore(DSN)
    await s.apply_schema()

    async def wipe():
        import psycopg

        async with await psycopg.AsyncConnection.connect(DSN, autocommit=True) as c:
            await c.execute("delete from knowledge where lang = %s", (L,))
            await c.execute("delete from style where lang = %s", (L,))
            await c.execute("delete from suggestions where lang = %s", (L,))
            await c.execute("delete from turn_outcomes where lang = %s", (L,))

    await wipe()
    yield s
    await wipe()
    await s.close()


@needs_db
async def test_sync_replaces_curated_and_keeps_learned(db):
    rows = parse_markdown(L, "play", "# Play\n\nThe bulb gives a hint when you are stuck.\n\nUndo is the turned-back arrow.\n")
    assert await db.replace_curated(L, "play", rows) == 2
    # a learned row in the same topic must survive a re-sync
    sid = await db.add_suggestion(L, "fact", "Hints can be bought with a short video.", embed(["Hints can be bought with a short video."])[0])
    assert await db.accept(sid) is True
    rows2 = parse_markdown(L, "play", "# Play\n\nHearts are rare.\n")
    assert await db.replace_curated(L, "play", rows2) == 1
    got = await db.knowledge_for(L, "tell me about hearts", k=10)
    assert got.count("Hearts are rare.") == 1
    assert "The bulb gives a hint when you are stuck." not in got
    assert "Hints can be bought with a short video." in got
    assert await db.prune_curated({(L, "other")}, [L]) >= 1
    assert "Hearts are rare." not in await db.knowledge_for(L, "hearts", k=10)
    assert "Hints can be bought with a short video." in await db.knowledge_for(L, "hints", k=10)


@needs_db
async def test_knowledge_is_retrieved_by_meaning_and_language(db):
    await db.replace_curated(L, "a", parse_markdown(L, "a", "# A\n\nThe bulb is the hint button; it shows the next step.\n\nThe weather in Lisbon is mild in spring.\n"))
    await db.replace_curated("xy", "a", parse_markdown("xy", "a", "# A\n\nThe bulb in another language.\n"))
    try:
        top = await db.knowledge_for(L, "how do I get a hint?", k=1)
        assert top == ["The bulb is the hint button; it shows the next step."]
        assert len(await db.knowledge_for(L, "anything", k=4)) == 2
        assert await db.knowledge_for("zz", "hint") == []
    finally:
        await db.replace_curated("xy", "a", [])


@needs_db
async def test_style_and_knobs(db):
    import psycopg

    async with await psycopg.AsyncConnection.connect(DSN, autocommit=True) as c:
        await c.execute("insert into style (key, lang, text) values ('a-note', %s, 'Be brief.'), ('knob.voice_speed', %s, '1.1'),"
                        " ('z-off', %s, 'x')", (L, L, L))
        await c.execute("update style set active = false where key = 'z-off' and lang = %s", (L,))
    assert await db.style_for(L) == ["Be brief."]
    assert await db.knobs_for(L) == {"voice_speed": "1.1"}


@needs_db
async def test_suggestions_dedupe_review_and_accept(db):
    a = "Players often ask why the bulb did not give a hint."
    e = embed([a])[0]
    first = await db.add_suggestion(L, "question", a, e)
    again = await db.add_suggestion(L, "question", a, e)
    assert first == again
    other = await db.add_suggestion(L, "style", "Keep answers to one sentence.", embed(["Keep answers to one sentence."])[0])
    assert other != first
    # a different lesson is its own suggestion, however close the topic (cosine under 0.92)
    similar = await db.add_suggestion(L, "question", "Players often ask what the bulb is for.")
    assert similar not in (first, other)
    # the same text under another kind is its own suggestion
    assert await db.add_suggestion(L, "fact", a, e) not in (first, other)
    pend = [p for p in await db.pending(100) if p["lang"] == L]
    assert pend[0]["id"] == first and pend[0]["seen"] == 2
    assert {"id", "lang", "kind", "text", "seen", "first_day", "last_day"} <= set(pend[0])
    # accept a style item with an edit, reject a fact
    assert await db.accept(other, "Keep answers short.") is True
    assert await db.style_for(L) == ["Keep answers short."]
    pend = [p for p in await db.pending(100) if p["lang"] == L]
    fact = [p["id"] for p in pend if p["kind"] == "fact"][0]
    assert await db.reject(fact) is True
    assert await db.reject(fact) is False
    assert await db.accept(fact) is False
    # accepting a question lands in knowledge as learned and is no longer pending
    assert await db.accept(first) is True
    assert a in await db.knowledge_for(L, "why did the bulb not hint?", k=4)
    assert [p["id"] for p in await db.pending(100) if p["lang"] == L] == [similar]


@needs_db
async def test_outcomes_are_numbers_only(db):
    await db.add_outcome({"lang": L, "decision": 2, "features": [0.25, -1.5], "interrupted": True, "gap_ms": 420, "call_s": 61})
    import psycopg

    async with await psycopg.AsyncConnection.connect(DSN, autocommit=True) as c:
        cur = await c.execute("select day, decision, features, interrupted, gap_ms, call_s from turn_outcomes where lang = %s", (L,))
        rows = await cur.fetchall()
        cols = await c.execute("select column_name from information_schema.columns where table_name = 'turn_outcomes'")
        names = {r[0] for r in await cols.fetchall()}
    assert len(rows) == 1 and rows[0][1:] == (2, [0.25, -1.5], True, 420, 61)
    assert names == {"day", "lang", "decision", "features", "interrupted", "gap_ms", "call_s"}


@needs_db
async def test_a_switched_off_curated_row_stays_off(db):
    rows = parse_markdown(L, "off", "# Off\n\nKeep me off.\n\nKeep me on.\n")
    await db.replace_curated(L, "off", rows)
    import psycopg

    async with await psycopg.AsyncConnection.connect(DSN, autocommit=True) as c:
        await c.execute("update knowledge set active = false where lang = %s and text = 'Keep me off.'", (L,))
    await db.replace_curated(L, "off", rows)
    assert await db.knowledge_for(L, "Keep me", k=10) == ["Keep me on."]
    # a pruned language only touches the languages asked for
    assert await db.prune_curated(set(), ["zz"]) == 0
    assert await db.knowledge_for(L, "Keep me", k=10) == ["Keep me on."]


@needs_db
@pytest.mark.parametrize(
    "lang, query, needle",
    [
        ("en", "how do hints work?", "The bulb gives a hint"),
        ("en", "who are you?", "The Swarm is a warm"),
        ("pt", "como funciona a dica?", "A lâmpada dá uma dica"),
        ("pt", "quem é você?", "O Enxame é um companheiro"),
        ("es", "¿cómo funciona la pista?", "La bombilla da una pista"),
        ("es", "¿quién eres?", "El Enjambre es un compañero"),
    ],
)
async def test_golden_queries_on_the_real_knowledge(lang, query, needle):
    """Run against the synced knowledge on the dev branch (tools/sync_swarm_knowledge.py --dev)."""
    got = await SharedStore(DSN).knowledge_for(lang, query, k=4)
    assert any(g.startswith(needle) for g in got), got
