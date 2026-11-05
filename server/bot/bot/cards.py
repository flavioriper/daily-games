"""The Swarm card: one seed, a set of spoken lines per language."""
import json
from pathlib import Path

from studio.card import Card

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "seeds" / "swarm.json"
CLIPS = ROOT / "voices" / "swarm"  # one folder per language: CLIPS / <language> / manifest.json
LANGUAGES = ("en", "pt", "es")


def load_card(language: str) -> Card:
    """The Swarm card speaking `language`: the seed with `language` set and `lines` from `lines_<language>`."""
    if language not in LANGUAGES:
        raise ValueError(f"unsupported language: {language}")
    seed = json.loads(SEED.read_text())
    lines = {code: seed.pop(f"lines_{code}") for code in LANGUAGES}
    seed["language"] = language
    seed["lines"] = lines[language]
    return Card.model_validate(seed)


def clip_card(card: Card) -> Card:
    """The card as the clip tools see it: render_clips and ClipPlayer look in <root>/<card.slug>, so the slug becomes the language and the root is CLIPS."""
    return card.model_copy(update={"slug": card.language})
