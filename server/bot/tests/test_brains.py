import re

import pytest

from studio.brains import KEYS, make_llm
from studio.prices import Prices

ENV = {"gateway": "AI_GATEWAY_API_KEY", "anthropic": "ANTHROPIC_API_KEY", "openai": "OPENAI_API_KEY", "google": "GEMINI_API_KEY", "groq": "GROQ_API_KEY", "cerebras": "CEREBRAS_API_KEY", "glm": "GLM_API_KEY"}


def test_every_brain_key_builds_without_network(monkeypatch):
    for k in KEYS:
        monkeypatch.setenv(ENV[k.split(":")[0]], "x")
    for k in KEYS:
        assert make_llm(k) is not None


def test_unknown_brain_raises():
    with pytest.raises(KeyError):
        make_llm("nope:model")


def test_prices_have_source_and_date_and_jev_is_priced():
    p = Prices.load("prices.yaml")
    assert all(r.source.startswith("https://") and re.fullmatch(r"\d{4}-\d{2}-\d{2}", r.checked) for r in p.rows)
    assert p.price("typesafe", "jev-1.13.0", "call") == 0.00003


def test_every_brain_has_input_and_output_prices():
    p = Prices.load("prices.yaml")
    for k in KEYS:
        provider, model = k.split(":", 1)
        assert p.price(provider, model, "input_mtok") is not None and p.price(provider, model, "output_mtok") is not None, k


@pytest.mark.parametrize("key", ["anthropic:claude-haiku-5-5", "anthropic:claude-sonnet-5-5"])
def test_thinking_setting_is_the_object_the_service_serialises(key, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "x")
    assert make_llm(key)._settings.thinking.model_dump()["type"] in ("disabled", "between_tools")


def test_glm_is_lias_model_on_zai_and_thinks_low(monkeypatch):
    # GLM 5.3 refuses "disabled" thinking (Fraction measured it, 30 Oct), so a spoken turn asks for the least it allows
    monkeypatch.setenv("GLM_API_KEY", "x")
    s = make_llm("glm:glm-5.3-flash")
    assert str(s._client.base_url).startswith("https://api.z.ai/api/paas/v4")
    assert s._settings.extra == {"extra_body": {"thinking": {"type": "enabled"}}, "reasoning_effort": "low"}
