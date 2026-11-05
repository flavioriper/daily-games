"""A persona whose voice is Soniox hears and speaks with Soniox (Sam, 4 Nov): no Deepgram and no ElevenLabs, the policy and its clips unchanged."""
import math
import wave
from array import array

from studio.clips import render_clips
from voice.bot import make_services, strategies
from voice.ledger_observer import LedgerObserver


def soniox(card):
    return card.model_copy(update={"voice": card.voice.model_copy(update={"provider": "soniox", "model": "tts-rt-v2", "voice_id": "Adrian"})})


class Rows:
    def __init__(self):
        self.rows = []

    def record(self, **row):
        self.rows.append(row)


def test_a_soniox_persona_builds_soniox_ears_and_voice_without_network(monkeypatch, card):
    for k in ("DEEPGRAM_API_KEY", "ELEVENLABS_API_KEY"):
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv("SONIOX_API_KEY", "x")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "x")
    s = make_services(soniox(card))
    assert type(s.stt).__name__ == "SonioxSTTService" and not s.stt._vad_force_turn_endpoint  # Soniox's own endpoint ends the turn
    assert type(s.tts).__name__ == "SonioxTTSService" and s.tts._settings.voice == "Adrian"


def test_a_soniox_turn_ends_on_its_endpoint_with_no_speculation(card):
    # Soniox sends no eager end of turn, so a speculating strategy would wait for one that never comes
    assert [type(x).__name__ for x in strategies(soniox(card)).stop] == ["ExternalUserTurnStopStrategy"]


def test_soniox_clips_are_spoken_by_soniox_in_the_call_voice(tmp_path, card):
    said = []

    def speak(text, voice, model, key, language):
        said.append((text, voice, model, key))
        return array("h", (int(8000 * math.sin(i / 8)) for i in range(12000))).tobytes()  # half a second of 24 kHz tone

    rows = Rows()
    out = render_clips(soniox(card), tmp_path, "k", rows, speak=speak)
    assert said and {(v, m, k) for _, v, m, k in said} == {("Adrian", "tts-rt-v2", "k")}
    assert not any("[short pause]" in t for t, *_ in said)  # an ElevenLabs tag Soniox would read aloud
    with wave.open(str(out["greeting"][0])) as w:
        assert (w.getframerate(), w.getnchannels(), w.getsampwidth()) == (24000, 1, 2) and w.getnframes() > 0
    assert [(r["kind"], r["provider"]) for r in rows.rows] == [("clip", "soniox")]


def test_a_soniox_call_is_billed_to_soniox(card):
    rows = Rows()
    o = LedgerObserver(rows, user_id="u", persona="p", session_id="s", brain="anthropic:claude-haiku-5-5", stt_model="stt-rt-v5", tts_model="tts-rt-v2", speech="soniox")
    o.open_stt(0)
    o.flush_stt(60)
    assert [(r["kind"], r["provider"], r["model"]) for r in rows.rows] == [("stt", "soniox", "stt-rt-v5")]
