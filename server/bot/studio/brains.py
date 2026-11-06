"""LLM registry: `provider:model` to a Pipecat service with the settings that keep a voice turn fast (spec 7.6)."""
import os

KEYS = [
    "anthropic:claude-haiku-5-5",
    "anthropic:claude-sonnet-5-5",
    "anthropic:claude-opus-5-5",
    "openai:gpt-6-luna",
    "openai:gpt-6.1-terra",
    "openai:gpt-6-sol",
    "google:gemini-3.1-flash-lite",
    "groq:openai/gpt-oss-120b",
    "cerebras:gpt-oss-120b",
    "gateway:openai/gpt-5.4-nano",
    "gateway:openai/gpt-6-luna",
    "gateway:anthropic/claude-sonnet-5.5",
    "glm:glm-5.3-flash",  # Lia's model in Fraction (Sam, 4 Nov)
]
GATEWAY_URL = "https://ai-gateway.vercel.sh/v1"
GLM_URL = "https://api.z.ai/api/paas/v4"
# GLM 5.3 refuses "disabled" thinking (Fraction measured it, 30 Oct): a spoken turn asks for the least it allows
GLM_THINKING = {"extra_body": {"thinking": {"type": "enabled"}}, "reasoning_effort": "low"}
MAX_TOKENS = 500  # a tool call carrying an email body counts against this; the steer line keeps spoken replies short
CHAT_REASONING = "none"  # a spoken turn cannot afford reasoning before its first word


def openai_units(u) -> dict:
    """OpenAI-compatible usage counts the cache inside prompt_tokens, hence gross."""
    details = getattr(u, "prompt_tokens_details", None)
    return {"prompt_tokens": u.prompt_tokens, "completion_tokens": u.completion_tokens, "cache_read_input_tokens": getattr(details, "cached_tokens", 0) or 0, "gross": True}


def make_llm(key: str, system: str | None = None):
    if key not in KEYS:
        raise KeyError(key)
    provider, model = key.split(":", 1)
    match provider:
        case "anthropic":
            from pipecat.services.anthropic.llm import AnthropicLLMService as S

            extra = {
                "claude-haiku-5-5": {"thinking": S.ThinkingConfig(type="disabled")},
                "claude-sonnet-5-5": {"thinking": S.ThinkingConfig(type="between_tools")},
                "claude-opus-5-5": {"effort": "low"},
            }[model]
            return S(api_key=os.environ["ANTHROPIC_API_KEY"], settings=S.Settings(model=model, system_instruction=system, enable_prompt_caching=True, max_tokens=MAX_TOKENS, **extra))
        case "openai":
            from pipecat.services.openai.llm import OpenAILLMService as S

            return S(api_key=os.environ["OPENAI_API_KEY"], settings=S.Settings(model=model, system_instruction=system, max_completion_tokens=MAX_TOKENS, extra={"reasoning_effort": CHAT_REASONING}))
        case "gateway":
            from pipecat.services.openai.llm import OpenAILLMService as S

            return S(api_key=os.environ["AI_GATEWAY_API_KEY"], base_url=GATEWAY_URL, settings=S.Settings(model=model, system_instruction=system, max_completion_tokens=MAX_TOKENS))
        case "glm":
            from pipecat.services.openai.llm import OpenAILLMService as S

            return S(api_key=os.environ["GLM_API_KEY"], base_url=GLM_URL, settings=S.Settings(model=model, system_instruction=system, max_tokens=MAX_TOKENS, extra=GLM_THINKING))
        case "google":
            from pipecat.services.google.llm import GoogleLLMService as S

            return S(api_key=os.environ["GEMINI_API_KEY"], settings=S.Settings(model=model, system_instruction=system, max_tokens=MAX_TOKENS))
        case "groq":
            from pipecat.services.groq.llm import GroqLLMService as S

            return S(api_key=os.environ["GROQ_API_KEY"], settings=S.Settings(model=model, system_instruction=system, max_tokens=MAX_TOKENS, reasoning_effort="low"))
        case "cerebras":
            from pipecat.services.cerebras.llm import CerebrasLLMService as S

            return S(api_key=os.environ["CEREBRAS_API_KEY"], settings=S.Settings(model=model, system_instruction=system, max_tokens=MAX_TOKENS))
