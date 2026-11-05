"""One call: the phone's websocket, Flux, PolicySteer, any LLM, ElevenLabs, clips (spec section 7). Flux's eager end of turn starts Jev and a held reply; its commit releases them. Events go to the phone as they happen (voice/phone.py); nothing about the player is kept."""
import asyncio
import os
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from loguru import logger
from pipecat.frames.frames import InterruptionFrame

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

from agent.eye import MODEL as EYE_MODEL, Eye
from agent.tools import COMMANDS, TIMEOUT, Toolbox, result_text
from bot.cards import CLIPS, clip_card
from memory.device import DeviceHub, DeviceStore
from memory.turn import MemoryTurn
from policy.learn import BaseLearner, load_base
from studio.brains import make_llm
from studio.card import Card, owner_of
from studio.clips import SONIOX_VOICE
from voice.clip_player import RATE, ClipOut, ClipPlayer
from voice.eager import OneSpeculationStopStrategy
from voice.foley import Listener
from voice.outcomes import Outcomes
from voice.ledger_observer import LedgerObserver
from voice.pace import PaceProcessor
from voice.phone import SEE_SECONDS, KeptOpen, KindLog, Phone
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


CAP_SECONDS = 15 * 60  # a call ends itself after fifteen minutes, with a line
BYE_GRACE = 0.4  # after the goodbye clip, before the pipeline stops
STATES = {"hearing": "listening", "speaking": "speaking", "done": "listening"}
ROOT = Path(__file__).resolve().parent.parent


def state_of(event: dict) -> str | None:
    """The face's state from the steer's and the clip output's stage events. A guessed (speculative) turn is not thinking yet: the person may still be talking."""
    stage = event.get("stage")
    if stage in ("jev", "policy"):
        return None if event.get("speculative") else "thinking"
    return STATES.get(stage)


@lru_cache(maxsize=1)
def base_learner() -> BaseLearner:
    """Read-only and shared: the base policy net, no player deltas."""
    return BaseLearner(load_base(ROOT / "models" / "base.pt"))


def default_ledger():
    """Cost rows keyed by uid, the one thing kept about a player (spec, "Nothing persists"). BOT_LEDGER names the file; RAM otherwise."""
    from studio.ledger import Ledger
    from studio.prices import Prices

    return Ledger(os.environ.get("BOT_LEDGER", ":memory:"), Prices.load(ROOT / "prices.yaml"))


def default_jev():
    """Jev's answers cached in RAM for this call only: a cache on disk would keep a hash of what the player said."""
    from policy.jev import default_jev as make

    return make(":memory:")


def default_memory_client():
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    import openai

    return openai.AsyncOpenAI(api_key=key)


def _dep(deps, name: str, default=None):
    return getattr(deps, name, None) or default


STYLE_BUDGET_S = 0.8  # the shared layer's style notes, read once at call start; late or down, the call starts without them


async def read_style(shared, lang: str, budget: float = STYLE_BUDGET_S) -> list[str]:
    """The shared layer's prompt notes for this language, or none (offline, down, slow). Never raises."""
    if shared is None or not getattr(shared, "online", False):
        return []
    try:
        notes, _knobs = await asyncio.wait_for(shared.style_and_knobs_for(lang), budget)
    except Exception:  # a timeout too
        return []
    return [n.strip() for n in notes if isinstance(n, str) and n.strip()]


def with_style(card: Card, notes: list[str]) -> Card:
    """The notes join the card's own "How you speak" lines, after them."""
    return card.model_copy(update={"style": [*card.style, *notes]}) if notes else card


async def run_call(websocket, card: Card, user_id: str, session_id: str, deps, store: DeviceStore | None = None) -> None:
    """One call on the phone's socket, after the hello. Ends on `bye` (or the fifteen-minute cap) with the call's memory sent and `bye_ack`, or when the phone goes away, with nothing sent."""
    phone = Phone.of(websocket, see_s=_dep(deps, "see_seconds", SEE_SECONDS))
    if store is None:
        store = await DeviceStore.load({}, phone.send)
    card = card.model_copy(update={"screen": True})  # the person sees the swarm: the phone wording of the prompt
    shared = _dep(deps, "shared")  # the shared layer (shared/store.py), one per process; None or offline leaves the call as it was
    styling = asyncio.ensure_future(read_style(shared, card.language))  # beside the clip load below, which takes longer
    outcomes = Outcomes(shared, card.language)
    started = asyncio.get_running_loop().time()
    transport = FastAPIWebsocketTransport(KeptOpen(websocket), FastAPIWebsocketParams(audio_in_enabled=True, audio_out_enabled=True, audio_in_sample_rate=IN_RATE, audio_out_sample_rate=RATE, serializer=PcmSerializer(on_text=phone.on_text)))
    events = _dep(deps, "events")
    log = (lambda **e: events.add({"session_id": session_id, **e})) if events is not None else (lambda **e: None)  # KindLog keeps the kind only

    def stage(e: dict) -> None:
        log(kind="stage", **e)
        at = e.get("stage")
        if at == "speaking":
            outcomes.speaking()
        elif at == "done":
            outcomes.done()
        elif at == "hearing":
            outcomes.heard()
        if name := state_of(e):
            phone.state(name)

    ledger = _dep(deps, "ledger") or default_ledger()
    ids = {"user_id": user_id, "persona": card.slug, "session_id": session_id}
    ledger_obs = LedgerObserver(ledger, user_id=user_id, persona=card.slug, session_id=session_id, brain=card.brain.chat, stt_model=stt_model(card), tts_model=card.voice.model, speech="soniox" if soniox(card) else None)
    latency = UserBotLatencyObserver()
    jev = (_dep(deps, "jev", default_jev))() if card.language == "en" else None  # Jev reads English; elsewhere the steer takes the card's default decision

    def eye_usage(u: dict) -> None:
        ledger.record(kind="llm", provider="openai", model=EYE_MODEL, units={"prompt_tokens": u.get("prompt_tokens") or 0, "completion_tokens": u.get("completion_tokens") or 0, "gross": True}, source="eye", **ids)

    toolbox = Toolbox(None, stage, owner=owner_of(card), phone=True, eye=_dep(deps, "eye") or Eye(), look=phone.look, on_usage=eye_usage)
    context = LLMContext(tools=toolbox.pipecat_schema())
    pair = LLMContextAggregatorPair(context, user_params=LLMUserAggregatorParams(user_turn_strategies=strategies(card)))
    clip_out, pace = ClipOut(on_stage=stage, on_said=phone.said), PaceProcessor()
    player = await asyncio.to_thread(ClipPlayer, clip_out, _dep(deps, "clips_root", CLIPS), clip_card(card), phone.said)  # clips live under the language; everything else keys on the real card
    card = with_style(card, await styling)
    s = _dep(deps, "services", make_services)(card)

    async def cue(name: str) -> None:  # the phone drops sfx; kept so the steer's clock behaves as in the studio
        stage({"stage": "sfx", "name": name})
        await clip_out.cue(name)

    memory = MemoryTurn(DeviceHub(store), card, user_id, session_id, log, _dep(deps, "memory_client") or default_memory_client(), ledger)
    memory.start()
    steer = PolicySteer(jev=jev, learner=_dep(deps, "learner") or base_learner(), slug=card.slug, user_id=user_id, default_decision=card.calibration.default_decision, clips=player,
                        on_event=lambda e: (log(**e), outcomes.on_event(e)), on_jev_call=ledger_obs.jev_call, on_stage=stage, on_cue=cue, pace=pace, memory=memory,
                        knowledge=(lambda text: shared.knowledge_for(card.language, text)) if shared is not None and shared.online else None)  # the decision point Tasks 16-18 hook: on_event gets every turn's decision

    async def act(params) -> None:
        turn = sum(m.get("role") == "user" for m in context.messages)
        result = await toolbox.run(params.function_name, dict(params.arguments), turn)
        for key in COMMANDS:
            if key in result:
                phone.send({"type": "tool", "name": key, "cmd": result[key]})
        await params.result_callback(result_text({k: v for k, v in result.items() if k not in COMMANDS}))  # the command is the phone's; the voice hears what was done

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
    task = PipelineTask(pipeline, params=PipelineParams(enable_metrics=True, enable_usage_metrics=True, enable_expressive_conversation=v.max_tags_per_reply > 0, expression_policy=policy if v.max_tags_per_reply > 0 else None), observers=[ledger_obs, latency], enable_rtvi=False)  # RTVI would echo every transcript, token and metric to the phone
    ending: list[str] = []  # why the call ended: bye, cap or gone

    async def end(reason: str) -> None:
        if not ending:
            ending.append(reason)
            await task.cancel()

    async def speak(kind: str) -> None:
        """A whole clip line: speaking while it plays, then listening unless something else moved the face meanwhile."""
        phone.state("speaking")
        mark = phone.changes
        seconds = await player.play(kind)
        asyncio.get_running_loop().call_later(seconds, lambda: phone.changes == mark and phone.state("listening"))

    async def interrupt() -> None:
        outcomes.interrupt()
        await task.queue_frame(InterruptionFrame())  # a barge-in: the TTS stops and the phone gets `clear`

    async def forget(fact_id: str) -> None:
        await memory.forget_by_id(fact_id)  # sends `memory {op: forget, id}`; end() scrubs it

    async def bye() -> None:
        await end("bye")

    phone.on_interrupt, phone.on_forget, phone.on_bye = interrupt, forget, bye

    async def cap() -> None:
        await asyncio.sleep(_dep(deps, "cap_seconds", CAP_SECONDS))
        await task.queue_frame(InterruptionFrame())  # a reply in flight stops; the goodbye does not play over it
        phone.state("speaking")
        seconds = await player.play("goodbye")
        if player.last_said is None:  # no clip, or its line did not line up: the phone still reads it
            phone.said(card.lines.goodbye)
        await asyncio.sleep(seconds + BYE_GRACE)
        await end("cap")

    @latency.event_handler("on_latency_breakdown")
    async def breakdown(_, b):
        log(kind="latency")

    @pair.assistant().event_handler("on_assistant_turn_stopped")
    async def said(_, message):
        log(kind="said")  # the words went to the phone sentence by sentence (ClipOut); none are logged

    @pair.user().event_handler("on_user_turn_started")
    async def hearing(*_):
        stage({"stage": "hearing"})

    @transport.event_handler("on_client_connected")
    async def connected(_, __):
        ledger_obs.open_stt()
        if jev is not None:
            asyncio.ensure_future(jev.warm())
        asyncio.ensure_future(warm_llm(s.llm))
        log(kind="connected")
        await speak("greeting")
        if card.disclose:
            await speak("disclosure")

    @transport.event_handler("on_client_disconnected")
    async def disconnected(_, __):
        log(kind="disconnected")
        await end("gone")

    capping = asyncio.ensure_future(cap())
    try:
        await PipelineRunner(handle_sigint=False).run(task)
    finally:
        capping.cancel()
        ledger_obs.flush_stt()
        await finish_call(websocket, phone, memory, context.messages, ending[0] if ending else "gone")
        await outcomes.end(call_s=asyncio.get_running_loop().time() - started)  # the last row, in the background: the socket is already closed


async def finish_call(websocket, phone: Phone, memory: MemoryTurn, messages: list[dict], reason: str) -> None:
    """The end of the call. On `bye` or the cap, with the socket still open: remembering, the call's summary and lasting facts go to the phone as `memory`, then `bye_ack` and a close. A phone that went away gets nothing and costs nothing more. After this the server holds nothing of the call. (Tasks 16-18 hook the shared layer here, after memory.end.)"""
    if reason in ("bye", "cap") and phone.open:
        phone.state("remembering")
        try:
            await memory.end(messages)
        except Exception as e:
            logger.warning(f"end of call memory failed: {type(e).__name__}")
        phone.send({"type": "bye_ack"})
        await phone.flush()
        try:
            await websocket.close(code=1000)
        except Exception:
            pass  # already gone
    elif memory.key is not None:
        memory.hub.detach(memory.key)
    phone.open = False


def turn_secs(breakdown) -> float:
    """User stopped to bot speaking. Pipecat's total_secs also counts a "pipeline" contribution that starts before the user spoke, which read as 6.6 s on a 3.3 s turn."""
    parts = [c.duration_secs for c in breakdown.contributions if c.key != "pipeline"]
    return sum(parts) if parts else breakdown.total_secs


STEER_LINES = re.compile(r"^\[(?:steer|learned|memory|knowledge):.*\]\n", re.M)


def clean_transcript(messages: list[dict]) -> list[dict]:
    out = []
    for m in messages:
        c = m.get("content")
        if m.get("role") in ("user", "assistant") and isinstance(c, str):
            out.append({"role": m["role"], "text": STEER_LINES.sub("", c)})
    return out


