"""Lessons at call end (spec amendment 2026-11-05): distilled from the call, scrubbed, stored pending, never in the way of `bye_ack`."""
import asyncio
import json
import time
from types import SimpleNamespace

import pytest

from shared import distil
from shared.store import SCHEMA
from tests.test_call_events import FakeSocket
from voice.bot import Phone, finish_call, learner_for

UID, SESSION = "u-secret-uid", "s-secret-session"
CALL = [
    {"role": "system", "content": "You are the Swarm."},
    {"role": "user", "content": "[knowledge: Hearts refill one every half hour.]\nhi, I'm Ana from Rua Augusta, how do hearts refill?"},
    {"role": "assistant", "content": "They refill when you watch an ad."},
    {"role": "user", "content": "no, they come back one every half hour on their own"},
    {"role": "assistant", "content": "You're right, one heart every half hour."},
]


class FakeClient:
    """Stands in for the OpenAI client: answers the distil and the scrub from a script, records what it was sent."""

    def __init__(self, *answers, hang: bool = False):
        self.answers, self.hang, self.sent = list(answers), hang, []
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self.create))

    async def create(self, **kw):
        self.sent.append(kw)
        if self.hang:
            await asyncio.sleep(3600)
        usage = SimpleNamespace(prompt_tokens=10, completion_tokens=5, prompt_tokens_details=None)
        return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps(self.answers.pop(0))))], usage=usage)


class FakeShared:
    online = True

    def __init__(self):
        self.added = []

    async def add_suggestion(self, *args, **kw):
        self.added.append((args, kw))
        return len(self.added)


LESSON = "Hearts refill on their own, one every half hour; watching an ad is not how they come back."
DRAFTS = {"lessons": [
    {"kind": "fix", "text": LESSON},
    {"kind": "fact", "text": "Ana likes Hidden Word best."},
    {"kind": "fact", "text": "A player on Rua Augusta asked about hearts."},
]}


async def test_personal_items_refused(caplog):
    # The scrub refuses the name; it lets the street through, and the last check still catches it.
    scrub = {"verdicts": [
        {"n": 0, "verdict": "keep", "text": LESSON, "reason": ""},
        {"n": 1, "verdict": "refuse", "text": "Someone likes Hidden Word best.", "reason": "name"},
        {"n": 2, "verdict": "keep", "text": "A player on Rua Augusta asked about hearts.", "reason": ""},
    ]}
    client, shared = FakeClient(DRAFTS, scrub), FakeShared()
    caplog.set_level("DEBUG")
    stored = await distil.learn(shared, distil.transcript_of(CALL), "en", client)
    assert stored == 1
    assert [a for a, _ in shared.added] == [("en", "fix", LESSON)]
    assert "Ana" not in caplog.text and "Augusta" not in caplog.text and "Hidden Word" not in caplog.text  # counts only
    # the distil saw the cleaned call, never the knowledge lines or the system prompt
    first = json.dumps(client.sent[0]["messages"])
    assert "[knowledge:" not in first and "You are the Swarm" not in first
    assert client.sent[0]["model"] == "gpt-6-luna" and client.sent[0]["reasoning_effort"] == "low"
    assert client.sent[0]["response_format"] == {"type": "json_object"}


@pytest.mark.parametrize("text", [
    "The player said she is 9 years old.",
    "The user likes the blue theme.",
    "O jogador disse que mora em Lisboa.",
    "Write to help@example.com for refunds.",
    "See https://example.com for the rules.",
    "Call +55 11 99999-8888 for help.",
    "Her dog Rex loves puzzles.",
    "The call was on 2026-11-05.",
    "It costs $5 to remove ads.",
    'Someone asked "is my score good?"',
    "A 9-year-old player finds Insane too hard.",
    "Uma criança de nove anos achou o Insane difícil.",
    "They have two kids who love Teacups.",
    "They live near the beach and play on the bus.",
    "The player prefers dark mode and plays at night.",
    "Eles moram no Recife e jogam de manhã.",
    "Ellos viven en Monterrey y juegan de noche.",
    "The player's sister loves Hidden Word.",
    "A cat named Rex watches every Bridges game.",
    "Find the player on Instagram @anasilva_99x",
    "Removing ads costs five dollars.",
    "Someone said 'my score is bad' after Insane.",
    "Someone said ‘my score is bad’ after Insane.",
    "A dyslexic player finds Hidden Word hard.",
    "Alguém disse que o Insane é difícil.",
    "Alguien dijo que el Insane es difícil.",
    "Players with ADHD lose focus on long boards.",
    "Un niño de diez años encontró el Insane difícil.",
])
def test_the_last_check_refuses_when_in_doubt(text):
    assert distil.local_refusal(text) is not None


@pytest.mark.parametrize("text", [
    LESSON,
    "Hidden Word has five letters and six rows.",
    "Keep a reply to two short sentences on the phone.",
    "Os corações voltam sozinhos, um a cada meia hora.",
    "Los corazones son cinco y vuelven solos, uno cada media hora.",
    "Don't read the rules aloud; it's better to give one step.",
])
def test_the_last_check_keeps_general_lessons(text):
    assert distil.local_refusal(text) is None


async def test_a_missing_or_malformed_verdict_is_a_refusal():
    client, shared = FakeClient(DRAFTS, {"verdicts": [{"n": 0, "verdict": "maybe", "text": LESSON}]}), FakeShared()
    assert await distil.learn(shared, distil.transcript_of(CALL), "en", client) == 0 and shared.added == []


async def test_no_ids_stored():
    scrub = {"verdicts": [{"n": 0, "verdict": "keep", "text": LESSON, "reason": ""}, {"n": 1, "verdict": "refuse", "text": "", "reason": "name"}, {"n": 2, "verdict": "refuse", "text": "", "reason": "place"}]}
    client, shared, rows = FakeClient(DRAFTS, scrub), FakeShared(), []
    memory = SimpleNamespace(forgotten=[], client=client)
    learn = learner_for(shared, "en", memory, on_usage=lambda u: rows.append(u))
    task = learn(CALL)
    await task
    assert shared.added == [(("en", "fix", LESSON), {})]
    blob = json.dumps(shared.added) + json.dumps([m for kw in client.sent for m in kw["messages"]])
    assert UID not in blob and SESSION not in blob
    assert len(rows) == 2  # the two passes' costs go to the ledger, by the caller
    # the table itself has no place for one
    ddl = SCHEMA.read_text().split("create table if not exists suggestions", 1)[1].split(");", 1)[0]
    assert not any(w in ddl for w in ("uid", "user", "session"))


async def test_a_call_with_a_forget_request_teaches_nothing():
    client, shared = FakeClient(DRAFTS), FakeShared()
    learn = learner_for(shared, "en", SimpleNamespace(forgotten=["Ana's address"], client=client))
    assert learn(CALL) is None and client.sent == []


async def test_offline_or_unknown_language_teaches_nothing():
    client = FakeClient(DRAFTS)
    assert learner_for(None, "en", SimpleNamespace(forgotten=[], client=client)) is None
    off = FakeShared()
    off.online = False
    assert learner_for(off, "en", SimpleNamespace(forgotten=[], client=client)) is None
    assert learner_for(FakeShared(), "fr", SimpleNamespace(forgotten=[], client=client)) is None
    assert learner_for(FakeShared(), "en", SimpleNamespace(forgotten=[], client=None)) is None


class FakeMemory:
    def __init__(self):
        self.key, self.forgotten = None, []

    async def end(self, messages):
        await asyncio.sleep(0.01)


async def test_end_never_waits():
    sock, shared = FakeSocket(), FakeShared()
    phone = Phone(sock)
    client = FakeClient(hang=True)
    learn = learner_for(shared, "en", SimpleNamespace(forgotten=[], client=client), timeout=30.0)
    started = time.perf_counter()
    await finish_call(sock, phone, FakeMemory(), CALL, "bye", learn=learn)
    assert time.perf_counter() - started < 0.5
    assert sock.sent[-1] == {"type": "bye_ack"} and sock.closed == 1000
    await asyncio.sleep(0.01)
    assert client.sent and len(distil.pending_tasks()) == 1  # the distil is still waiting on its model, in the background
    await distil.cancel_pending()
    assert distil.pending_tasks() == set() and shared.added == []


async def test_a_hung_model_is_given_up_on_its_timeout(caplog):
    client, shared = FakeClient(hang=True), FakeShared()
    task = distil.schedule(shared, distil.transcript_of(CALL), "en", client, timeout=0.05)
    await asyncio.wait_for(task, 2)
    assert shared.added == [] and distil.pending_tasks() == set() and "timed out" in caplog.text


async def test_a_call_that_ends_gone_still_teaches():
    """The ruling of 2026-11-05: a phone that went away gets no memory and no bye_ack, but its call's lessons are drafted."""
    sock, called = FakeSocket(), []
    memory = FakeMemory()
    ended = []
    memory.end = lambda m: ended.append(m)
    await finish_call(sock, Phone(sock), memory, CALL, "gone", learn=lambda m: called.append(m))
    assert called == [CALL] and ended == [] and sock.sent == [] and sock.closed is None

    def boom(_):
        raise RuntimeError("Ana")

    await finish_call(sock, Phone(sock), FakeMemory(), CALL, "gone", learn=boom)  # never raises


async def test_a_learner_that_raises_never_costs_the_bye_ack():
    sock = FakeSocket()

    def boom(_):
        raise RuntimeError("Ana")

    await finish_call(sock, Phone(sock), FakeMemory(), CALL, "bye", learn=boom)
    assert sock.sent[-1] == {"type": "bye_ack"}


async def test_a_failed_background_write_does_not_take_the_layer_down(monkeypatch):
    from shared import store as store_mod

    s = store_mod.SharedStore("postgresql://nobody@127.0.0.1:1/none")

    async def no_pool():
        raise OSError("no route")

    async def vec(*_):
        return "[0]"

    monkeypatch.setattr(s, "_get_pool", no_pool)
    monkeypatch.setattr(s, "_vec_of", vec)
    assert await s.add_suggestion("en", "fact", "A fact.") is None
    await s.add_outcome({"lang": "en", "decision": 1, "features": [0.1], "interrupted": False, "gap_ms": 1, "call_s": 1})
    assert not s.down  # writes dropped quietly; reads still go to the database
    assert await s.pending(1) == [] and s.down  # a failed read still marks it down


def test_review_table_strips_control_characters():
    import importlib.util
    from pathlib import Path

    spec = importlib.util.spec_from_file_location("review", Path(__file__).resolve().parents[3] / "tools" / "review_swarm_suggestions.py")
    review = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(review)
    row = {"id": 1, "lang": "en", "kind": "fact", "seen": 2, "first_day": "2026-11-05", "last_day": "2026-11-05", "text": "a\x1b[2Jb\nc\u202ed"}
    out = review.table([row])
    assert "\x1b" not in out and "\u202e" not in out and out.count("\n") == 1
