import asyncio
from dataclasses import replace

from pipecat.processors.aggregators.llm_context import LLMContext

from policy.features import KINDS, JevAnswers
from policy.jev import JevError
from policy.learn import Outcome
from policy.model import Delta
from tests.conftest import load_base
from voice.steer import PolicySteer


def answers(kind="answer", p=0.9, complete=0.9, stop=0.0, complaint="none", complaint_p=0.0):
    k = {n: 0.02 for n in KINDS}
    k[kind] = p
    if stop:
        k["stop"] = stop
    return JevAnswers(kind=k, complete=complete, wants_detail=0.1, upset=0.1, decision_needed=0.1, complaint=complaint, complaint_p=complaint_p)


class FakeJev:
    def __init__(self, result=None, delay=0.0, error=False):
        self.result, self.delay, self.error, self.calls = result or answers(), delay, error, 0

    async def answers(self, text):
        self.calls += 1
        await asyncio.sleep(self.delay)
        if self.error:
            raise JevError("no key")
        return self.result


class FakeLearner:
    def __init__(self):
        self.base = load_base()
        self.persona = Delta.zeros()
        self.corrections = []
        self.calls = []
        self.outcome = Outcome(True, "accepted", 1.0, {"stance": 0.9})

    def deltas_for(self, user, slug):
        self.calls.append("deltas")
        return [self.persona]

    def correct(self, c):
        self.calls.append("correct")
        self.corrections.append(c)
        return self.outcome


class FakeClips:
    def __init__(self):
        self.played = []

    async def play(self, kind, gain=1.0):
        self.played.append(kind)


STAGES = []
DEFAULT = {"stance": "execute", "register": "brief", "warmth": "neutral", "ack": "no"}


def make(jev=None, budget=0.4, bridge=30.0, pace=None, ack=None):
    events, facts = [], []
    clips, learner = FakeClips(), FakeLearner()

    class Steer(PolicySteer):
        def decide(self, features):
            p = super().decide(features)
            if ack and p.decision.stance != "hold":
                p.decision = replace(p.decision, ack=ack)
            return p

    steer = Steer(jev=jev or FakeJev(), learner=learner, slug="p", user_id="u", default_decision=DEFAULT, clips=clips, on_event=events.append, on_fact=facts.append, jev_budget_s=budget, bridge_after_s=bridge, pace=pace, on_stage=STAGES.append)
    return steer, clips, events, learner, facts


def ctx(text):
    return LLMContext(messages=[{"role": "user", "content": text}])


async def test_steer_line_is_prepended_and_ack_clip_plays():
    steer, clips, events, *_ = make(ack="yes")
    c = ctx("shorten my headline")
    await steer.on_context(c)
    assert c.messages[-1]["content"].startswith("[steer: stance=")
    assert c.messages[-1]["content"].endswith("\nshorten my headline")
    assert clips.played == ["acks"] and events[-1]["jev_path"] == "final"


async def test_jev_timeout_uses_default_decision_and_marks_it():
    steer, clips, events, *_ = make(jev=FakeJev(delay=2.0), budget=0.05)
    c = ctx("hello there")
    await steer.on_context(c)
    assert c.messages[-1]["content"].startswith("[steer: stance=execute register=brief warmth=neutral ack=no]")
    assert events[-1]["jev_path"] == "timeout"


async def test_jev_error_degrades_like_a_timeout():
    steer, _, events, *_ = make(jev=FakeJev(error=True))
    c = ctx("hello there")
    await steer.on_context(c)
    assert c.messages[-1]["content"].startswith("[steer: stance=execute") and events[-1]["jev_path"] == "error"


async def test_pace_is_reported_but_not_fed_to_the_net():
    class P:
        def pace(self):
            return "fast"

        def words_per_second(self):
            return 4.1

    steer, _, events, *_ = make(pace=P())
    await steer.on_context(ctx("quick one for you here"))
    f = events[-1]["features"]
    assert f["pace_normal"] == 1.0 and f["pace_fast"] == 0.0 and events[-1]["pace"] == "fast"


async def test_early_answer_is_reused_when_text_barely_changed():
    jev = FakeJev()
    steer, _, events, *_ = make(jev=jev)
    steer.start_early("make my headline shorter and maybe a bit punchier please")
    await steer.on_context(ctx("make my headline shorter and maybe a bit punchier please now"))
    assert jev.calls == 1 and events[-1]["jev_path"] == "early"


async def test_early_answer_is_dropped_when_text_moved():
    jev = FakeJev()
    steer, *_ = make(jev=jev)
    steer.start_early("make my")
    await asyncio.sleep(0)
    await steer.on_context(ctx("make my headline shorter and punchier"))
    assert jev.calls == 2


async def test_stop_rule_overrides_and_plays_nothing():
    steer, clips, events, *_ = make(jev=FakeJev(answers(kind="stop", p=0.95)), ack="yes")
    await steer.on_context(ctx("ok stop"))
    assert events[-1]["decision"]["stance"] == "hold" and clips.played == []


async def test_bridge_clip_fires_when_the_llm_is_slow_and_is_cancelled_by_text():
    steer, clips, *_ = make(bridge=0.02, ack="no")
    await steer.on_context(ctx("what now"))
    await asyncio.sleep(0.05)
    assert clips.played == ["thinking"]  # the opening stance is advise; execute plays a bridge
    steer, clips, *_ = make(bridge=0.02, ack="no")
    await steer.on_context(ctx("what now"))
    steer.on_llm_text()
    await asyncio.sleep(0.05)
    assert clips.played == []


async def test_first_turn_complaint_is_ignored():
    steer, clips, events, learner, _ = make(jev=FakeJev(answers(complaint="too_long", complaint_p=0.95)))
    await steer.on_context(ctx("you talk too much"))
    assert learner.corrections == [] and "learned" not in clips.played


async def test_complaint_corrects_previous_turn_before_deciding():
    jev = FakeJev()
    steer, clips, events, learner, facts = make(jev=jev, ack="no")
    await steer.on_context(ctx("draft the email"))
    steer.on_llm_text()
    prev = steer.last_features
    jev.result = answers(complaint="too_long", complaint_p=0.9)
    learner.calls.clear()
    c = ctx("you talk too much")
    await steer.on_context(c)
    assert learner.corrections[0].features == prev and (learner.corrections[0].head, learner.corrections[0].wanted) == ("register", "brief")
    assert learner.calls[:2] == ["correct", "deltas"]
    content = c.messages[-1]["content"]
    assert "register=brief" in content and "ack=yes" in content and "\n[learned: register=brief]\n" in content
    assert clips.played == ["learned"] and facts == ["prefers short answers"]
    assert events[-1]["learned"]["accepted"] is True


async def test_refused_correction_still_plays_and_keeps_the_fact():
    jev = FakeJev()
    steer, clips, events, learner, facts = make(jev=jev)
    await steer.on_context(ctx("draft the email"))
    steer.on_llm_text()
    jev.result = answers(complaint="too_many_questions", complaint_p=0.9)
    learner.outcome = Outcome(False, "would regress held-out stance", 0.0, {})
    await steer.on_context(ctx("stop asking me things"))
    assert clips.played == ["learned"] and len(facts) == 1 and events[-1]["learned"]["accepted"] is False


async def test_stages_are_announced_in_order_with_timings():
    STAGES.clear()
    steer, _, events, *_ = make(ack="no")
    await steer.on_context(ctx("draft the email"))
    steer.on_llm_text()
    steer.on_llm_text()
    names = [s["stage"] for s in STAGES]
    assert names == ["jev", "policy", "llm", "llm_first"]
    assert "ms" in STAGES[1] and STAGES[1]["path"] == "final" and "ms" in STAGES[3]
    assert events[-1]["probabilities"]["stance"]


async def test_no_llm_first_stage_without_a_turn():
    STAGES.clear()
    steer, *_ = make()
    steer.on_llm_text()
    assert STAGES == []


def gap_steer(jev=None, budget=0.4, stance="execute", chance=1.0, bridge=0.03, stall=0.06):
    steer, clips, events, learner, facts = make(jev=jev, budget=budget, bridge=bridge)
    cues = []

    async def cue(name):
        cues.append(name)

    steer.on_cue, steer.stall_after, steer.reflex_chance = cue, stall, chance
    decide = steer.decide

    def forced(features):
        p = decide(features)
        p.decision = replace(p.decision, stance=stance, ack="no")
        return p

    steer.decide = forced
    return steer, clips, events, learner, facts, cues


async def test_reflex_plays_at_once_and_the_reply_is_told_not_to_repeat_it():
    steer, clips, events, *_ , cues = gap_steer()
    steer.heard("can you check the invoice for me")
    await steer._user_stopped()
    assert clips.played == ["reflexes"]
    c = ctx("can you check the invoice for me")
    await steer.on_context(c)
    assert "ack=yes" in c.messages[-1]["content"].splitlines()[0]
    assert "reflex" in events[-1]["clips"] and events[-1]["perceived_gap_ms"] is not None
    steer.on_llm_text()


async def test_no_reflex_on_a_short_turn():
    steer, clips, *_ = gap_steer()
    steer.heard("hi there")
    await steer._user_stopped()
    assert clips.played == []


async def test_execute_types_bridges_then_stalls_and_first_word_stops_it():
    steer, clips, _, _, _, cues = gap_steer(stance="execute")
    await steer.on_context(ctx("send it"))
    await asyncio.sleep(0.12)
    assert cues == ["typing"] and clips.played == ["bridges", "stalls"]
    steer.on_llm_text()
    await asyncio.sleep(0)
    assert cues == ["typing", "stop"]


async def test_advice_thinks_out_loud_without_typing():
    steer, clips, _, _, _, cues = gap_steer(stance="advise")
    await steer.on_context(ctx("which one"))
    await asyncio.sleep(0.05)
    assert cues == [] and clips.played == ["thinking"]
    steer.on_llm_text()


async def test_hold_says_nothing_but_the_room_is_alive():
    steer, clips, _, _, _, cues = gap_steer(stance="hold")
    await steer.on_context(ctx("hello"))
    await asyncio.sleep(0.05)
    assert cues in (["mouse"], ["chair"]) and clips.played == []


async def test_late_jev_still_trains_on_a_correction():
    jev = FakeJev(answers(complaint="too_long", complaint_p=0.95), delay=0.03)
    steer, _, events, learner, facts, _ = gap_steer(jev=jev, budget=0.001)
    steer.last_features = [0.0] * 21
    await steer.on_context(ctx("you talk too much"))
    assert events[-1]["jev_path"] == "timeout"
    steer.on_llm_text()
    await asyncio.sleep(0.08)
    assert learner.corrections and facts


async def test_speculative_turn_waits_for_the_commit_and_a_withdrawn_one_leaves_nothing():
    steer, clips, events, learner, *_ = gap_steer(jev=FakeJev(answers(complaint="too_long", complaint_p=0.95)))
    steer.last_features = [0.0] * 21
    c = ctx("you talk too much")
    await steer.on_context(c, speculative=True)
    assert c.messages[-1]["content"].startswith("[steer:") and "[learned:" in c.messages[-1]["content"]
    assert events == [] and learner.corrections == []  # nothing is final while the user may still be talking
    steer._user_started()
    assert steer._held is None and learner.corrections == []
    await steer.on_context(ctx("you talk too much"), speculative=True)
    await steer._user_stopped()
    assert len(events) == 1 and learner.corrections
    steer.on_llm_text()


async def test_early_reflex_fires_on_the_guess_and_not_again_at_the_commit():
    steer, clips, _, _, _, cues = gap_steer()
    await steer.on_context(ctx("can you check the invoice"), speculative=True)
    assert cues == ["backchannel"]
    steer.heard("can you check the invoice")
    await steer._user_stopped()
    assert clips.played == []  # no second "mm" at the commit
    steer.on_llm_text()


async def test_a_greeting_gets_no_typing_and_no_bridge():
    steer, clips, _, _, _, cues = gap_steer(jev=FakeJev(answers(kind="greeting")), stance="execute")
    await steer.on_context(ctx("hey are you there"))
    await asyncio.sleep(0.12)
    assert cues == [] and clips.played == []


async def test_a_question_thinks_out_loud_without_typing_even_on_execute():
    steer, clips, _, _, _, cues = gap_steer(jev=FakeJev(answers(kind="question")), stance="execute")
    await steer.on_context(ctx("what do you do all day"))
    await asyncio.sleep(0.12)
    assert cues == [] and clips.played == ["thinking", "stalls"]
    steer.on_llm_text()


async def test_a_short_turn_with_jev_late_fills_nothing():
    steer, clips, _, _, _, cues = gap_steer(jev=FakeJev(delay=2.0), budget=0.001, stance="execute")
    await steer.on_context(ctx("hi there"))
    await asyncio.sleep(0.12)
    assert cues == [] and clips.played == []


async def test_after_a_reflex_only_the_stall_follows():
    steer, clips, _, _, _, cues = gap_steer(stance="execute")
    steer.heard("can you check the invoice for me")
    await steer._user_stopped()
    await steer.on_context(ctx("can you check the invoice for me"))
    await asyncio.sleep(0.12)
    assert cues == ["typing"] and clips.played == ["reflexes", "stalls"]
    steer.on_llm_text()


async def test_the_turn_event_says_what_the_gap_sounds_like():
    steer, _, events, _, _, _ = gap_steer(jev=FakeJev(answers(kind="greeting")), stance="execute")
    await steer.on_context(ctx("hey are you there"))
    assert events[-1]["gap"] is None
    steer, _, events, _, _, _ = gap_steer(stance="execute")
    await steer.on_context(ctx("send the invoice"))
    assert events[-1]["gap"] == "typing"
    steer.on_llm_text()


async def test_no_reflex_by_default_the_reply_speaks_for_itself():
    steer, clips, _, _, _, cues = gap_steer(stance="execute", chance=steer_default_reflex_chance())
    steer.heard("can you check the invoice for me")
    await steer._user_stopped()
    await steer.on_context(ctx("can you check the invoice for me"), speculative=True)
    assert clips.played == [] and "backchannel" not in cues  # the request still types; nothing is said before the reply


def steer_default_reflex_chance():
    import inspect

    return inspect.signature(PolicySteer.__init__).parameters["reflex_chance"].default


async def test_hold_on_a_greeting_makes_no_sound_at_all():
    steer, clips, _, _, _, cues = gap_steer(jev=FakeJev(answers(kind="greeting")), stance="hold")
    await steer.on_context(ctx("hey boyd how are you"))
    await asyncio.sleep(0.05)
    assert cues == [] and clips.played == []


def test_gap_timers_are_jittered_so_there_is_no_fixed_rhythm():
    import random

    steer, *_ = make()
    steer.rng = random.Random(7)
    draws = {round(steer._jitter(2.0), 3) for _ in range(20)}
    assert len(draws) > 10 and all(1.6 <= d <= 2.4 for d in draws)


async def test_a_short_reply_to_the_personas_own_question_fills_nothing():
    steer, clips, _, _, _, cues = gap_steer(stance="execute")
    c = LLMContext(messages=[{"role": "assistant", "content": "Doing fine. How about you?"}, {"role": "user", "content": "I'm fine. Thanks."}])
    await steer.on_context(c)
    await asyncio.sleep(0.12)
    assert cues == [] and clips.played == []
