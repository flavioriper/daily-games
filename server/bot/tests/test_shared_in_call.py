"""The shared layer in the call: knowledge on the turn, style at call start, one numbers-only outcome per bot turn."""
import asyncio
import datetime as dt
import json
import time

from bot.cards import load_card
from shared.store import OUTCOME_KEYS
from tests.test_steer import DEFAULT, FakeClips, FakeJev, FakeLearner, ctx
from voice.bot import clean_transcript, read_style, with_style
from voice.outcomes import Outcomes, decision_code
from voice.prompt import system_prompt
from voice.steer import PolicySteer

ROWS = ["Hints: tap the bulb on any board to see one step.", "A hint never costs gold and never ends the streak."]
NOTE = "On the phone, keep a reply to two short sentences."
WORDS = "my name is Ana and I live in Lisbon, how do hints work"


class FakeShared:
    online = True

    def __init__(self, delay: float = 0.0):
        self.delay, self.asked, self.rows = delay, [], []

    async def knowledge_for(self, lang, text, k=4):
        self.asked.append((lang, text))
        await asyncio.sleep(self.delay)
        return list(ROWS)

    async def style_and_knobs_for(self, lang):
        await asyncio.sleep(self.delay)
        return [NOTE], {"speed": "1.1"}

    async def add_outcome(self, row):
        self.rows.append(row)


def steer_with(shared, events, budget=0.8):
    return PolicySteer(jev=FakeJev(), learner=FakeLearner(), slug="p", user_id="u-secret", default_decision=DEFAULT, clips=FakeClips(), on_event=events.append,
                       bridge_after_s=30.0, knowledge=(lambda t: shared.knowledge_for("en", t)) if shared else None, knowledge_budget_s=budget)


async def test_prompt_carries_knowledge_and_style():
    shared, events = FakeShared(), []
    card = with_style(load_card("en"), await read_style(shared, "en"))
    assert NOTE in system_prompt(card)
    assert "[knowledge:" in system_prompt(card)  # the prompt says what the lines are
    steer = steer_with(shared, events)
    c = ctx("how do hints work")
    await steer.on_context(c)
    content = c.messages[-1]["content"]
    assert all(f"[knowledge: {r}]" in content for r in ROWS) and content.endswith("\nhow do hints work")
    assert shared.asked == [("en", "how do hints work")]
    assert events[-1]["knowledge"] == 2 and ROWS[0] not in json.dumps(events[-1])  # a count, never the rows
    assert clean_transcript(c.messages) == [{"role": "user", "text": "how do hints work"}]  # the summary never sees them


async def test_slow_knowledge_misses_its_budget_and_the_turn_goes_on():
    shared, events = FakeShared(delay=5.0), []
    steer = steer_with(shared, events, budget=0.05)
    c = ctx("how do hints work")
    started = time.perf_counter()
    await steer.on_context(c)
    assert time.perf_counter() - started < 1.0
    assert "[knowledge:" not in c.messages[-1]["content"] and events[-1]["knowledge"] == 0


async def test_no_shared_layer_leaves_the_call_unchanged():
    events = []
    steer = steer_with(None, events)
    c = ctx("how do hints work")
    await steer.on_context(c)
    assert "[knowledge:" not in c.messages[-1]["content"]
    card = load_card("en")
    assert with_style(card, await read_style(None, "en")) == card
    assert await read_style(FakeShared(delay=5.0), "en", budget=0.05) == []  # slow style: the call starts without it


class Clock:
    def __init__(self):
        self.t = 100.0

    def __call__(self):
        return self.t


async def test_outcome_has_no_text():
    shared, events, clock = FakeShared(), [], Clock()
    out = Outcomes(shared, "en", clock=clock)
    steer = steer_with(shared, events)
    for words in (WORDS, "and what about the streak"):
        out.heard()
        c = ctx(words)
        await steer.on_context(c)
        out.on_event(events[-1])
        out.speaking()
        clock.t += 0.02
        out.done()
        clock.t += 0.03
    await out.end(call_s=42)
    await out.drain()
    assert len(shared.rows) == 2
    first, last = shared.rows
    for row in shared.rows:
        assert set(row) == set(OUTCOME_KEYS)
        assert isinstance(row["day"], dt.date) and not isinstance(row["day"], dt.datetime)
        assert row["lang"] == "en" and isinstance(row["decision"], int) and all(isinstance(x, float) for x in row["features"])
        assert all(not isinstance(v, str) for k, v in row.items() if k != "lang")
    kept = json.dumps(shared.rows, default=str)
    for secret in ("Ana", "Lisbon", "hints", "streak", "u-secret", "session"):
        assert secret not in kept
    assert first["gap_ms"] == 30 and not first["interrupted"] and first["call_s"] == 0
    assert last["call_s"] == 42 and last["gap_ms"] == -1  # no next speech after the last turn


async def test_speaking_over_the_bot_is_an_interruption():
    shared = FakeShared()
    out = Outcomes(shared, "en")
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": None, "text": "hello there"})
    out.speaking()
    out.heard()  # the user starts while the voice is still going
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": None})
    out.speaking()
    out.interrupt()  # the phone's tap
    await out.end(call_s=5)
    await out.drain()
    assert [r["interrupted"] for r in shared.rows] == [True, True]
    assert shared.rows[0]["gap_ms"] == 0 and shared.rows[0]["features"] == []


async def test_offline_and_non_turn_events_write_nothing():
    out = Outcomes(None, "en")
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": [0.1]})
    await out.end(call_s=3)
    await out.drain()
    shared = FakeShared()
    out = Outcomes(shared, "en")
    out.on_event({"kind": "memory_turn"})
    out.heard()
    await out.end(call_s=3)
    await out.drain()
    assert shared.rows == []


def test_decision_codes_are_distinct():
    from itertools import product

    from policy.labels import HEADS

    codes = {decision_code(dict(zip(HEADS, combo))) for combo in product(*HEADS.values())}
    assert len(codes) == 4 * 3 * 3 * 2 and min(codes) == 0


def test_the_call_reads_style_before_its_services_are_built():
    from tests.test_call_events import _json_until, _closed, _offline_deps

    shared, seen = FakeShared(), []

    from voice.bot import Services
    from pipecat.processors.frame_processor import FrameProcessor
    from pipecat.services.openai.llm import OpenAILLMService

    class Pass(FrameProcessor):
        async def process_frame(self, frame, direction):
            await super().process_frame(frame, direction)
            await self.push_frame(frame, direction)

    def services(card):
        seen.append(card)
        return Services(Pass(), OpenAILLMService(api_key="offline", settings=OpenAILLMService.Settings(model="gpt-6-luna")), Pass())

    client, _ = _offline_deps(shared=shared, services=services)
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_json({"type": "hello", "token": "t", "language": "en"})
        assert ws.receive_json()["type"] == "session"
        ws.send_json({"type": "bye"})
        _json_until(ws, "bye_ack")
        assert _closed(ws) == 1000
    assert seen and NOTE in seen[0].style and NOTE in system_prompt(seen[0])
    assert shared.rows == []  # no bot turn, no row


async def test_a_turn_the_voice_never_spoke_is_not_an_interruption():
    shared = FakeShared()
    out = Outcomes(shared, "en")
    out.on_event({"kind": "turn", "decision": {**DEFAULT, "stance": "hold"}, "raw_features": None})
    out.heard()  # a hold, a tool-only turn: no TTS, then the person speaks
    await out.end(call_s=4)
    await out.drain()
    assert len(shared.rows) == 1 and shared.rows[0]["interrupted"] is False and shared.rows[0]["gap_ms"] == -1


async def test_a_missed_stop_does_not_leak_into_the_next_row():
    shared, clock = FakeShared(), Clock()
    out = Outcomes(shared, "en", clock=clock)
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": None})
    out.speaking()
    out.heard()  # barge-in; the TTSStoppedFrame never comes
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": None})
    out.heard()  # the second turn never spoke
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": None})
    out.speaking()
    out.interrupt()  # the tap; no stop frame either
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": None})
    out.speaking()
    clock.t += 1.0
    out.done()
    clock.t += 0.5
    out.heard()
    await out.end(call_s=8)
    await out.drain()
    assert [(r["interrupted"], r["gap_ms"]) for r in shared.rows] == [(True, 0), (False, -1), (True, -1), (False, 500)]  # the tapped turn got no next speech before the next turn


async def test_call_length_lands_even_when_the_last_row_has_closed():
    shared = FakeShared()
    out = Outcomes(shared, "en")
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": [0.5]})
    out.speaking()
    out.done()
    out.heard()  # the row closes; then the person says bye with no bot turn after
    await out.end(call_s=9)
    await out.drain()
    assert len(shared.rows) == 1 and shared.rows[0]["call_s"] == 9 and shared.rows[0]["gap_ms"] >= 0


def test_a_bad_turn_event_never_raises():
    out = Outcomes(FakeShared(), "en")
    out.on_event({"kind": "turn", "decision": "not a dict", "raw_features": ["x"]})
    out.on_event({"kind": "turn", "decision": DEFAULT, "raw_features": 5})


async def test_knowledge_rows_are_capped_and_style_notes_are_one_line():
    from voice.steer import KNOWLEDGE_CHARS, knowledge_lines

    line = knowledge_lines(["word " * 400])
    assert line.count("\n") == 1 and len(line) <= KNOWLEDGE_CHARS + len("[knowledge: ]\n")

    class Multi(FakeShared):
        async def style_and_knobs_for(self, lang):
            return ["Keep it short.\n\nNever  list.", "  "], {}

    assert await read_style(Multi(), "en") == ["Keep it short. Never list."]


def test_tests_never_see_the_real_database():
    import os

    assert "NEON_SWARM_URL" not in os.environ
