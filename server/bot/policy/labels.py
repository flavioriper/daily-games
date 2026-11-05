# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""The policy's output (spec section 2) and the rules prior that labels the base's training data (spec section 5.1)."""
from dataclasses import asdict, dataclass

HEADS: dict[str, list[str]] = {
    "stance": ["execute", "advise", "clarify", "hold"],
    "register": ["brief", "standard", "thorough"],
    "warmth": ["neutral", "warm", "firm"],
    "ack": ["yes", "no"],
}

SURE = 0.7  # Fraction's Triage::SURE


@dataclass(frozen=True)
class Decision:
    stance: str
    register: str
    warmth: str
    ack: str

    def steer_line(self) -> str:
        return f"[steer: stance={self.stance} register={self.register} warmth={self.warmth} ack={self.ack}]"

    def as_dict(self) -> dict[str, str]:
        return asdict(self)


def prior(kind: str, kind_confidence: float, mood: str, words: int, verbosity: int | None) -> Decision:
    if kind in ("stop", "greeting", "off_topic"):
        stance = "hold"
    elif kind == "redo":
        stance = "execute"
    elif kind == "question":
        stance = "advise"
    else:
        stance = "execute" if kind_confidence >= SURE else "clarify"

    if verbosity is not None:
        register = "brief" if verbosity <= 1 else ("standard" if verbosity == 2 else "thorough")
    else:
        register = "brief" if words <= 4 else "standard"

    warmth = "warm" if mood in ("unsure", "excited") else ("firm" if mood == "frustrated" else "neutral")
    ack = "yes" if stance in ("execute", "advise") and kind_confidence >= SURE and mood != "frustrated" else "no"
    return Decision(stance, register, warmth, ack)
