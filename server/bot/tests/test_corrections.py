from policy.features import KINDS, JevAnswers
from policy.labels import HEADS
from studio.corrections import COMPLAINTS, FACTS, detect


def a(c, p):
    return JevAnswers(kind={k: 0.1 for k in KINDS}, complete=1, wants_detail=0, upset=0, decision_needed=0, complaint=c, complaint_p=p)


def test_mapping_is_complete_and_legal():
    assert set(COMPLAINTS) == {"too_long", "too_short", "too_soft", "too_harsh", "too_many_questions", "should_have_asked", "too_eager_ack"} == set(FACTS)
    assert all(v in HEADS[h] for h, v in COMPLAINTS.values())


def test_below_threshold_and_silent_bot_refuse():
    assert detect(a("too_long", 0.69), True) is None
    assert detect(a("too_long", 0.9), False) is None
    assert detect(a("none", 0.9), True) is None
    assert detect(a("too_long", 0.7), True) == ("too_long", "register", "brief")
