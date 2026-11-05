"""The call's phone side: the screen tools' wording and checks, the see round trip, the pt/es memory requests, and the events pushed on the socket."""
import asyncio
import base64
import json
from types import SimpleNamespace

from agent.eye import Eye
from agent.tools import DIRECTIONS, IDLE, LOOK_WORDS, PLACES, SCREEN, Toolbox
from memory.turn import detect_request
from studio.card import Owner
from voice.bot import KindLog, Phone

DESKTOP = ("cursor", "input", "panel")
GOOD_ROWS = ["..##..", ".####.", "######", ".####.", "..##.."]


class FakeSocket:
    def __init__(self):
        self.sent: list[dict] = []
        self.state = SimpleNamespace()
        self.closed = None

    async def send_text(self, text: str) -> None:
        self.sent.append(json.loads(text))

    async def close(self, code: int = 1000) -> None:
        self.closed = code


class FakeAsk:
    """Stands in for gpt-6.1-terra: records every request, answers from a script."""

    def __init__(self, *answers):
        self.answers, self.seen = list(answers), []

    def __call__(self, content, timeout=None):
        assert timeout and timeout <= 13  # every terra call is bounded below its tool's timeout
        self.seen.append(content)
        return self.answers.pop(0), {"prompt_tokens": 10, "completion_tokens": 5}


def box(eye=None, look=None, emit=lambda e: None):
    return Toolbox(None, emit, owner=Owner(name="Swarm"), phone=True, eye=eye or Eye(ask=FakeAsk()), look=look)


async def run(b: Toolbox, tool: str, **args) -> dict:
    return await b.run(tool, args, 1)


def test_tool_words_have_no_desktop():
    assert LOOK_WORDS == ["ahead", "point", *DIRECTIONS]
    assert IDLE == ["ahead", "wander", "doze"]
    assert "point" in PLACES and not any("panel" in p for p in PLACES)
    assert box().names() == ["swarm", "move", "draw", "dots", "tone", "see"]
    for tool in SCREEN:
        words = [tool["description"]] + [json.dumps(p) for p in tool["properties"].values()]
        for w in words:
            for bad in DESKTOP:
                assert bad not in w.lower(), (tool["name"], bad)
        assert "[screen:" not in tool["description"]


async def test_draw_checks():
    b = box()
    assert "error" in await run(b, "draw", rows=["..#", "##"])
    assert "error" in await run(b, "draw", rows=GOOD_ROWS, palette={"#": "plaid"})
    assert "error" in await run(b, "draw", name="bank:nope")
    assert "error" in await run(b, "draw", name="bank:duck", rows=GOOD_ROWS)
    assert "error" in await run(b, "draw")
    assert "error" in await run(b, "draw", rows=["#" * 97])
    assert "error" in await run(b, "draw", name="bank:duck", size=2)
    assert "error" in await run(b, "draw", rows=GOOD_ROWS)  # rows need meant
    good = await run(b, "draw", rows=GOOD_ROWS, meant="a diamond", palette={"#": "#ffcc00", "o": "navy"}, seconds=10)
    assert good["draw"] == {"rows": GOOD_ROWS, "palette": {"#": "#ffcc00", "o": "navy"}, "seconds": 10} and b.drawn == "a diamond"
    assert (await run(b, "draw", name="bank:duck"))["draw"] == {"name": "bank:duck"}
    assert (await run(b, "draw", name="today"))["draw"] == {"name": "today"}
    assert (await run(b, "draw", clear=True))["draw"] == {"clear": True}


async def test_draw_a_subject_has_the_eye_write_its_rows():
    ask = FakeAsk({"rows": ["." * 12] * 5 + ["#" * 12] * 7})
    got = await run(box(eye=Eye(ask=ask)), "draw", subject="a rocket")
    assert got["draw"]["rows"] == ["." * 12] * 5 + ["#" * 12] * 7 and "subject" not in got["draw"]
    assert "a rocket" in ask.seen[0][0]["text"] and "a rocket" in got["summary"]


async def test_tone_checks():
    b = box()
    assert "error" in await run(b, "tone", tone="plaid")
    assert "error" in await run(b, "tone")
    assert "error" in await run(b, "tone", intensity="bright")
    assert "error" in await run(b, "tone", tone="gold", seconds=99)
    assert (await run(b, "tone", tone="#3366FF"))["tone"] == {"tone": "#3366ff"}
    assert (await run(b, "tone", tone="gold", intensity=1.4, seconds=3))["tone"] == {"tone": "gold", "intensity": 1.4, "seconds": 3}


async def test_dots_checks():
    b = box()
    assert "error" in await run(b, "dots")
    assert "error" in await run(b, "dots", add=100, remove=50)
    assert "error" in await run(b, "dots", add=0)
    assert "error" in await run(b, "dots", total=5000)
    assert "error" in await run(b, "dots", add=100, **{"from": "sky"})
    assert "error" in await run(b, "dots", remove=100, to="away")
    assert (await run(b, "dots", add=300, **{"from": "edges"}))["dots"] == {"add": 300, "from": "edges"}
    assert (await run(b, "dots", total=2000))["dots"] == {"total": 2000}


async def test_see_waits():
    sock, log = FakeSocket(), KindLog()
    phone = Phone(sock, see_s=1.0)
    ask = FakeAsk({"reads_as": "a duck", "ok": True, "fix": ""})
    b = box(eye=Eye(ask=ask), look=phone.look, emit=lambda e: log.add({"kind": "stage", **e}))
    await run(b, "draw", name="bank:duck")
    jpg = b"\xff\xd8 a tiny jpeg \xff\xd9"
    b64 = base64.b64encode(jpg).decode()

    async def answer():
        while not any(m.get("name") == "see" for m in sock.sent):
            await asyncio.sleep(0.01)
        ask_id = next(m["id"] for m in sock.sent if m.get("name") == "see")
        phone.on_text(json.dumps({"type": "seen", "id": ask_id, "jpg": b64, "w": 384, "h": 683}))

    answering = asyncio.ensure_future(answer())
    got = await run(b, "see")
    await answering
    assert "a duck" in got["summary"] and got["ok"] is True
    image = [p for p in ask.seen[-1] if p.get("type") == "image_url"]
    assert image and image[0]["image_url"]["url"] == "data:image/jpeg;base64," + b64
    assert "duck" in ask.seen[-1][0]["text"]  # the eye is told what was meant
    assert all(set(e) <= {"t", "session_id", "kind"} for e in log.items)
    assert b64 not in json.dumps(list(log.items)) and b64 not in json.dumps(sock.sent) and b64 not in json.dumps(got)

    async def look_at(**draw) -> list:
        """What the eye was asked after this drawing."""
        await run(b, "draw", **draw)
        sock.sent.clear()
        answering = asyncio.ensure_future(answer())
        got = await run(b, "see")
        await answering
        return [got, ask.seen[-1][0]["text"]]

    ask.answers += [{"reads_as": "a heart", "ok": True, "fix": ""}, {"reads_as": "a cat"}, {"reads_as": "a face", "ok": True, "fix": ""}]
    got, asked = await look_at(rows=GOOD_ROWS, meant="a heart")
    assert "a heart" in asked and got["ok"] is True
    got, asked = await look_at(name="today")
    assert "meant" not in asked and got["ok"] is None and "Compare" in got["summary"]  # an open look: the voice compares
    got, asked = await look_at(clear=True)
    assert "a face made of glowing dots" in asked  # nothing drawn: the face is what should show

    phone.see_s = 0.05
    late = await run(b, "see")
    assert "could not see" in json.dumps(late)
    assert phone.pending == {}


async def test_phone_messages_reach_their_handlers():
    sock = FakeSocket()
    phone = Phone(sock)
    got = []

    async def on(kind, msg):
        got.append((kind, msg.get("id")))

    phone.on_interrupt = lambda: on("interrupt", {})
    phone.on_forget = lambda i: on("forget", {"id": i})
    phone.on_bye = lambda: on("bye", {})
    for m in [{"type": "interrupt"}, {"type": "forget", "id": "f1"}, {"type": "forget"}, {"type": "bye"}, {"type": "nope"}]:
        phone.on_text(json.dumps(m))
    phone.on_text("not json")
    await asyncio.sleep(0.01)
    assert got == [("interrupt", None), ("forget", "f1"), ("bye", None)]

    phone.state("thinking")
    phone.state("thinking")
    phone.said("Hi there.")
    phone.send({"type": "memory", "op": "add", "id": "x", "text": "t"})
    await phone.flush()
    assert sock.sent == [{"type": "state", "name": "thinking"}, {"type": "said", "text": "Hi there."}, {"type": "memory", "op": "add", "id": "x", "text": "t"}]


async def test_said_when_a_sentence_starts():
    from pipecat.frames.frames import AggregatedTextFrame, TTSTextFrame

    from voice.clip_player import ClipOut

    said = []
    out = ClipOut(on_said=said.append)
    sentence = AggregatedTextFrame("[cheerful] Oh, a duck!  Nice.", "sentence")
    sentence.will_be_spoken = True
    word = TTSTextFrame("duck", "word")
    word.will_be_spoken = True
    skipped = AggregatedTextFrame("not spoken", "sentence")
    for f in (sentence, word, skipped):
        await out.watch(f)
    assert said == ["Oh, a duck! Nice."]


def test_a_guessed_turn_is_not_thinking():
    from voice.bot import state_of

    assert state_of({"stage": "policy", "speculative": True}) is None and state_of({"stage": "jev", "speculative": True}) is None
    assert state_of({"stage": "policy", "speculative": False}) == "thinking" and state_of({"stage": "jev"}) == "thinking"
    assert state_of({"stage": "speaking"}) == "speaking" and state_of({"stage": "hearing"}) == "listening"


def test_forget_patterns_pt_es():
    assert detect_request("esquece isso") == "forget"
    assert detect_request("olvida eso") == "forget"
    assert detect_request("por favor, esqueça isso que eu disse") == "forget"
    assert detect_request("no recuerdes eso") == "forget"
    assert detect_request("isso está errado") == "wrong"
    assert detect_request("eso no es verdad") == "wrong"
    assert detect_request("forget that") == "forget"
    assert detect_request("eu gosto de xadrez") is None


# ---- the call end to end, offline: the real pipeline with stand-in ears, brain and voice ----


def _offline_deps(**over):
    from fastapi.testclient import TestClient

    from bot.app import Deps, build_app
    from pipecat.processors.frame_processor import FrameProcessor
    from pipecat.services.openai.llm import OpenAILLMService
    from policy.jev import NoJev
    from voice.bot import Services

    class Pass(FrameProcessor):
        async def process_frame(self, frame, direction):
            await super().process_frame(frame, direction)
            await self.push_frame(frame, direction)

    def services(card):
        return Services(Pass(), OpenAILLMService(api_key="offline", settings=OpenAILLMService.Settings(model="gpt-6-luna")), Pass())

    log = KindLog()
    fields = dict(verify=lambda token: "u1", services=services, jev=lambda: NoJev(), eye=Eye(ask=FakeAsk()), events=log)
    fields.update(over)
    return TestClient(build_app(Deps(**fields))), log


def _json_until(ws, kind: str) -> list[dict]:
    """Text messages up to and including the first of `kind` (audio frames skipped)."""
    out = []
    while True:
        frame = ws.receive()
        if frame.get("text"):
            out.append(json.loads(frame["text"]))
            if out[-1].get("type") == kind:
                return out


def _closed(ws) -> int:
    while True:
        frame = ws.receive()
        if frame["type"] == "websocket.close":
            return frame["code"]


def test_bye_sends_the_memory_then_the_ack_and_closes():
    client, log = _offline_deps()
    memory = {"facts": [{"id": "f1", "text": "Their dog is called Biscuit", "since": "2026-11-01T10:00:00Z"}], "episodes": []}
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_json({"type": "hello", "token": "t", "language": "en", "memory": memory})
        assert ws.receive_json()["type"] == "session"
        got = _json_until(ws, "said")
        assert got[-1]["text"].startswith("Hi, I'm Swarm") and {"type": "state", "name": "speaking"} in got  # the greeting's line, before its clip
        ws.send_json({"type": "forget", "id": "f1"})
        assert _json_until(ws, "memory")[-1] == {"type": "memory", "op": "forget", "id": "f1", "text": ""}
        ws.send_json({"type": "bye"})
        got = _json_until(ws, "bye_ack")
        assert {"type": "state", "name": "remembering"} in got
        assert _closed(ws) == 1000
    assert all(set(e) == {"t", "session_id", "kind"} for e in log.items)
    kept = json.dumps(list(log.items))
    assert "Biscuit" not in kept and "Swarm" not in kept and "connected" in {e["kind"] for e in log.items}


def test_the_cap_says_goodbye_then_ends_like_a_bye():
    client, _ = _offline_deps(cap_seconds=0.5)
    with client.websocket_connect("/ws/bot") as ws:
        ws.send_json({"type": "hello", "token": "t", "language": "pt"})
        assert ws.receive_json()["type"] == "session"
        got = _json_until(ws, "bye_ack")
        assert {"type": "said", "text": "Deu nossos quinze minutos! Adorei conversar com você. Volta logo, tá?"} in got
        assert _closed(ws) == 1000
