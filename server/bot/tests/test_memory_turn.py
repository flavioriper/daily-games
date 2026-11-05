"""The memory path's request detector. The Postgres-backed turn tests went with the hub in the fork."""
from memory.turn import detect_request


def test_requests_are_detected():
    assert detect_request("please don't remember that") == "forget"
    assert detect_request("forget what I said") == "forget"
    assert detect_request("no, that's wrong") == "wrong"
    assert detect_request("do you remember my sister") is None


def test_remember_requests_are_detected():
    from memory.turn import asks_to_remember

    for text in ["Remember that I like chess.", "please remember my sister is called Ana", "Don't forget that I play on Sundays",
                 "Lembra que eu gosto de xadrez.", "lembre-se de que eu moro no Porto", "Não esquece que eu jogo xadrez",
                 "Recuerda que me gusta el ajedrez.", "no olvides que juego los domingos",
                 "Remember, I like chess.", "Hi! Remember that I like chess.", "no te olvides de que juego los domingos",
                 "lembre que eu gosto de xadrez", "não esqueça que eu jogo xadrez", "por favor, guarda isso", "Remember that I like chess. Can you draw?"]:
        assert asks_to_remember(text), text
    for text in ["do you remember my sister", "I can't remember the word", "forget that", "Hi! What are you made of?",
                 "Can you remember my name?", "Do you still remember that", "Did you remember that", "Why can't you remember that",
                 "Remember me?", "I remember that I left it", "Você lembra que eu falei?", "Você guarda isso?", "ele guarda isso na gaveta",
                 "Remember when we played"]:
        assert not asks_to_remember(text), text


def test_dont_forget_is_not_a_forget():
    assert detect_request("Don't forget that I play on Sundays") is None
    assert detect_request("não esquece disso, tá?") is None
    assert detect_request("never forget that I like chess") is None
    assert detect_request("nunca esqueça isso") is None and detect_request("não se esqueça disso") is None
    assert detect_request("forget that") == "forget"
    assert detect_request("esquece isso") == "forget"


async def test_an_asked_remember_is_kept_whatever_the_gate_says(card, monkeypatch):
    """The trained gate drops "remember that I like chess" (0.62 drop on a real call); asked outright, it is a lasting fact."""
    import memory.turn as turn_mod
    from memory.device import DeviceHub, DeviceStore
    from memory.embed import embed
    from memory.turn import MemoryTurn, Recalled

    sent = []
    hub = DeviceHub(await DeviceStore.load({}, sent.append))
    events = []
    turn = MemoryTurn(hub, card, "u", "s1", emit=lambda **e: events.append(e), client=object())
    await turn._load()

    async def note(text, *a):
        return "They like chess"

    async def weigh(note, similar, *a):
        return turn_mod.consolidate.Weighed(action="add", fact=note)

    monkeypatch.setattr(turn_mod.consolidate, "write_note", note)
    monkeypatch.setattr(turn_mod.consolidate, "weigh", weigh)
    monkeypatch.setattr(turn_mod, "keep_scores", lambda *a: {"drop": 0.62, "short": 0.13, "long": 0.25})
    import torch

    t = torch.tensor(embed(["Remember that I like chess."])[0])
    await turn.after_turn("t1", "Remember that I like chess.", "hi", None, Recalled(vectors=(t, t)))
    assert sent and sent[-1]["op"] == "add" and sent[-1]["text"] == "They like chess"
    assert events[-1]["keep"] == "asked" and events[-1]["action"] == "add"
    sent.clear()
    await turn.after_turn("t2", "I had toast.", "hi", None, Recalled(vectors=(t, t)))
    assert sent == [] and events[-1]["action"] == "drop"  # unasked, the gate still decides


async def test_end_waits_for_the_last_turns_fact(card, monkeypatch):
    """A "remember that" said just before bye: its fact goes out before end() returns (and so before bye_ack)."""
    import asyncio

    import torch

    import memory.turn as turn_mod
    from memory.device import DeviceHub, DeviceStore
    from memory.embed import embed
    from memory.turn import MemoryTurn, Recalled

    sent = []
    hub = DeviceHub(await DeviceStore.load({}, sent.append))
    turn = MemoryTurn(hub, card, "u", "s1", emit=lambda **e: None, client=object())
    await turn._load()

    async def note(text, *a):
        await asyncio.sleep(0.3)
        return "They like chess"

    async def weigh(note, similar, *a):
        return turn_mod.consolidate.Weighed(action="add", fact=note)

    async def nothing(*a):
        return ""

    monkeypatch.setattr(turn_mod.consolidate, "write_note", note)
    monkeypatch.setattr(turn_mod.consolidate, "weigh", weigh)
    monkeypatch.setattr(turn_mod.consolidate, "summarise", nothing)
    t = torch.tensor(embed(["Remember that I like chess."])[0])
    turn.schedule_after_turn("t1", "Remember that I like chess.", "hi", None, Recalled(vectors=(t, t)))  # end() right away: counted from scheduling
    await turn.end([])
    assert [m["op"] for m in sent] == ["add"] and not turn.writing


async def test_end_says_why_it_skipped_the_summary(card):
    """A call with no summary leaves its reason in the events, in counts and states only (never the words)."""
    from memory.device import DeviceHub, DeviceStore
    from memory.turn import MemoryTurn

    events = []
    hub = DeviceHub(await DeviceStore.load({}, lambda m: None))
    turn = MemoryTurn(hub, card, "u", "s1", emit=lambda **e: events.append(e), client=object())
    await turn.end([{"role": "user", "content": "hi there"}, {"role": "assistant", "tool_calls": []}])
    assert events == [{"kind": "end_skipped", "reason": "1 lines of 2 messages"}]
    events.clear()
    await MemoryTurn(hub, card, "u", "s2", emit=lambda **e: events.append(e)).end([])
    assert events == [{"kind": "end_skipped", "reason": "no client"}]
