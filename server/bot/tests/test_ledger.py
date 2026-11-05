import pytest

from studio.ledger import Ledger
from studio.prices import Prices

IDS = {"user_id": "u", "persona": "p", "session_id": "s", "source": "test"}


def ledger(tmp_path):
    return Ledger(tmp_path / "l.sqlite", Prices.load("prices.yaml"))


def test_anthropic_net_and_openai_gross_cache_accounting(tmp_path):
    L = ledger(tmp_path)
    a = L.record(kind="llm", provider="anthropic", model="claude-haiku-5-5", units={"prompt_tokens": 1000, "cache_read_input_tokens": 3000, "completion_tokens": 100, "gross": False}, **IDS)
    assert a.cost_usd == pytest.approx((1000 * 0.10 + 3000 * 0.01 + 100 * 0.50) / 1e6)
    o = L.record(kind="llm", provider="openai", model="gpt-6-luna", units={"prompt_tokens": 4000, "cache_read_input_tokens": 3000, "completion_tokens": 100, "gross": True}, **IDS)
    assert o.cost_usd == pytest.approx(((4000 - 3000) * 0.10 + 3000 * 0.01 + 100 * 0.50) / 1e6)


def test_cache_write_is_billed_at_its_own_rate(tmp_path):
    a = ledger(tmp_path).record(kind="llm", provider="anthropic", model="claude-haiku-5-5", units={"prompt_tokens": 0, "cache_creation_input_tokens": 1000000, "completion_tokens": 0, "gross": False}, **IDS)
    assert a.cost_usd == pytest.approx(0.125)


def test_unpriced_model_is_none_not_zero(tmp_path):
    r = ledger(tmp_path).record(kind="jev", provider="typesafe", model="jev-unknown", units={"calls": 1}, **IDS)
    assert r.cost_usd is None


def test_jev_calls_are_priced(tmp_path):
    r = ledger(tmp_path).record(kind="jev", provider="typesafe", model="jev-1.13.0", units={"calls": 2}, **IDS)
    assert r.cost_usd == pytest.approx(0.00006)


def test_stt_and_tts_rates(tmp_path):
    L = ledger(tmp_path)
    assert L.record(kind="stt", provider="deepgram", model="flux-general-en", units={"seconds": 60}, **IDS).cost_usd == pytest.approx(0.0078)
    assert L.record(kind="tts", provider="elevenlabs", model="eleven_v4_turbo", units={"characters": 1000}, **IDS).cost_usd == pytest.approx(0.04)
    assert L.session_total("s")["total"] == pytest.approx(0.0478)


def test_session_total_flags_unpriced_rows(tmp_path):
    L = ledger(tmp_path)
    L.record(kind="jev", provider="typesafe", model="jev-unknown", units={"calls": 3}, **IDS)
    assert L.session_total("s")["unpriced"] == ["jev"]


def test_projection_uses_measured_mix(tmp_path):
    L = ledger(tmp_path)
    L.record(kind="stt", provider="deepgram", model="flux-general-en", units={"seconds": 600}, **IDS)
    L.record(kind="tts", provider="elevenlabs", model="eleven_v4_turbo", units={"characters": 4800}, **IDS)
    per_min = (0.078 + 0.192) / 10
    assert L.projection("u", [10, 30])[1]["monthly_usd"] == pytest.approx(per_min * 30 * 30, rel=0.02)


def test_what_if_reprices_the_same_units(tmp_path):
    L = ledger(tmp_path)
    L.record(kind="llm", provider="anthropic", model="claude-haiku-5-5", units={"prompt_tokens": 1000000, "completion_tokens": 0, "gross": False}, **IDS)
    L.record(kind="tts", provider="elevenlabs", model="eleven_v4_turbo", units={"characters": 1000}, **IDS)
    rows = {r["key"]: r for r in L.what_if("s", ["anthropic:claude-sonnet-5-5"], ["inworld:tts-2"])}
    assert rows["anthropic:claude-sonnet-5-5"]["cost_usd"] == pytest.approx(2.0 + 0.04)
    assert rows["inworld:tts-2"]["cost_usd"] == pytest.approx(0.10 + 0.025)
