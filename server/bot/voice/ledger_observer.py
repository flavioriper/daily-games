"""Turns Pipecat usage metrics into ledger rows. STT is billed on socket time, so it is measured from connect to disconnect, not from speech."""
import time

from pipecat.frames.frames import MetricsFrame
from pipecat.metrics.metrics import LLMUsageMetricsData, TTSUsageMetricsData
from pipecat.observers.base_observer import BaseObserver


class LedgerObserver(BaseObserver):
    def __init__(self, ledger, *, user_id, persona, session_id, brain: str, stt_model: str, tts_model: str, speech: str | None = None, **kwargs):
        super().__init__(**kwargs)
        self.ledger, self.stt_model, self.tts_model = ledger, stt_model, tts_model
        self.stt_provider, self.tts_provider = (speech, speech) if speech else ("deepgram", "elevenlabs")  # one provider for both, or Flux and ElevenLabs
        self.ids = {"user_id": user_id, "persona": persona, "session_id": session_id}
        self.provider, self.model = brain.split(":", 1)
        self._seen: set[int] = set()
        self._stt_from: float | None = None

    def jev_call(self) -> None:
        self.ledger.record(kind="jev", provider="typesafe", model="jev-1.13.0", units={"calls": 1}, source="steer", **self.ids)

    def open_stt(self, now: float | None = None) -> None:
        self._stt_from = now if now is not None else time.time()

    def flush_stt(self, now: float | None = None) -> None:
        if self._stt_from is None:
            return
        now = now if now is not None else time.time()
        self.ledger.record(kind="stt", provider=self.stt_provider, model=self.stt_model, units={"seconds": now - self._stt_from}, source="socket time", **self.ids)
        self._stt_from = now

    async def on_push_frame(self, data) -> None:
        frame = data.frame
        if not isinstance(frame, MetricsFrame) or frame.id in self._seen:
            return
        self._seen.add(frame.id)
        for d in frame.data:
            if isinstance(d, LLMUsageMetricsData):
                u = d.value
                units = {"prompt_tokens": u.prompt_tokens, "completion_tokens": u.completion_tokens, "cache_read_input_tokens": u.cache_read_input_tokens, "cache_creation_input_tokens": u.cache_creation_input_tokens, "gross": self.provider != "anthropic"}
                self.ledger.record(kind="llm", provider=self.provider, model=self.model, units=units, source="pipecat", **self.ids)
                self.flush_stt()
            elif isinstance(d, TTSUsageMetricsData):
                self.ledger.record(kind="tts", provider=self.tts_provider, model=self.tts_model, units={"characters": d.value}, source="pipecat", **self.ids)
