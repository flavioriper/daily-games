"""Pre-rendered persona lines (spec 7.5): rendered once over HTTP, cached by hash, played as raw audio with no TTS round trip."""
import base64
import hashlib
import json
import subprocess
from pathlib import Path

import httpx

KINDS = ["acks", "bridges", "backchannels", "learned", "reflexes", "thinking", "stalls", "reaching", "searching"]
URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice}?output_format=mp3_44100_128"
STREAM_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice}/stream?output_format=mp3_44100_128"
SONIOX_URL = "wss://tts-rt.soniox.com/tts-websocket"
SONIOX_VOICE = "Adrian"  # a stock voice until the persona has its own
PCM = ("-f", "s16le", "-ar", "24000", "-ac", "1")
SHORT = 8
TRIM = "silenceremove=stop_periods=-1:stop_duration=0.15:stop_threshold=-45dB"


class SpeechError(Exception):
    pass


def clip_key(text: str, voice_id: str, model: str, stability: float) -> str:
    return hashlib.sha1(json.dumps([text, voice_id, model, stability]).encode()).hexdigest()


def render_text(text: str) -> str:
    # very short strings hallucinate at low stability; the pause is trimmed off afterwards
    return f"{text} [short pause]" if len(text) < SHORT else text


def to_wav(audio: bytes, path: Path, source=("-f", "mp3")) -> None:
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *source, "-i", "pipe:0", "-af", TRIM, "-ac", "1", "-ar", "24000", "-sample_fmt", "s16", str(path)], input=audio, check=True)


def soniox_pcm(text: str, voice: str, model: str, api_key: str, language: str = "en") -> bytes:
    """One line in Soniox's real-time voice, the one the call speaks with, as 24 kHz 16-bit mono PCM."""
    from websockets.sync.client import connect

    audio = bytearray()
    with connect(SONIOX_URL, additional_headers={"Authorization": f"Bearer {api_key}"}) as ws:
        ws.send(json.dumps({"stream_id": "clip", "model": model, "voice": voice, "language": language, "audio_format": "pcm_s16le", "sample_rate": 24000}))
        ws.send(json.dumps({"stream_id": "clip", "text": text, "text_end": False}))
        ws.send(json.dumps({"stream_id": "clip", "text": "", "text_end": True}))
        for message in ws:
            msg = json.loads(message)
            if msg.get("error_code") is not None:
                raise SpeechError(f"Soniox {msg['error_code']}: {msg.get('error_message', '')}")
            audio += base64.b64decode(msg.get("audio") or "")
            if msg.get("terminated"):
                return bytes(audio)
    raise SpeechError("Soniox closed before the line ended")


def render_clips(card, root, api_key: str, ledger=None, client: httpx.Client | None = None, speak=soniox_pcm) -> dict[str, list[Path]]:
    client = client or httpx.Client(timeout=60)
    folder = Path(root) / card.slug
    folder.mkdir(parents=True, exist_ok=True)
    v = card.voice
    lines = {"greeting": [card.lines.greeting], **{k: getattr(card.lines, k) for k in KINDS}}
    if card.disclose:
        lines["disclosure"] = [card.lines.disclosure]
    out: dict[str, list[Path]] = {}
    chars = 0
    for kind, texts in lines.items():
        out[kind] = []
        for text in texts:
            path = folder / f"{clip_key(text, v.voice_id, v.model, v.stability)}.wav"
            if not path.exists() and v.provider == "soniox":
                to_wav(speak(text, v.voice_id or SONIOX_VOICE, v.model, api_key, card.language), path, PCM)  # Soniox reads ElevenLabs' [short pause] aloud
                chars += len(text)
            elif not path.exists():
                spoken = render_text(text)
                r = client.post(URL.format(voice=v.voice_id), headers={"xi-api-key": api_key}, json={"text": spoken, "model_id": v.model, "voice_settings": {"stability": v.stability}})
                r.raise_for_status()
                to_wav(r.content, path)
                chars += len(spoken)
            out[kind].append(path)
    (folder / "manifest.json").write_text(json.dumps({k: [p.name for p in ps] for k, ps in out.items()}))
    if ledger and chars:
        ledger.record(user_id="studio", persona=card.slug, session_id=f"render-{card.slug}", kind="clip", provider=v.provider, model=v.model, units={"characters": chars}, source="render_clips")
    return out


async def open_speech(card, text: str, api_key: str, client: httpx.AsyncClient) -> httpx.Response:
    """Opens a streamed reply in the persona's voice for a typed turn; the caller reads and closes it."""
    v = card.voice
    request = client.build_request("POST", STREAM_URL.format(voice=v.voice_id), headers={"xi-api-key": api_key}, json={"text": text, "model_id": v.model, "voice_settings": {"stability": v.stability}})
    r = await client.send(request, stream=True)
    if r.is_error:
        await r.aread()
        await r.aclose()
        raise SpeechError(f"ElevenLabs {r.status_code}: {r.text[:200]}")
    return r


def has_clips(card, root) -> bool:
    return (Path(root) / card.slug / "manifest.json").exists()
