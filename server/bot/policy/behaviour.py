"""Behaviour parameters: one override function that any compiled persona is a point of (spec 4.1). The four legacy personas are templates."""
from dataclasses import asdict, dataclass, fields

from policy.labels import Decision


@dataclass(frozen=True)
class Behaviour:
    clarify_below_complete: float | None = None
    advise_above_decision: float | None = None
    advise_on_question: float | None = None
    never_clarify: bool = False
    hold_unless_asked: float | None = None
    register: str = "base"
    register_hurried_fallback: bool = False
    warmth: str = "base"
    warmth_frustrated_fallback: bool = False
    firm_when_upset: float | None = None
    ack: str = "base"

    @classmethod
    def from_dict(cls, d: dict) -> "Behaviour":
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in d.items() if k in known})

    def as_dict(self) -> dict:
        return asdict(self)


TEMPLATES: dict[str, Behaviour] = {
    "cautious_advisor": Behaviour(clarify_below_complete=0.8, advise_above_decision=0.6, register="thorough", register_hurried_fallback=True, warmth="warm", warmth_frustrated_fallback=True, ack="yes"),
    "blunt_operator": Behaviour(never_clarify=True, register="brief", warmth="neutral", firm_when_upset=0.5, ack="no"),
    "onboarding_guide": Behaviour(advise_on_question=0.5, register="standard", warmth="warm", ack="yes"),
    "silent_partner": Behaviour(hold_unless_asked=0.7, register="brief", warmth="neutral", ack="no"),
}


def override(b: Behaviour, base: Decision, f: dict[str, float]) -> Decision:
    hold = base.stance == "hold"
    stance = base.stance
    if b.clarify_below_complete is not None and stance == "execute" and f["complete"] < b.clarify_below_complete:
        stance = "clarify"
    if b.advise_above_decision is not None and not hold and f["decision_needed"] >= b.advise_above_decision:
        stance = "advise"
    if b.advise_on_question is not None and not hold and f["kind_question"] >= b.advise_on_question:
        stance = "advise"
    if b.never_clarify and stance == "clarify":
        stance = "execute"
    if b.hold_unless_asked is not None and not (f["kind_question"] >= b.hold_unless_asked or f["decision_needed"] >= b.hold_unless_asked):
        stance = "hold"

    register = base.register if b.register == "base" or (b.register_hurried_fallback and f["mood_hurried"] >= 0.5) else b.register
    warmth = base.warmth if b.warmth == "base" or (b.warmth_frustrated_fallback and f["mood_frustrated"] >= 0.5) else b.warmth
    if b.firm_when_upset is not None and f["upset"] >= b.firm_when_upset:
        warmth = "firm"
    ack = "no" if hold or stance == "hold" else (base.ack if b.ack == "base" else b.ack)
    return Decision(stance, register, warmth, ack)
