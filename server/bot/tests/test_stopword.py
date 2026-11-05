import pytest
from pipecat.frames.frames import BotStartedSpeakingFrame, InterimTranscriptionFrame

from voice.stopword import StopWordUserTurnStartStrategy


async def fires(text):
    s = StopWordUserTurnStartStrategy()
    hit = []

    async def started(*a, **k):
        hit.append(1)

    s.report_user_turn_started = started
    await s.process_frame(BotStartedSpeakingFrame())
    await s.process_frame(InterimTranscriptionFrame(text, "u", "t"))
    return bool(hit)


@pytest.mark.parametrize("text,starts", [("Stop.", True), ("hold on", True), ("mm-hm", False), ("yeah", False), ("stop talking please", True), ("I stopped by", False), ("no no", True)])
async def test_stop_words_start_a_turn_while_bot_speaks(text, starts):
    assert await fires(text) is starts
