from policy.behaviour import TEMPLATES, Behaviour, override
from policy.features import named
from policy.labels import Decision


def test_hold_is_never_turned_into_speech():
    f = {k: 0.0 for k in ["complete", "decision_needed", "kind_question", "mood_hurried", "mood_frustrated", "upset"]}
    d = override(Behaviour(never_clarify=True, register="brief", ack="yes"), Decision("hold", "standard", "neutral", "no"), f)
    assert d.stance == "hold" and d.ack == "no"


def test_round_trip():
    b = TEMPLATES["cautious_advisor"]
    assert Behaviour.from_dict(b.as_dict()) == b
