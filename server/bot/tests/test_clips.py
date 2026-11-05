import subprocess
import wave

import httpx
import pytest

from studio.card import Lines
from studio.clips import clip_key, render_clips
from voice.clip_player import ClipPlayer


@pytest.fixture(scope="module")
def mp3(tmp_path_factory):
    p = tmp_path_factory.mktemp("a") / "s.mp3"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=300:duration=0.6", "-af", "apad=pad_dur=1", str(p)], check=True)
    return p.read_bytes()


class Eleven:
    def __init__(self, audio):
        self.audio, self.calls, self.texts = audio, 0, []
        self.client = httpx.Client(transport=httpx.MockTransport(self.handle))

    def handle(self, request):
        import json

        self.calls += 1
        self.texts.append(json.loads(request.content)["text"])
        return httpx.Response(200, content=self.audio)


def duration(path):
    with wave.open(str(path)) as w:
        assert (w.getframerate(), w.getnchannels(), w.getsampwidth()) == (24000, 1, 2)
        return w.getnframes() / 24000


def short(card):
    return card.model_copy(update={"lines": Lines(greeting="Nilo. Go ahead.", acks=["Mm"])})


def test_short_line_gets_pause_tag_and_is_trimmed(tmp_path, mp3, card):
    e = Eleven(mp3)
    acks = render_clips(short(card), tmp_path, "k", None, client=e.client)["acks"]
    assert "Mm [short pause]" in e.texts
    assert duration(acks[0]) < 1.5


def test_cache_key_skips_rerender(tmp_path, mp3, card):
    e = Eleven(mp3)
    render_clips(card, tmp_path, "k", None, client=e.client)
    n = e.calls
    assert n == 19  # greeting + 12 lines + 6 default search lines
    render_clips(card, tmp_path, "k", None, client=e.client)
    assert e.calls == n


def test_changing_stability_changes_the_key():
    assert clip_key("a", "v", "m", 0.3) != clip_key("a", "v", "m", 0.4)


class Out:
    def __init__(self):
        self.frames = []

    async def push_frame(self, f):
        self.frames.append(f)


async def test_player_pushes_24k_mono_frames_and_applies_gain(tmp_path, mp3, card):
    render_clips(card, tmp_path, "k", None, client=Eleven(mp3).client)
    out, quiet = Out(), Out()
    await ClipPlayer(out, tmp_path, card).play("acks")
    assert all(f.sample_rate == 24000 and f.num_channels == 1 for f in out.frames) and len(out.frames) > 5
    assert all(len(f.audio) <= 960 for f in out.frames)
    p = ClipPlayer(quiet, tmp_path, card)
    p._rng.seed(1)
    await p.play("backchannels", gain=0.0)
    assert not any(any(f.audio) for f in quiet.frames)


async def test_player_with_no_clips_of_that_kind_is_silent(tmp_path, card):
    out = Out()
    await ClipPlayer(out, tmp_path, card).play("acks")
    assert out.frames == []


async def test_first_tts_audio_and_tts_end_are_announced():
    from pipecat.frames.frames import TTSAudioRawFrame, TTSStoppedFrame

    from voice.clip_player import ClipOut

    stages = []
    out = ClipOut(on_stage=stages.append)
    out.push_frame = lambda *a, **k: __import__("asyncio").sleep(0)
    await out.watch(TTSAudioRawFrame(b"\0\0", 24000, 1))
    await out.watch(TTSAudioRawFrame(b"\0\0", 24000, 1))
    await out.watch(TTSStoppedFrame())
    assert [s["stage"] for s in stages] == ["speaking", "done"]


async def test_speech_stream_uses_the_persona_voice_and_reports_provider_errors(card):
    import httpx

    from studio.clips import SpeechError, open_speech

    seen = []

    def ok(request):
        seen.append(request)
        return httpx.Response(200, content=b"mp3")

    async with httpx.AsyncClient(transport=httpx.MockTransport(ok)) as client:
        r = await open_speech(card, "Hello.", "k", client)
        assert await r.aread() == b"mp3"
    assert card.voice.voice_id in str(seen[0].url) and seen[0].headers["xi-api-key"] == "k"

    async with httpx.AsyncClient(transport=httpx.MockTransport(lambda _: httpx.Response(401, text="bad key"))) as client:
        with pytest.raises(SpeechError, match="401"):
            await open_speech(card, "Hello.", "k", client)
