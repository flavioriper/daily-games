"""The Swarm card: one seed, a set of spoken lines per language, and ten voices (a woman's and a man's per accent).

The voices are the user's picks of 2026-11-06 (warm, playful and kind, full of energy but supportive; the
listening page is in docs/agents/bot.md). The phone sends its region and the player's voice in the hello;
the player can ask the Swarm to switch mid-call (the `voice` tool), and the phone keeps the choice.
"""
import json
import random
from pathlib import Path

from studio.card import Card

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "seeds" / "swarm.json"
CLIPS = ROOT / "voices" / "swarm"  # one folder per voice: CLIPS / <language>-<accent>-<gender> / manifest.json
LANGUAGES = ("en", "pt", "es")
GENDERS = ("female", "male")
TABLE = json.loads((ROOT / "seeds" / "swarm_voices.json").read_text())
ACCENTS = {lang: tuple(a) for lang, a in TABLE["accents"].items()}  # the first is the language's default
REGIONS = {(lang, code): accent for lang, codes in TABLE["regions"].items() for code, accent in codes.items()}  # the phone's country code; anything else takes the default
VOICES = {tuple(name.split("-")): tuple(v) for name, v in TABLE["voices"].items()}  # (language, accent, gender) -> (voice_id, name)
SEATS = {voice_id: seat for seat, (voice_id, _) in VOICES.items()}
# How the Swarm speaks of itself: Portuguese and Spanish mark it ("feita", "hecho"); English does not.
SELF = {
    "female": "Your voice is a woman's: when your language marks gender, speak of yourself in the feminine (pt: feita, obrigada, pronta; es: hecha, lista, contenta).",
    "male": "Your voice is a man's: when your language marks gender, speak of yourself in the masculine (pt: feito, obrigado, pronto; es: hecho, listo, contento).",
}


def accent_for(language: str, region: str | None) -> str:
    """The accent for a phone's country code ("GB", "ES"), or the language's default."""
    return REGIONS.get((language, (region or "").upper()), ACCENTS[language][0])


def pick_gender(gender: str | None, rng=random) -> str:
    """The player's voice as the phone sent it, or a coin toss for a player who has none yet (the user, 2026-11-06: random per player)."""
    return gender if gender in GENDERS else rng.choice(GENDERS)


def load_card(language: str, accent: str | None = None, gender: str = "female") -> Card:
    """The Swarm card speaking `language` in the voice of `accent` and `gender`: the seed with `language` set, `lines` from `lines_<language>`
    with `lines_<language>_<gender>` over them (the lines where the Swarm speaks of itself), and the voice's id."""
    if language not in LANGUAGES:
        raise ValueError(f"unsupported language: {language}")
    if gender not in GENDERS:
        raise ValueError(f"unsupported gender: {gender}")
    accent = accent if accent in ACCENTS[language] else ACCENTS[language][0]
    seed = json.loads(SEED.read_text())
    lines = {code: seed.pop(f"lines_{code}") for code in LANGUAGES}
    overrides = {key: seed.pop(key) for key in [k for k in seed if k.startswith("lines_")]}
    seed["language"] = language
    seed["lines"] = {**lines[language], **overrides.get(f"lines_{language}_{gender}", {})}
    seed["identity"] = f"{seed['identity']} {SELF[gender]}"
    seed["voice"]["voice_id"] = VOICES[(language, accent, gender)][0]
    return Card.model_validate(seed)


def seat_of(card: Card) -> tuple[str, str, str]:
    """(language, accent, gender) of the card's voice."""
    return SEATS.get(card.voice.voice_id) or (card.language, ACCENTS[card.language][0], "female")


def other_gender(gender: str) -> str:
    return GENDERS[1 - GENDERS.index(gender)]


def clip_card(card: Card) -> Card:
    """The card as the clip tools see it: render_clips and ClipPlayer look in <root>/<card.slug>, so the slug becomes the voice's folder and the root is CLIPS."""
    return card.model_copy(update={"slug": "-".join(seat_of(card))})
