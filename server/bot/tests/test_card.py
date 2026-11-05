import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from studio.card import PRONOUNS, Card, Owner, owner_name, owner_of

ROOT = Path(__file__).resolve().parent.parent


def test_owner_defaults_are_they_and_utc(card):
    assert card.owner is None
    o = owner_of(card)
    assert o.pronouns == "they"
    assert o.timezone == "UTC"
    assert o.work_hours == (9, 18)


def test_bad_timezone_is_refused():
    with pytest.raises(ValidationError):
        Owner(name="x", timezone="Mars/Base")


def test_work_hours_must_run_forwards_within_a_day():
    with pytest.raises(ValidationError):
        Owner(name="x", work_hours=(18, 9))
    assert Owner(name="x", work_hours=(0, 24)).work_hours == (0, 24)


def test_dana_fixture_is_a_neutral_agent_persona():
    text = (ROOT / "tests" / "fixtures" / "persona_dana.json").read_text()
    dana = Card.model_validate_json(text)
    o = owner_of(dana)
    assert dana.agent and dana.name == "Digital Dana"
    assert (o.name, o.pronouns, o.timezone) == ("Dana Reyes", "she", "Asia/Singapore")
    assert "flavio" not in text.lower()


def test_old_card_owner_comes_from_its_name(card):
    assert owner_of(card).name == owner_name(card)


def test_pronouns_table():
    assert PRONOUNS["they"] == {"subject": "they", "object": "them", "possessive": "their"}
    assert PRONOUNS["she"] == {"subject": "she", "object": "her", "possessive": "her"}
    assert PRONOUNS["he"] == {"subject": "he", "object": "him", "possessive": "his"}
