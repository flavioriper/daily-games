"""Plays pre-rendered clips as raw 24 kHz audio frames. Loaded into memory at call start: a bucket read has no place on the voice path."""
import audioop
import json
import random
import wave
from pathlib import Path

from pipecat.frames.frames import Frame, OutputAudioRawFrame, OutputTransportMessageUrgentFrame, TTSAudioRawFrame, TTSStoppedFrame
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

RATE = 24000
CHUNK = 960  # 20 ms of 16-bit mono


class ClipOut(FrameProcessor):
    """Sits right before the transport so clips never queue behind the LLM or TTS."""

    def __init__(self, on_stage=lambda _: None, **kwargs):
        super().__init__(**kwargs)
        self.on_stage = on_stage
        self._speaking = False

    async def cue(self, name: str) -> None:
        """Tells the page to play a room sound or backchannel; it mixes them itself."""
        await self.push_frame(OutputTransportMessageUrgentFrame({"type": "sfx", "name": name}))

    async def watch(self, frame: Frame) -> None:
        if isinstance(frame, TTSAudioRawFrame) and not self._speaking:
            self._speaking = True
            self.on_stage({"stage": "speaking"})
        elif isinstance(frame, TTSStoppedFrame) and self._speaking:
            self._speaking = False
            self.on_stage({"stage": "done"})

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        await self.watch(frame)
        await self.push_frame(frame, direction)


FALLBACK = {"thinking": "bridges", "stalls": "bridges", "reaching": "bridges", "searching": "bridges"}  # cards from before these kinds existed


class ClipPlayer:
    def __init__(self, out, root, card):
        self.out = out
        self._rng = random.Random()
        self._clips: dict[str, list[bytes]] = {}
        manifest = Path(root) / card.slug / "manifest.json"
        if manifest.exists():
            for kind, names in json.loads(manifest.read_text()).items():
                self._clips[kind] = []
                for name in names:
                    with wave.open(str(manifest.parent / name)) as w:
                        self._clips[kind].append(w.readframes(w.getnframes()))

    async def play(self, kind: str, gain: float = 1.0) -> None:
        clips = self._clips.get(kind) or self._clips.get(FALLBACK.get(kind, ""))
        if not clips:
            return
        audio = self._rng.choice(clips)
        if gain != 1.0:
            audio = audioop.mul(audio, 2, gain)
        for i in range(0, len(audio), CHUNK):
            await self.out.push_frame(OutputAudioRawFrame(audio[i : i + CHUNK], RATE, 1))
