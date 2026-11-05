"""PolicySteer: Jev reads the turn, the policy decides, the decision goes on the user's message and into the persona's voice clips (spec 7.3, 8)."""
import asyncio
import random
import time
import uuid
from dataclasses import replace
from typing import Awaitable, Callable, Protocol

from pipecat.frames.frames import Frame, InterruptionFrame, LLMContextFrame, UserStartedSpeakingFrame, UserStoppedSpeakingFrame, UserTurnResponseCancelFrame
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

from policy.features import FEATURE_NAMES, KINDS, WORD, JevAnswers, named, vector
from policy.jev import JevError
from policy.labels import Decision
from policy.learn import Correction
from policy.model import Prediction, predict
from policy.mood import mood
from studio.corrections import FACTS, detect


SILENT_TOOLS = {"swarm", "move", "draw", "dots", "tone", "see"}  # tools that act on the screen, not the world: no typing sound, no bridge line


class Clips(Protocol):
    async def play(self, kind: str, gain: float = 1.0) -> None: ...


REFLEX_MIN_WORDS = 4
QUIET_KINDS = {"greeting", "off_topic", "stop"}  # nothing to work on, so no typing and no "hang on"
TASK_KINDS = {"answer", "redo"}  # a request: the persona is doing something, so typing fits
SHORT_REPLY_WORDS = 5
LAST_QUESTION = FEATURE_NAMES.index("has_last_question")


def gap_sound(stance: str, features: list[float] | None, text: str) -> str | None:
    """What fills the silence after this turn: None for a greeting, an aside, a stop or a short reply to the persona's own question; "typing" for a request being executed; "thinking" otherwise."""
    words = len(WORD.findall(text))
    if features is None:  # Jev was late: a short turn is probably a greeting
        if words < REFLEX_MIN_WORDS:
            return None
        kind = "answer"
    else:
        kind = max(KINDS, key=lambda k: features[KINDS.index(k)])
        if features[LAST_QUESTION] and words < SHORT_REPLY_WORDS:  # "I'm fine, thanks" after "how are you?" is not a job
            return None
    if kind in QUIET_KINDS:
        return None
    return "typing" if stance == "execute" and kind in TASK_KINDS else "thinking"


def barely_changed(early: str, final: str) -> bool:
    a, b = set(early.lower().split()), set(final.lower().split())
    return len(a ^ b) <= 0.2 * len(b)


def _text(message: dict) -> str:
    c = message.get("content")
    return c if isinstance(c, str) else "".join(p.get("text", "") for p in c or [] if isinstance(p, dict))


def _prepend(message: dict, prefix: str) -> None:
    c = message.get("content")
    if isinstance(c, str):
        message["content"] = prefix + c
    else:
        message["content"] = [{"type": "text", "text": prefix + _text(message)}]


KNOWLEDGE_CHARS = 400  # one row on the prompt at most this long
KNOWLEDGE_BUDGET_S = 0.8  # the shared layer's lookup may wait on its model or on Neon; past this the turn goes on without it


async def _within(task: asyncio.Task | None, budget: float) -> list[str]:
    """The knowledge rows if they come back within ``budget`` of being awaited, else none; never raises."""
    if task is None:
        return []
    try:
        rows = await asyncio.wait_for(task, budget)
    except asyncio.TimeoutError:
        return []
    except Exception:
        return []
    return [r for r in rows or [] if isinstance(r, str) and r.strip()]


def knowledge_lines(rows: list[str]) -> str:
    return "".join(f"[knowledge: {' '.join(r.split())[:KNOWLEDGE_CHARS].rstrip()}]\n" for r in rows)


LOOK_EVERY_S, LOOK_BEATS = 1.8, 4  # about seven seconds of looking; past that, quiet is honest


class PolicySteer(FrameProcessor):
    """The gap after the user stops is filled on one clock from that moment: a reflex at once, typing if the persona is doing something, a spoken bridge at bridge_after_s, a stall at stall_after_s. The first LLM text ends all of it. A greeting or an aside gets none of it, and one spoken filler per gap: after a reflex only the stall can follow."""

    def __init__(self, *, jev, learner, slug: str, user_id: str, default_decision: dict[str, str], clips: Clips, on_event: Callable[[dict], None],
                 on_fact: Callable[[str], None] = lambda _: None, on_jev_call: Callable[[], None] = lambda: None, on_stage: Callable[[dict], None] = lambda _: None,
                 on_cue: Callable[[str], Awaitable[None]] | None = None, jev_budget_s: float = 0.25, speculative_budget_s: float = 0.7, bridge_after_s: float = 2.0, stall_after_s: float = 4.5,
                 reflex_chance: float = 0.0, pace=None, rng=None, memory=None, knowledge: Callable[[str], Awaitable[list[str]]] | None = None, knowledge_budget_s: float = KNOWLEDGE_BUDGET_S, **kwargs):  # off: a "yeah" the moment the user stops is a filler with nothing to fill (Flavio, 2026-11-01)
        super().__init__(**kwargs)
        self.jev, self.learner, self.slug, self.user_id = jev, learner, slug, user_id
        self.default_decision = Decision(**default_decision)
        self.clips, self.on_event, self.on_fact, self.on_jev_call, self.on_stage = clips, on_event, on_fact, on_jev_call, on_stage
        self.on_cue = on_cue
        self._llm_sent: float | None = None
        self.budget, self.speculative_budget, self.bridge_after, self.stall_after, self.reflex_chance, self.pace = jev_budget_s, speculative_budget_s, bridge_after_s, stall_after_s, reflex_chance, pace
        self.rng = rng or random.Random()
        self.memory = memory
        self.knowledge, self.knowledge_budget = knowledge, knowledge_budget_s  # the shared layer's rows for what was just said
        self._early: tuple[str, asyncio.Task] | None = None
        self._asked: tuple[str, asyncio.Task] | None = None
        self._bridge: asyncio.Task | None = None
        self._overdue: asyncio.Task | None = None
        self._heard, self._reflexed, self._typing, self._answering, self._stopped = "", False, False, False, False
        self._looked = False
        self._stopped_at: float | None = None
        self._held: Callable[[], Awaitable[None]] | None = None  # the rest of a speculative turn, run when Flux commits
        self.last_features: list[float] | None = None
        self.last_decision: dict | None = None

    def _ask(self, text: str) -> asyncio.Task:
        if self._asked and self._asked[0] == text and not self._asked[1].cancelled():
            return self._asked[1]  # Flux's eager event and the speculative frame race for the same words
        self.on_jev_call()
        self._asked = (text, asyncio.ensure_future(self.jev.answers(text)))
        return self._asked[1]

    def start_early(self, text: str) -> None:
        """From Flux's eager end of turn: the commit usually lands after Jev has answered. Flux may re-issue the guess with a revised transcript; the same words keep the call in flight."""
        if self.jev is None:
            return
        if text.strip() and not (self._early and barely_changed(self._early[0], text) and not self._early[1].cancelled()):
            self._early = (text, self._ask(text))

    def heard(self, text: str) -> None:
        self._heard = text

    def decide(self, features: list[float]) -> Prediction:
        return predict(self.learner.base, self.learner.deltas_for(self.user_id, self.slug), features)

    def _stand_down(self) -> None:
        if self._bridge:
            self._bridge.cancel()
            self._bridge = None
        if self._typing:
            self._typing = False
            if self.on_cue:
                asyncio.ensure_future(self.on_cue("stop"))

    def on_llm_text(self) -> None:
        if self._llm_sent is not None:
            self.on_stage({"stage": "llm_first", "ms": round((time.perf_counter() - self._llm_sent) * 1000)})
            self._llm_sent = None
        self._answering = True
        self._stand_down()

    async def tools_started(self, names: list[str]) -> None:
        """A tool can run after the model has already spoken, when the gap clock has stood down, and the silence would read as a dead line. Reaching a person gets its one line and then real quiet."""
        if set(names) <= SILENT_TOOLS:
            return  # moving its own body is instant and needs no cover
        if "reach_owner" in names:
            self._stand_down()
            if not self._answering:
                await self.clips.play("reaching")
        elif "search_docs" in names:
            await self._look()
        elif self.on_cue and not self._typing:
            self._typing = True
            await self.on_cue("typing")

    async def _look(self) -> None:
        """A document search takes seconds, so it replaces the gap clock: papers at once, one line, then papers and one stall until the first word."""
        self._stand_down()
        if self.on_cue:
            await self.on_cue("papers")
        if not self._answering and not self._looked:
            self._looked = True
            await self.clips.play("searching")
        self._bridge = asyncio.ensure_future(self._keep_looking())

    async def _keep_looking(self) -> None:
        for beat in range(LOOK_BEATS):
            await asyncio.sleep(self._jitter(LOOK_EVERY_S))
            if beat == LOOK_BEATS - 2 and not self._answering:
                await self.clips.play("stalls")
            elif self.on_cue:
                await self.on_cue("papers")
        self._bridge = None

    def _jitter(self, seconds: float) -> float:
        """A filler on a fixed clock is a metronome; people vary by about a fifth."""
        return seconds * self.rng.uniform(0.8, 1.2)

    async def _bridge_later(self, kind: str, bridge: bool = True) -> None:
        since = time.perf_counter() - (self._stopped_at or time.perf_counter())
        await asyncio.sleep(max(0.0, self._jitter(self.bridge_after) - since))
        if bridge:
            await self.clips.play(kind)
        await asyncio.sleep(self._jitter(self.stall_after - self.bridge_after))
        self._bridge = None
        await self.clips.play("stalls")

    async def _late(self, task: asyncio.Task, text: str, last_bot: str, previous: list[float] | None) -> None:
        """Jev missed the budget, so this reply went on the persona default. Its answer still steers the next turn, and a correction still counts."""
        try:
            answers = await task
        except (JevError, asyncio.CancelledError):
            return
        self.last_features = vector(answers, mood(text), last_bot.rstrip().endswith("?"), text)
        hit = detect(answers, previous is not None)
        if hit:
            complaint, head, wanted = hit
            await asyncio.to_thread(self.learner.correct, Correction(self.user_id, self.slug, previous, head, wanted))
            self.on_fact(FACTS[complaint])
        self.on_stage({"stage": "jev_late", "correction": bool(hit)})

    async def _answers(self, text: str, budget: float) -> tuple[JevAnswers | None, str, int]:
        started = time.perf_counter()
        path = "final"
        self._overdue = None
        early, self._early = self._early, None
        if self.jev is None:  # no Jev for this language: every turn takes the card's default decision
            return None, "off", 0
        if early and barely_changed(early[0], text):
            task, path = early[1], "early"
        else:
            if early:
                early[1].cancel()
            task = self._ask(text)
        task.add_done_callback(lambda t: t.cancelled() or t.exception())  # an abandoned call must not log an unretrieved exception
        try:
            answers = await asyncio.wait_for(asyncio.shield(task), budget)
        except asyncio.TimeoutError:
            answers, path = None, "timeout"
            self._overdue = task
        except JevError:
            answers, path = None, "error"
        return answers, path, round((time.perf_counter() - started) * 1000)

    async def on_context(self, context, speculative: bool = False) -> None:
        self._llm_sent = None
        self._stand_down()
        self._answering, self._looked = False, False
        self._held = None
        message = next((m for m in reversed(context.messages) if m.get("role") == "user"), None)
        if message is None:
            return
        text = _text(message)
        if speculative:
            await self._early_reflex(text)
        previous = self.last_features
        last_bot = next((_text(m) for m in reversed(context.messages) if m.get("role") == "assistant"), "")
        self.on_stage({"stage": "jev", "text": text, "speculative": speculative})
        recalling = asyncio.ensure_future(self.memory.recall(text, last_bot)) if self.memory else None  # beside Jev, not after it: it has its own deadline
        knowing = asyncio.ensure_future(self.knowledge(text)) if self.knowledge and text.strip() else None  # beside Jev too, under its own budget
        knowing_from = time.perf_counter()
        # a guessed turn is held anyway, so it can wait for Jev; a committed one has someone waiting in silence
        answers, path, jev_ms = await self._answers(text, self.speculative_budget if speculative else self.budget)
        overdue, self._overdue = self._overdue, None
        policy_from = time.perf_counter()

        learned, prediction, features, correction = None, None, None, None
        if answers is not None:
            features = vector(answers, mood(text), last_bot.rstrip().endswith("?"), text)
            hit = detect(answers, previous is not None)
            if hit:
                complaint, head, wanted = hit
                correction = (complaint, Correction(self.user_id, self.slug, previous, head, wanted))
                if not speculative:  # a guessed turn may be withdrawn, and an unsaid complaint must not train anything
                    learned = await self._learn(correction)
                else:
                    learned = {"head": head, "wanted": wanted}
            prediction = self.decide(features)
        decision = prediction.decision if prediction else self.default_decision
        if learned:
            decision = replace(decision, register="brief", ack="yes")
        reflexed = self._reflexed
        spoken = replace(decision, ack="yes") if reflexed else decision

        recalled = await recalling if recalling else None
        memory_lines = "".join(line + "\n" for line in recalled.lines) if recalled else ""
        known = await _within(knowing, max(0.0, self.knowledge_budget - (time.perf_counter() - knowing_from)))  # the budget runs from the turn's start, not from here
        _prepend(message, spoken.steer_line() + "\n" + (f"[learned: {learned['head']}={learned['wanted']}]\n" if learned else "") + memory_lines + knowledge_lines(known))

        async def finish() -> None:
            nonlocal learned
            if correction and speculative:
                learned = await self._learn(correction)
            if features:
                self.last_features = features
            if overdue:
                asyncio.ensure_future(self._late(overdue, text, last_bot, previous))
            clips, gap = ["reflex"] if self._reflexed else [], None
            kick = time.perf_counter()
            if learned:
                clips.append("learned")
                await self.clips.play("learned")
                gap = 0
            elif decision.ack == "yes" and decision.stance != "hold" and not self._reflexed:
                clips.append("acks")
                await self.clips.play("acks")
                gap = 0
            if self._reflexed:
                gap = 0
            sound = None
            if not self._answering and not ({"acks", "learned"} & set(clips)):
                sound = gap_sound(decision.stance, features, text)
                await self._fill(decision.stance, sound, bridge=not self._reflexed)
            self.last_decision = decision.as_dict()
            self.on_stage({"stage": "policy", "ms": round((time.perf_counter() - policy_from) * 1000), "jev_ms": jev_ms, "path": path, "speculative": speculative})
            turn_id = uuid.uuid4().hex
            self.on_event({
                "kind": "turn", "turn_id": turn_id, "speculative": speculative, "text": text, "jev_ms": jev_ms, "jev_path": path,
                "features": named(features) if features else {}, "raw_features": features, "decision": decision.as_dict(),
                "override": prediction.override if prediction else None, "probabilities": prediction.probabilities if prediction else {}, "explanation": prediction.explanation if prediction else {},
                "steer": decision.steer_line(), "clips": clips, "learned": learned, "gap": sound, "perceived_gap_ms": gap if gap is None else round((time.perf_counter() - kick) * 1000),
                "pace": self.pace.pace() if self.pace else None, "wps": self.pace.words_per_second() if self.pace else None,
                "memory": recalled.event if recalled else None, "knowledge": len(known),
            })
            if self.memory:
                self.memory.schedule_after_turn(turn_id, text, last_bot, features, recalled)
            if not self._answering:
                self.on_stage({"stage": "llm"})
            if not speculative:
                self._llm_sent = time.perf_counter()

        if speculative:
            self._llm_sent = time.perf_counter()
        if not speculative or self._stopped:
            await finish()
        else:
            self._held = finish

    async def _learn(self, correction) -> dict:
        complaint, c = correction
        o = await asyncio.to_thread(self.learner.correct, c)
        self.on_fact(FACTS[complaint])
        return {"accepted": o.accepted, "reason": o.reason, "head": c.head, "wanted": c.wanted, "delta_norm": round(o.delta_norm, 4), "holdout": o.holdout}

    async def _small_sound(self) -> None:
        since = time.perf_counter() - (self._stopped_at or time.perf_counter())
        await asyncio.sleep(max(0.0, self._jitter(self.bridge_after * 0.7) - since))
        self._bridge = None
        await self.on_cue(self.rng.choice(["mouse", "chair"]))

    async def _fill(self, stance: str, sound: str | None, bridge: bool = True) -> None:
        if sound is None:  # a greeting or an aside: the reply comes when it comes
            return
        if stance == "hold":  # nothing to say and no reason to say it, but a person is still audibly there
            if self.on_cue:
                self._bridge = asyncio.ensure_future(self._small_sound())
            return
        if sound == "typing" and self.on_cue:
            self._typing = True
            await self.on_cue("typing")
        self._bridge = asyncio.ensure_future(self._bridge_later("bridges" if sound == "typing" else "thinking", bridge))

    async def _early_reflex(self, text: str) -> None:
        """Flux's guess lands long before its commit. If the guess is wrong the user is still talking, and an "mm" then is just listening."""
        if self.on_cue and not self._reflexed and len(text.split()) >= REFLEX_MIN_WORDS and self.rng.random() < self.reflex_chance:
            self._reflexed = True
            await self.on_cue("backchannel")

    async def _user_stopped(self) -> None:
        self._stopped, self._stopped_at = True, time.perf_counter()
        if not self._reflexed and len(self._heard.split()) >= REFLEX_MIN_WORDS and self.rng.random() < self.reflex_chance:
            self._reflexed = True
            await self.clips.play("reflexes")
        if self._held:
            held, self._held = self._held, None
            await held()

    def _user_started(self) -> None:
        self._stopped, self._reflexed, self._heard, self._stopped_at, self._held = False, False, "", None, None

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        if isinstance(frame, LLMContextFrame):
            await self.on_context(frame.context, speculative=getattr(frame, "speculation", False))
        elif isinstance(frame, InterruptionFrame):
            self.on_llm_text()
        elif isinstance(frame, UserStartedSpeakingFrame):
            self._user_started()
        elif isinstance(frame, UserStoppedSpeakingFrame):
            await self._user_stopped()
        elif isinstance(frame, UserTurnResponseCancelFrame):
            self._held = None  # the "mm" stands: a second one seconds later is what sounds mechanical
        await self.push_frame(frame, direction)


class AfterLLM(FrameProcessor):
    """Tells PolicySteer the model has started answering, so the bridge clip stands down."""

    def __init__(self, steer: PolicySteer, **kwargs):
        super().__init__(**kwargs)
        self.steer = steer

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        from pipecat.frames.frames import LLMTextFrame

        await super().process_frame(frame, direction)
        if isinstance(frame, LLMTextFrame):
            self.steer.on_llm_text()
        await self.push_frame(frame, direction)
