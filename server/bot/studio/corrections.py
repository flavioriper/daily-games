"""Spoken complaints as corrections on the previous turn (spec section 8)."""
from policy.features import JevAnswers

COMPLAINTS: dict[str, tuple[str, str]] = {
    "too_long": ("register", "brief"),
    "too_short": ("register", "thorough"),
    "too_soft": ("warmth", "firm"),
    "too_harsh": ("warmth", "warm"),
    "too_many_questions": ("stance", "execute"),
    "should_have_asked": ("stance", "clarify"),
    "too_eager_ack": ("ack", "no"),
}
FACTS: dict[str, str] = {
    "too_long": "prefers short answers",
    "too_short": "prefers complete answers",
    "too_soft": "prefers direct answers",
    "too_harsh": "prefers a gentler tone",
    "too_many_questions": "prefers action over questions",
    "should_have_asked": "wants to be asked before you act",
    "too_eager_ack": "dislikes filler acknowledgements",
}


def detect(answers: JevAnswers, bot_spoke_last_turn: bool, threshold: float = 0.7) -> tuple[str, str, str] | None:
    if not bot_spoke_last_turn or answers.complaint not in COMPLAINTS or answers.complaint_p < threshold:
        return None
    return (answers.complaint, *COMPLAINTS[answers.complaint])
