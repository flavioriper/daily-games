"""Long user turns get a backchannel, sent as a message, never as call audio, so it overlaps speech and cannot trip bot-speaking state. strip_tags still removes old room tags from text. (The room sounds were cut in the fork.)"""
import random
import re
import time
from typing import Awaitable, Callable

from pipecat.frames.frames import Frame, InterimTranscriptionFrame, TranscriptionFrame
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

ROOM_SOUNDS = ("typing", "mouse", "papers", "chair", "mug", "door")
TAG = re.compile(r"\[(" + "|".join(ROOM_SOUNDS) + r")\]\s*")
Cue = Callable[[str], Awaitable[None]]


def strip_tags(text: str) -> str:
    return TAG.sub("", text).strip()


class Listener(FrameProcessor):
    """Drops an "mm-hm" into a long turn, and tells the steer what was heard. Interim transcripts are cumulative within a turn. every_s is both the talk needed before the first one and the cooldown after it, jittered by a fifth so it never keeps time."""

    def __init__(self, cue: Cue, on_heard: Callable[[str], None] = lambda _: None, every_words: int = 14, every_s: float = 6.0, chance: float = 0.5, rng=None, **kwargs):
        super().__init__(**kwargs)
        self.cue, self.on_heard, self.every_words, self.every_s, self.chance = cue, on_heard, every_words, every_s, chance
        self.rng = rng or random.Random()
        self._mark, self._at = 0, None
        self._rearm()

    def _rearm(self) -> None:
        self._period = self.every_s * self.rng.uniform(0.8, 1.2)

    async def hear(self, frame: Frame) -> None:
        if isinstance(frame, TranscriptionFrame):
            self._mark, self._at = 0, None
            self.on_heard(frame.text)
        elif isinstance(frame, InterimTranscriptionFrame):
            words, now = len(frame.text.split()), time.monotonic()
            if self._at is None:
                self._at = now
            if words - self._mark >= self.every_words and now - self._at >= self._period:
                self._mark, self._at = words, now
                self._rearm()
                if self.rng.random() < self.chance:
                    await self.cue("backchannel")

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        await self.hear(frame)
        await self.push_frame(frame, direction)
