"""The device-fed memory: what the phone sends in the hello, held in RAM for the call, every change pushed back through emit."""
import numpy as np
import torch

from memory.device import DeviceHub, DeviceStore
from memory.embed import embed
from memory.turn import MemoryTurn, Request

PAYLOAD = {
    "facts": [
        {"id": "f1", "text": "Their dog is called Biscuit", "since": "2026-11-01T10:00:00Z"},
        {"id": "f2", "text": "They play Hidden Word every morning", "since": "2026-11-03T08:00:00Z"},
    ],
    "episodes": [{"id": "e1", "at": "2026-11-03T09:00:00Z", "summary": "They talked about a hard Bridges board and gave up on Insane."}],
}


def collect():
    sent = []
    return sent, sent.append


async def test_round_trip():
    sent, emit = collect()
    store = DeviceStore(PAYLOAD, emit)
    facts = await store.facts_for("peeplet", "u")
    assert len(facts) == 2 and {f.id for f in facts} == {"f1", "f2"}
    assert all(f.embedding.shape == (384,) and np.linalg.norm(f.embedding) > 0.9 for f in facts)
    episodes = await store.episodes_for("peeplet", "u")
    assert [e.id for e in episodes] == ["e1"] and episodes[0].created_at.startswith("2026-11-03")
    assert sent == []  # loading writes nothing back

    fid = await store.add_fact("peeplet", "u", "Their sister lives in Porto", embed(["Their sister lives in Porto"])[0])
    assert sent[-1] == {"type": "memory", "op": "add", "id": fid, "text": "Their sister lives in Porto"}
    assert len(await store.facts_for("peeplet", "u")) == 3

    await store.expire_fact("f1")
    assert sent[-1] == {"type": "memory", "op": "forget", "id": "f1", "text": ""}
    await store.forget_fact("peeplet", "u", "f2", "They play Hidden Word every morning")
    assert sent[-1] == {"type": "memory", "op": "forget", "id": "f2", "text": ""}
    assert [f.id for f in await store.facts_for("peeplet", "u")] == [fid]

    await store.add_episode("peeplet", "u", "s1-abc", "A short chat about Teacups.", embed(["A short chat about Teacups."])[0])
    assert sent[-1] == {"type": "memory", "op": "episode", "id": "s1-abc", "text": "A short chat about Teacups."}
    assert len(await store.episodes_for("peeplet", "u")) == 2
    assert (await store.counts("peeplet", "u"))["facts"] == 1


def test_bad_items_dropped():
    payload = {"facts": [{"id": "a", "since": "x"}, {"id": "b", "text": "x" * 400}, {"text": "no id"}, {"id": "c", "text": "kept"}, "junk"],
               "episodes": [{"id": "e", "at": "2026-11-01"}, {"id": "e2", "summary": "y" * 301}, {"id": "e3", "at": "2026-11-02", "summary": "kept too"}]}
    store = DeviceStore(payload, lambda m: None)
    assert [f.text for f in store.facts] == ["kept"]
    assert [e.summary for e in store.episodes] == ["kept too"]
    assert DeviceStore(None, lambda m: None).facts == []
    assert DeviceStore({"facts": "nope"}, lambda m: None).facts == []


async def test_writes_fit_the_phone_limit():
    sent, emit = collect()
    store = DeviceStore({}, emit)
    long = "word " * 100
    await store.add_episode("p", "u", "s", long, embed([long])[0])
    assert len(sent[-1]["text"]) <= 300
    await store.update_episode("s", "Scrubbed.", embed(["Scrubbed."])[0])
    assert sent[-1] == {"type": "memory", "op": "episode", "id": "s", "text": "Scrubbed."}
    assert [e.summary for e in await store.episodes_for("p", "u")] == ["Scrubbed."]


async def test_notes_stay_in_ram():
    sent, emit = collect()
    store = DeviceStore({}, emit)
    await store.add_note("p", "u", "s1", "They are tired today")
    assert await store.notes_for("s1") == ["They are tired today"]
    await store.clear_notes("s1")
    assert await store.notes_for("s1") == []
    await store.add_note("p", "u", "s1", "again")
    await store.clear_stale_notes("p", "u")
    assert await store.notes_for("s1") == []
    await store.log_event("p", "u", {"kind": "recall"})
    assert sent == []  # short term and the event log never reach the phone


async def test_memory_turn_runs_on_the_device_hub(card):
    """turn.py's own calls, unchanged, against the device store: load, then a forget."""
    sent, emit = collect()
    hub = DeviceHub(DeviceStore(PAYLOAD, emit))
    assert hub.status == "up" and await hub.ensure()
    events = []
    turn = MemoryTurn(hub, card, "u", "s1", emit=lambda **e: events.append(e))
    await turn._load()
    assert turn.index.loaded and sorted(turn.index.facts.texts) == sorted(f["text"] for f in PAYLOAD["facts"])
    assert turn.index.episodes.texts == [PAYLOAD["episodes"][0]["summary"]]
    assert turn.key in hub.live
    t = torch.tensor(embed(["forget that"])[0])
    await turn._apply("t1", Request("forget", "f1", "Their dog is called Biscuit"), t, t, None)
    assert sent[-1] == {"type": "memory", "op": "forget", "id": "f1", "text": ""}
    assert events[-1]["action"] == "forget" and "f1" not in [m[0] for m in turn.index.facts.meta]
    await turn.end([])
    assert turn.key not in hub.live
