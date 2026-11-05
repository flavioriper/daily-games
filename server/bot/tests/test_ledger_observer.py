from types import SimpleNamespace

from pipecat.frames.frames import MetricsFrame
from pipecat.metrics.metrics import LLMTokenUsage, LLMUsageMetricsData, TTSUsageMetricsData

from studio.ledger import Ledger
from studio.prices import Prices
from voice.ledger_observer import LedgerObserver


def obs(tmp_path, brain="anthropic:claude-haiku-5-5"):
    L = Ledger(tmp_path / "l.sqlite", Prices.load("prices.yaml"))
    return L, LedgerObserver(L, user_id="u", persona="p", session_id="s", brain=brain, stt_model="flux-general-en", tts_model="eleven_v4_turbo")


def pushed(*data):
    return MetricsFrame(data=list(data))


async def test_a_frame_seen_on_every_hop_is_counted_once(tmp_path):
    L, o = obs(tmp_path)
    f = pushed(TTSUsageMetricsData(processor="t", value=1000))
    for _ in range(3):
        await o.on_push_frame(SimpleNamespace(frame=f))
    assert L.session_total("s")["by_kind"]["tts"] == 0.04


async def test_llm_usage_is_net_for_anthropic_and_gross_otherwise(tmp_path):
    u = LLMTokenUsage(prompt_tokens=4000, completion_tokens=0, total_tokens=4000, cache_read_input_tokens=3000)
    L, o = obs(tmp_path)
    await o.on_push_frame(SimpleNamespace(frame=pushed(LLMUsageMetricsData(processor="l", value=u))))
    assert abs(L.session_total("s")["total"] - (4000 * 0.1 + 3000 * 0.01) / 1e6) < 1e-12


def test_stt_is_billed_on_socket_seconds(tmp_path):
    L, o = obs(tmp_path)
    o.open_stt(now=100.0)
    o.flush_stt(now=160.0)
    o.flush_stt(now=220.0)
    assert abs(L.session_total("s")["by_kind"]["stt"] - 0.0156) < 1e-9


async def test_gross_provider_does_not_double_count_cache(tmp_path):
    u = LLMTokenUsage(prompt_tokens=4000, completion_tokens=0, total_tokens=4000, cache_read_input_tokens=3000)
    L, o = obs(tmp_path, "openai:gpt-6-luna")
    await o.on_push_frame(SimpleNamespace(frame=pushed(LLMUsageMetricsData(processor="l", value=u))))
    assert abs(L.session_total("s")["total"] - (1000 * 0.1 + 3000 * 0.01) / 1e6) < 1e-12
