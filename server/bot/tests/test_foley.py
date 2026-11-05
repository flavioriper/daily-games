import random

from pipecat.frames.frames import InterimTranscriptionFrame, TranscriptionFrame

from studio.card import Lines
from voice.foley import Listener, strip_tags
from voice.prompt import system_prompt
from voice.serializer import PcmSerializer


def test_typed_replies_lose_their_tags():
    assert strip_tags("[papers] Here it is.") == "Here it is."


async def test_room_cue_is_sent_as_a_message():
    from pipecat.frames.frames import OutputTransportMessageUrgentFrame

    assert await PcmSerializer().serialize(OutputTransportMessageUrgentFrame({"type": "sfx", "name": "mug"})) == '{"type": "sfx", "name": "mug"}'


async def test_backchannel_needs_words_and_time_then_rearms(monkeypatch):
    cues, now = [], [0.0]

    async def cue(name):
        cues.append(name)

    monkeypatch.setattr("voice.foley.time.monotonic", lambda: now[0])
    heard = []
    li = Listener(cue, heard.append, every_words=3, every_s=2, chance=1.0, rng=random.Random(1))
    await li.hear(InterimTranscriptionFrame("one two three four", "u", "t"))
    assert cues == []  # enough words, not enough time
    now[0] = 3
    await li.hear(InterimTranscriptionFrame("one two three four five", "u", "t"))
    assert cues == ["backchannel"]
    now[0] = 6
    await li.hear(InterimTranscriptionFrame("one two three four five six", "u", "t"))
    assert cues == ["backchannel"]  # only one new word since
    await li.hear(TranscriptionFrame("done", "u", "t"))
    assert heard == ["done"]


def test_prompt_never_lets_the_persona_claim_to_be_human(card):
    assert "do not claim to be human" in system_prompt(card)
    assert "already told them" in system_prompt(card.model_copy(update={"disclose": True}))


def test_disclosure_is_rendered_only_when_on(tmp_path, card):
    from studio.clips import render_clips
    from tests.test_clips import Eleven

    import subprocess
    p = tmp_path / "s.mp3"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=300:duration=0.4", str(p)], check=True)
    e = Eleven(p.read_bytes())
    one = card.model_copy(update={"lines": Lines(greeting="Hi there.")})
    assert "disclosure" not in render_clips(one, tmp_path, "k", None, client=e.client)
    assert "disclosure" in render_clips(one.model_copy(update={"disclose": True}), tmp_path, "k", None, client=e.client)


def test_backchannel_cooldown_is_jittered_and_rearmed_each_time():
    li = Listener(lambda _: None, every_s=5.0, rng=random.Random(3))
    first = li._period
    assert 4.0 <= first <= 6.0
    li._rearm()
    assert 4.0 <= li._period <= 6.0 and li._period != first
