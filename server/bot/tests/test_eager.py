"""Flux re-issues EagerEndOfTurn with a revised transcript and no TurnResumed between (a real call: "What you do?" then "What you do"). One turn must get one answer."""
from pipecat.frames.frames import EagerTranscriptionFrame, InterimTranscriptionFrame, LLMContextFrame, ProposedUserStoppedSpeakingFrame, TranscriptionFrame, UserTurnResponseCancelFrame
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import LLMContextAggregatorPair, LLMUserAggregatorParams
from pipecat.tests.utils import SleepFrame, run_test

from voice.bot import strategies


def user_aggregator():
    return LLMContextAggregatorPair(LLMContext(), user_params=LLMUserAggregatorParams(user_turn_strategies=strategies())).user()


def turn(*eager: str, final: str):
    # the pauses keep the turn start's interruption from clearing the frames behind it, as real audio timing would
    frames = [InterimTranscriptionFrame("what you", "u", "t"), SleepFrame(0.05)]
    for e in eager:
        frames += [EagerTranscriptionFrame(e, "u", "t"), SleepFrame(0.05)]
    return frames + [TranscriptionFrame(final, "u", "t", finalized=True), ProposedUserStoppedSpeakingFrame(), SleepFrame(0.1)]


async def test_a_revised_eager_transcript_that_still_matches_keeps_the_first_speculation():
    down, _ = await run_test(user_aggregator(), frames_to_send=turn("What you do?", "What you do", final="What you do"))
    inferences = [f for f in down if isinstance(f, LLMContextFrame)]
    assert len(inferences) == 1 and inferences[0].speculation
    assert not any(isinstance(f, UserTurnResponseCancelFrame) for f in down)


async def test_an_eager_transcript_that_moved_withdraws_the_first_speculation_before_the_second():
    down, _ = await run_test(user_aggregator(), frames_to_send=turn("What you", "What you do", final="What you do"))
    kinds = [type(f) for f in down if isinstance(f, (LLMContextFrame, UserTurnResponseCancelFrame))]
    assert kinds == [LLMContextFrame, UserTurnResponseCancelFrame, LLMContextFrame]
