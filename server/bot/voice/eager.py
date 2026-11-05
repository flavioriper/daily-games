"""One speculation per turn. Flux re-issues EagerEndOfTurn with a revised transcript and no TurnResumed between (a real call: "What you do?" then "What you do"); Pipecat 1.15.0's strategy then starts a second speculation on top of the first, its gate releases the first reply at the commit, the second runs unheld, and both are spoken."""
from loguru import logger
from pipecat.frames.frames import EagerTranscriptionFrame
from pipecat.turns.user_stop.eager_user_turn_stop_strategy import EagerUserTurnStopStrategy


class OneSpeculationStopStrategy(EagerUserTurnStopStrategy):
    """A revised eager transcript that still matches keeps the speculation in flight; one that moved withdraws it before speculating again."""

    async def _speculate(self, frame: EagerTranscriptionFrame):  # private in pipecat 1.15.0; re-check on upgrade
        pending = self._speculation
        if pending:
            if self._match_policy.matches(pending.text, self._text + frame.text):
                logger.debug(f"{self}: revised eager transcript still matches [{pending.text}], keeping the speculation")
                return
            logger.debug(f"{self}: eager transcript moved from [{pending.text}], withdrawing that speculation first")
            await self._take_speculation()  # cleared before the withdrawal so its echo cannot wipe the new one
            await self.cancel_user_turn_speculation()
        await super()._speculate(frame)
