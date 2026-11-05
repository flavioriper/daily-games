"""Plays pre-rendered clips as raw 24 kHz audio frames. Loaded into memory at call start: a bucket read has no place on the voice path."""
import audioop
import json
import random
import wave
from pathlib import Path

import re

from pipecat.frames.frames import AggregatedTextFrame, Frame, OutputAudioRawFrame, OutputTransportMessageUrgentFrame, TTSAudioRawFrame, TTSStoppedFrame, TTSTextFrame
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

RATE = 24000
CHUNK = 960  # 20 ms of 16-bit mono


class ClipOut(FrameProcessor):
    """Sits right before the transport so clips never queue behind the LLM or TTS."""

    def __init__(self, on_stage=lambda _: None, on_said=lambda _: None, **kwargs):
        super().__init__(**kwargs)
        self.on_stage, self.on_said = on_stage, on_said
        self._speaking = False

    async def cue(self, name: str) -> None:
        """Tells the page to play a room sound or backchannel; it mixes them itself."""
        await self.push_frame(OutputTransportMessageUrgentFrame({"type": "sfx", "name": name}))

    async def watch(self, frame: Frame) -> None:
        if isinstance(frame, AggregatedTextFrame) and not isinstance(frame, TTSTextFrame) and frame.will_be_spoken:
            self.on_said(spoken(frame.text))  # the TTS pushes a sentence's text right before its audio starts
        elif isinstance(frame, TTSAudioRawFrame) and not self._speaking:
            self._speaking = True
            self.on_stage({"stage": "speaking"})
        elif isinstance(frame, TTSStoppedFrame) and self._speaking:
            self._speaking = False
            self.on_stage({"stage": "done"})

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        await self.watch(frame)
        await self.push_frame(frame, direction)


TAGS = re.compile(r"\[[^\]]*\]|<[^>]*>")  # delivery tags and markup: heard, never read


def spoken(text: str) -> str:
    """A sentence as the phone shows it."""
    return " ".join(TAGS.sub("", text or "").split())


FALLBACK = {"thinking": "bridges", "stalls": "bridges", "reaching": "bridges", "searching": "bridges"}  # cards from before these kinds existed


class ClipPlayer:
    def __init__(self, out, root, card, on_said=None):
        """`on_said` gets a clip's line just before it plays, when the manifest lines up with the card's lines (render_clips writes them in order)."""
        self.out, self.on_said = out, on_said
        self._rng = random.Random()
        self._clips: dict[str, list[bytes]] = {}
        self._texts: dict[str, list[str]] = {}
        manifest = Path(root) / card.slug / "manifest.json"
        if manifest.exists():
            for kind, names in json.loads(manifest.read_text()).items():
                self._clips[kind] = []
                for name in names:
                    with wave.open(str(manifest.parent / name)) as w:
                        self._clips[kind].append(w.readframes(w.getnframes()))
                lines = getattr(card.lines, kind, None)
                lines = [lines] if isinstance(lines, str) else lines
                if isinstance(lines, list) and len(lines) == len(names):
                    self._texts[kind] = lines

    async def play(self, kind: str, gain: float = 1.0) -> float:
        """Pushes one clip of `kind` and returns its length in seconds (0 when there is none)."""
        if not self._clips.get(kind):
            kind = FALLBACK.get(kind, "")
        clips = self._clips.get(kind)
        if not clips:
            return 0.0
        i = self._rng.randrange(len(clips))
        audio = clips[i]
        if self.on_said and kind in self._texts:
            self.on_said(self._texts[kind][i])
        if gain != 1.0:
            audio = audioop.mul(audio, 2, gain)
        for i in range(0, len(audio), CHUNK):
            await self.out.push_frame(OutputAudioRawFrame(audio[i : i + CHUNK], RATE, 1))
        return len(audio) / 2 / RATE
