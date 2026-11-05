import pytest

from bot.cards import load_card


@pytest.mark.parametrize("language", ["en", "pt", "es"])
def test_card_loads_each_language(language):
    card = load_card(language)
    assert card.language == language
    assert card.lines.greeting
    assert card.calibration.accepted
    assert card.disclose and card.room is None and not card.agent
    assert all(len(getattr(card.lines, k)) == 6 for k in ["acks", "bridges", "backchannels", "learned", "reflexes", "thinking", "stalls"])


def test_unknown_language_is_refused():
    with pytest.raises(ValueError):
        load_card("fr")
