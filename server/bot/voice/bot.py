"""One call: browser websocket, Flux, PolicySteer, any LLM, ElevenLabs, clips (spec section 7). Flux's eager end of turn starts Jev and a held reply; its commit releases them."""
import asyncio
import os
import re
from dataclasses import dataclass
from typing import Any

from pipecat.expressive.policy import ExpressionGuidance, ExpressionPolicy
from pipecat.observers.user_bot_latency_observer import UserBotLatencyObserver
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import LLMContextAggregatorPair, LLMUserAggregatorParams
from pipecat.transports.websocket.fastapi import FastAPIWebsocketParams, FastAPIWebsocketTransport
from pipecat.turns.user_start.min_words_user_turn_start_strategy import MinWordsUserTurnStartStrategy
from pipecat.turns.user_stop.external_user_turn_stop_strategy import ExternalUserTurnStopStrategy
from pipecat.turns.user_turn_strategies import UserTurnStrategies

from agent.tools import TIMEOUT, result_text
from studio.brains import make_llm
from studio.card import Card
from studio.clips import SONIOX_VOICE
from voice.clip_player import RATE, ClipOut, ClipPlayer
from voice.eager import OneSpeculationStopStrategy
from voice.foley import Listener
from voice.ledger_observer import LedgerObserver
from voice.pace import PaceProcessor
from voice.prompt import system_prompt
from voice.serializer import IN_RATE, PcmSerializer
from voice.steer import AfterLLM, PolicySteer
from voice.stopword import StopWordUserTurnStartStrategy

EAGER_EOT = 0.5
COMMIT_EOT = 0.8  # with the default 0.7 Flux ended turns at commas; the held reply pays for the wait
SPECULATE = os.environ.get("STUDIO_SPECULATE", "1") == "1"
SONIOX_STT = "stt-rt-v5"


@dataclass
class Services:
    stt: Any
    llm: Any
    tts: Any


def soniox(card: Card) -> bool:
    """A Soniox voice hears with Soniox too (Sam, 4 Nov): one key for the call, the policy and its clips unchanged."""
    return card.voice.provider == "soniox"


def stt_model(card: Card) -> str:
    if soniox(card):
        return SONIOX_STT
    return "flux-general-en" if card.language == "en" else "flux-general-multi"


def make_services(card: Card) -> Services:
    if soniox(card):
        from pipecat.services.soniox.stt import SonioxSTTService as S
        from pipecat.services.soniox.tts import SonioxTTSService as V

        key = os.environ["SONIOX_API_KEY"]
        # Soniox's own endpoint detection ends the turn (Flux's commit); it has no eager guess, so nothing speculates
        stt = S(api_key=key, sample_rate=IN_RATE, vad_force_turn_endpoint=False, settings=S.Settings(model=SONIOX_STT, language_hints=[card.language]))
        tts = V(api_key=key, sample_rate=RATE, settings=V.Settings(model=card.voice.model, voice=card.voice.voice_id or SONIOX_VOICE))
        return Services(stt, make_llm(card.brain.chat, system_prompt(card)), tts)

    from pipecat.services.deepgram.flux.stt import DeepgramFluxSTTService as F
    from pipecat.services.elevenlabs.dialogue.tts import ElevenLabsDialogueTTSService as T

    # enable_eager_end_of_turn spends an LLM call on every prediction, withdrawn ones included; it buys the gap between Flux's guess and its commit
    stt = F(api_key=os.environ["DEEPGRAM_API_KEY"], sample_rate=IN_RATE, enable_eager_end_of_turn=SPECULATE, settings=F.Settings(model=stt_model(card), eager_eot_threshold=EAGER_EOT, eot_threshold=COMMIT_EOT))
    tts = T(api_key=os.environ["ELEVENLABS_API_KEY"], sample_rate=RATE, settings=T.Settings(model=card.voice.model, voice=card.voice.voice_id, stability=card.voice.stability))
    return Services(stt, make_llm(card.brain.chat, system_prompt(card)), tts)


async def warm_llm(llm) -> None:
    """The first turn otherwise pays for the TLS handshake, and it is usually "hi", where a slow reply is most obvious."""
    client = getattr(llm, "_client", None)
    if client is not None and hasattr(client, "models"):
        try:
            await client.models.list()
        except Exception:
            pass  # only a warm-up


def strategies(card: Card | None = None) -> UserTurnStrategies:
    # stop is explicit: left out, Pipecat fills in the local Smart Turn analyzer instead of Flux. StopWord goes first so MinWords can't drop the word.
    speculate = SPECULATE and not (card and soniox(card))
    return UserTurnStrategies(start=[StopWordUserTurnStartStrategy(), MinWordsUserTurnStartStrategy(min_words=2)], stop=[OneSpeculationStopStrategy() if speculate else ExternalUserTurnStopStrategy()])


async def run_call(websocket, card: Card, user_id: str, session_id: str, deps) -> None:
    s = (deps.services or make_services)(card)
    transport = FastAPIWebsocketTransport(websocket, FastAPIWebsocketParams(audio_in_enabled=True, audio_out_enabled=True, audio_in_sample_rate=IN_RATE, audio_out_sample_rate=RATE, serializer=PcmSerializer()))
    log = lambda **e: deps.events.add({"session_id": session_id, "slug": card.slug, **e})
    stage = lambda e: log(kind="stage", **e)
    ledger_obs = LedgerObserver(deps.ledger, user_id=user_id, persona=card.slug, session_id=session_id, brain=card.brain.chat, stt_model=stt_model(card), tts_model=card.voice.model, speech="soniox" if soniox(card) else None)
    latency = UserBotLatencyObserver()

    toolbox = deps.toolbox(card, stage)
    context = LLMContext(tools=toolbox.pipecat_schema()) if toolbox else LLMContext()
    pair = LLMContextAggregatorPair(context, user_params=LLMUserAggregatorParams(user_turn_strategies=strategies(card)))
    clip_out, pace = ClipOut(on_stage=stage), PaceProcessor()
    player = await asyncio.to_thread(ClipPlayer, clip_out, deps.voices_root, card)

    async def cue(name: str) -> None:  # every room sound and backchannel is on the record, so a stray one can be traced to its source
        stage({"stage": "sfx", "name": name})
        await clip_out.cue(name)

    def on_event(e: dict) -> None:
        log(**deps.enrich_turn(e, user_id, card.slug))

    def on_fact(fact: str) -> None:
        asyncio.ensure_future(asyncio.to_thread(deps.add_fact, card.slug, fact))  # a bucket write has no place on the audio loop

    memory = deps.memory_turn(card, user_id, session_id, log)
    steer = PolicySteer(jev=deps.jev, learner=deps.learner, slug=card.slug, user_id=user_id, default_decision=card.calibration.default_decision, clips=player, on_event=on_event, on_fact=on_fact, on_jev_call=ledger_obs.jev_call, on_stage=stage, on_cue=cue, pace=pace, memory=memory)

    if toolbox:
        toolbox.memory = memory

        async def act(params) -> None:
            turn = sum(m.get("role") == "user" for m in context.messages)  # what send_email counts to know the person has answered since the draft
            await params.result_callback(result_text(await toolbox.run(params.function_name, dict(params.arguments), turn)))

        for name in toolbox.names():
            s.llm.register_function(name, act, timeout_secs=TIMEOUT[name])

        @s.llm.event_handler("on_function_calls_started")
        async def acting(_, calls):
            await steer.tools_started([c.function_name for c in calls])

    if "on_eager_end_of_turn" in s.stt._event_handlers:
        @s.stt.event_handler("on_eager_end_of_turn")
        async def eager(_, transcript):
            steer.start_early(transcript)

    pipeline = Pipeline([transport.input(), s.stt, Listener(cue, steer.heard), pace, pair.user(), steer, s.llm, AfterLLM(steer), s.tts, clip_out, transport.output(), pair.assistant()])
    v = card.voice.expression
    policy = ExpressionPolicy(delivery=v.deliveries, sounds=v.sounds, guidance=[ExpressionGuidance.MATCH_STYLE, f"Use at most {v.max_tags_per_reply} tags per reply."])
    task = PipelineTask(pipeline, params=PipelineParams(enable_metrics=True, enable_usage_metrics=True, enable_expressive_conversation=v.max_tags_per_reply > 0, expression_policy=policy if v.max_tags_per_reply > 0 else None), observers=[ledger_obs, latency])

    @latency.event_handler("on_latency_breakdown")
    async def breakdown(_, b):
        log(kind="latency", secs=turn_secs(b), contributions=[c.model_dump(mode="json") for c in b.contributions])

    @pair.assistant().event_handler("on_assistant_turn_stopped")
    async def said(_, message):
        if message.content:
            log(kind="said", text=message.content, interrupted=message.interrupted)

    @pair.user().event_handler("on_user_turn_started")
    async def hearing(*_):
        stage({"stage": "hearing"})

    @transport.event_handler("on_client_connected")
    async def connected(_, __):
        ledger_obs.open_stt()
        asyncio.ensure_future(deps.jev.warm())
        asyncio.ensure_future(warm_llm(s.llm))
        log(kind="connected", slug=card.slug)
        await player.play("greeting")
        if card.disclose:
            await player.play("disclosure")

    @transport.event_handler("on_client_disconnected")
    async def disconnected(_, __):
        log(kind="disconnected")
        await task.cancel()

    try:
        await PipelineRunner(handle_sigint=False).run(task)
    finally:
        ledger_obs.flush_stt()
        await deps.after_call(memory, context.messages)


def turn_secs(breakdown) -> float:
    """User stopped to bot speaking. Pipecat's total_secs also counts a "pipeline" contribution that starts before the user spoke, which read as 6.6 s on a 3.3 s turn."""
    parts = [c.duration_secs for c in breakdown.contributions if c.key != "pipeline"]
    return sum(parts) if parts else breakdown.total_secs


STEER_LINES = re.compile(r"^\[(?:steer|learned|memory):.*\]\n", re.M)


def clean_transcript(messages: list[dict]) -> list[dict]:
    out = []
    for m in messages:
        c = m.get("content")
        if m.get("role") in ("user", "assistant") and isinstance(c, str):
            out.append({"role": m["role"], "text": STEER_LINES.sub("", c)})
    return out


