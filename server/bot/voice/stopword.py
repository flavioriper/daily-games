"""A one-word "stop" interrupts while the bot speaks, where MinWords would ignore it (spec 7.2)."""
import re

from pipecat.frames.frames import Frame, InterimTranscriptionFrame, TranscriptionFrame
from pipecat.turns.user_start.base_user_turn_start_strategy import BaseUserTurnStartStrategy

STOP_WORDS = ["stop", "wait", "hold on", "hang on", "quiet", "shut up", "enough", "no no"]


def normalise(text: str) -> str:
    return " ".join(re.sub(r"[^\w\s]", " ", text.lower()).split())


class StopWordUserTurnStartStrategy(BaseUserTurnStartStrategy):
    def __init__(self, words: list[str] = STOP_WORDS, **kwargs):
        super().__init__(**kwargs)
        self._words = words

    async def process_frame(self, frame: Frame):
        if isinstance(frame, (TranscriptionFrame, InterimTranscriptionFrame)):
            text = normalise(frame.text)
            if any(text == w or text.startswith(w + " ") for w in self._words):
                await self.report_user_turn_started()
