# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""The policy's input: 21 floats in a fixed order (spec section 3)."""
import math
import re
from dataclasses import dataclass

KINDS = ["answer", "question", "redo", "greeting", "off_topic", "stop"]
MOODS = ["calm", "unsure", "frustrated", "excited", "hurried"]
PACES = ["slow", "normal", "fast"]

FEATURE_NAMES = (
    [f"kind_{k}" for k in KINDS]
    + ["complete", "wants_detail", "upset", "decision_needed"]
    + [f"mood_{m}" for m in MOODS]
    + ["mood_confidence"]
    + [f"pace_{p}" for p in PACES]
    + ["has_last_question", "log_words"]
)
DIM = len(FEATURE_NAMES)

WORD = re.compile(r"[A-Za-z0-9']+")


@dataclass
class JevAnswers:
    kind: dict[str, float]
    complete: float
    wants_detail: float
    upset: float
    decision_needed: float
    complaint: str = "none"  # not a feature: spoken-correction signal (spec 8)
    complaint_p: float = 0.0


@dataclass
class MoodResult:
    mood: str
    confidence: float
    pace: str


def vector(jev: JevAnswers, mood: MoodResult, has_last_question: bool, text: str) -> list[float]:
    return (
        [float(jev.kind[k]) for k in KINDS]
        + [jev.complete, jev.wants_detail, jev.upset, jev.decision_needed]
        + [1.0 if mood.mood == m else 0.0 for m in MOODS]
        + [mood.confidence]
        + [1.0 if mood.pace == p else 0.0 for p in PACES]
        + [1.0 if has_last_question else 0.0, math.log(1 + len(WORD.findall(text)))]
    )


def named(v: list[float]) -> dict[str, float]:
    return dict(zip(FEATURE_NAMES, v))
