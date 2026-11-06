"""The typed path: the same PolicySteer and prompt as a call, with silent clips and a plain SDK call instead of the voice pipeline."""
import asyncio
import json
import os
import uuid

import anthropic
from pipecat.processors.aggregators.llm_context import LLMContext

from agent.tools import TIMEOUT, result_text
from studio.brains import CHAT_REASONING, GATEWAY_URL, GLM_THINKING, GLM_URL, openai_units
from voice.foley import strip_tags
from voice.prompt import system_prompt
from voice.steer import PolicySteer

MAX_TOKENS = 400
HISTORY = 20
TEXT_BUDGET_S = 5.0
IDLE_S = 600.0
ROUNDS = 6
OPENAI_COMPATIBLE = {
    "openai": ("OPENAI_API_KEY", None),
    "google": ("GEMINI_API_KEY", "https://generativelanguage.googleapis.com/v1beta/openai/"),
    "groq": ("GROQ_API_KEY", "https://api.groq.com/openai/v1"),
    "cerebras": ("CEREBRAS_API_KEY", "https://api.cerebras.ai/v1"),
    "gateway": ("AI_GATEWAY_API_KEY", GATEWAY_URL),
    "glm": ("GLM_API_KEY", GLM_URL),
}


class Silent:
    async def play(self, kind: str, gain: float = 1.0) -> None:
        pass


async def tool_reply(client, model: str, messages: list[dict], extra: dict, tools, turn: int) -> tuple[str, dict]:
    """The typed path's agent loop; Pipecat runs the same tools on a call. Tool messages stay in this loop, so the session keeps only what was said."""
    messages, totals = list(messages), {}
    for _ in range(ROUNDS):
        r = await client.chat.completions.create(model=model, messages=messages, tools=tools.openai_schema(), **extra)
        for k, v in openai_units(r.usage).items():
            totals[k] = v if isinstance(v, bool) else totals.get(k, 0) + v
        message = r.choices[0].message
        if not message.tool_calls:
            return (message.content or "").strip(), totals
        messages.append(message.model_dump(exclude_none=True))
        for call in message.tool_calls:
            result = await asyncio.wait_for(tools.run(call.function.name, json.loads(call.function.arguments or "{}"), turn), TIMEOUT.get(call.function.name, 15))
            messages.append({"role": "tool", "tool_call_id": call.id, "content": result_text(result)})
    return "Sorry, that took too many steps.", totals


async def llm_reply(card, system: str, messages: list[dict], deps, tools=None) -> tuple[str, dict]:
    provider, model = card.brain.chat.split(":", 1)
    if provider == "anthropic":
        thinking = {"claude-haiku-5-5": {"thinking": {"type": "disabled"}}, "claude-sonnet-5-5": {"thinking": {"type": "between_tools"}}}.get(model, {})
        r = await deps.anthropic.messages.create(model=model, max_tokens=MAX_TOKENS, system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}], messages=messages, **thinking)
        u = r.usage
        return "".join(b.text for b in r.content if b.type == "text").strip(), {"prompt_tokens": u.input_tokens, "completion_tokens": u.output_tokens, "cache_read_input_tokens": u.cache_read_input_tokens, "cache_creation_input_tokens": u.cache_creation_input_tokens, "gross": False}
    from openai import AsyncOpenAI

    env, base = OPENAI_COMPATIBLE[provider]
    extra = {"reasoning_effort": CHAT_REASONING} if provider == "openai" else GLM_THINKING if provider == "glm" else {}
    client = AsyncOpenAI(api_key=os.environ[env], base_url=base)
    if tools:
        return await tool_reply(client, model, [{"role": "system", "content": system}, *messages], extra, tools, sum(m["role"] == "user" for m in messages))
    r = await client.chat.completions.create(model=model, messages=[{"role": "system", "content": system}, *messages], **extra)
    return r.choices[0].message.content.strip(), openai_units(r.usage)


class TextSessions:
    def __init__(self, deps, idle_s: float = IDLE_S):
        self.deps, self.idle_s = deps, idle_s
        self._by: dict[tuple[str, str], tuple] = {}
        self._idle: dict[tuple[str, str], asyncio.Task] = {}
        self._ids: dict[tuple[str, str], str] = {}

    def session_id(self, user_id: str, slug: str) -> str:
        return self._ids.setdefault((user_id, slug), f"text-{user_id}-{slug}-{uuid.uuid4().hex[:8]}")

    def reset(self, user_id: str, slug: str) -> str:
        """A page load is a new conversation: the old one ends as if it had gone idle, so it still becomes an episode, and costs start again from zero."""
        key = (user_id, slug)
        if key in self._idle:
            self._idle.pop(key).cancel()
        if key in self._by:
            steer, context, *_ = self._by.pop(key)
            asyncio.ensure_future(self.deps.after_call(steer.memory, context.messages))
        self._ids.pop(key, None)
        return self.session_id(user_id, slug)

    def _session(self, card, user_id: str):
        key = (user_id, card.slug)
        if key in self._by:
            s = self._by[key]
            s[0].default_decision = type(s[0].default_decision)(**card.calibration.default_decision)
            return s
        deps, events = self.deps, []
        session = self.session_id(user_id, card.slug)
        log = lambda **e: deps.events.add({"session_id": session, "slug": card.slug, **e})
        ids = {"user_id": user_id, "persona": card.slug, "session_id": session}
        memory = deps.memory_turn(card, user_id, f"{session}-{uuid.uuid4().hex[:6]}", log)

        steer = PolicySteer(jev=deps.jev, learner=deps.learner, slug=card.slug, user_id=user_id, default_decision=card.calibration.default_decision, clips=Silent(), on_event=events.append, on_fact=lambda fact: deps.add_fact(card.slug, fact), on_stage=lambda e: log(kind="stage", **e),
                            on_jev_call=lambda: deps.ledger.record(kind="jev", provider="typesafe", model="jev-1.13.0", units={"calls": 1}, source="steer", **ids), jev_budget_s=TEXT_BUDGET_S, memory=memory)
        toolbox = deps.toolbox(card, lambda e: log(kind="stage", **e))
        if toolbox:
            toolbox.memory = memory
        self._by[key] = (steer, LLMContext(), events, ids, log, toolbox)
        return self._by[key]

    def _arm(self, user_id: str, slug: str) -> None:
        """A typed session has no hang-up; going quiet for IDLE_S ends it, which writes the episode."""
        key = (user_id, slug)
        if key in self._idle:
            self._idle[key].cancel()
        self._idle[key] = asyncio.ensure_future(self._expire(key))

    async def _expire(self, key: tuple[str, str]) -> None:
        await asyncio.sleep(self.idle_s)
        steer, context, *_ = self._by.pop(key)
        self._idle.pop(key, None)
        await self.deps.after_call(steer.memory, context.messages)

    async def turn(self, card, user_id: str, text: str, screen: str | None = None) -> dict:
        steer, context, events, ids, log, toolbox = self._session(card, user_id)
        self._arm(user_id, card.slug)
        if steer.memory:
            await steer.memory.ready  # a typed first turn can afford to wait; a call has been connected for seconds by then
        context.add_message({"role": "user", "content": text})
        await steer.on_context(context)
        if screen:  # after Jev has read the turn, so the note never shapes the policy's features
            message = context.messages[-1]
            note = f"\n[screen: {screen}]"
            if isinstance(message.get("content"), str):
                message["content"] += note
            elif isinstance(message.get("content"), list):
                message["content"].append({"type": "text", "text": note})
        event = self.deps.enrich_turn(events[-1], user_id, card.slug)
        log(**event)
        if toolbox:
            toolbox.new_turn(screen)
        extra = {"tools": toolbox} if toolbox else {}
        reply, units = await self.deps.reply(card, system_prompt(card), context.messages[-HISTORY:], self.deps, **extra)
        reply = strip_tags(reply)
        steer.on_llm_text()
        context.add_message({"role": "assistant", "content": reply})
        log(kind="said", text=reply, interrupted=False)
        log(kind="stage", stage="done")
        provider, model = card.brain.chat.split(":", 1)
        self.deps.ledger.record(kind="llm", provider=provider, model=model, units=units, source="text turn", **ids)
        return {
            "turn_id": event["turn_id"], "features": event["features"], "jev_ms": event["jev_ms"], "jev_path": event["jev_path"], "learned": event["learned"],
            "persona": {"decision": event["decision"], "steer": event["steer"], "explanation": event["explanation"], "override": event["override"], "reply": reply,
                        "delta_norm": round(self.deps.learner.user_delta(user_id, card.slug).norm(), 4)},
            "cost": self.deps.ledger.session_total(ids["session_id"]),
        }
