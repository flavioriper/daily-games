from voice.prompt import system_prompt


def test_prompt_renders_nothing_yet_and_legend(card):
    p = system_prompt(card)
    assert "nothing yet" in p and p.startswith("You are Nilo.") and "[learned:" in p
    assert "prefers short answers" in system_prompt(card.model_copy(update={"facts": ["prefers short answers"]}))
