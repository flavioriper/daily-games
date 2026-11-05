"""Words per second of the current user turn, for the panel only: the network never saw a non-normal pace (spec 7.3)."""
import time

from pipecat.frames.frames import Frame, InterimTranscriptionFrame, TranscriptionFrame
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor


class PaceProcessor(FrameProcessor):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._t0, self._wps = None, 0.0

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        if isinstance(frame, (InterimTranscriptionFrame, TranscriptionFrame)):
            now = time.monotonic()
            self._t0 = self._t0 or now
            if now > self._t0:
                self._wps = len(frame.text.split()) / (now - self._t0)
            if isinstance(frame, TranscriptionFrame):
                self._t0 = None
        await self.push_frame(frame, direction)

    def words_per_second(self) -> float:
        return round(self._wps, 2)

    def pace(self) -> str:
        return "slow" if self._wps and self._wps < 2.0 else "fast" if self._wps > 3.3 else "normal"
