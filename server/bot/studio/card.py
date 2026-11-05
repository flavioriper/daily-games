"""The persona card (spec section 4): one JSON document per persona."""
import re
from typing import Literal
from zoneinfo import ZoneInfo

from pydantic import BaseModel, Field, field_validator

from policy.behaviour import Behaviour

SLUG = re.compile(r"[a-z0-9_-]{1,64}")


SEARCHING = ["Let me pull that up.", "Let me find that page.", "One sec, it's in here somewhere.", "Let me check the document.", "Okay, let me look that up.", "Hang on, let me find it."]


class Lines(BaseModel):
    greeting: str
    acks: list[str] = Field(default_factory=list)
    bridges: list[str] = Field(default_factory=list)
    backchannels: list[str] = Field(default_factory=list)
    learned: list[str] = Field(default_factory=list)
    reflexes: list[str] = Field(default_factory=list)  # the instant reaction when the user stops
    thinking: list[str] = Field(default_factory=list)  # a beat before giving an opinion
    stalls: list[str] = Field(default_factory=list)  # the wait has gone on too long
    reaching: list[str] = Field(default_factory=list)  # before going silent to try the real person
    searching: list[str] = Field(default_factory=lambda: list(SEARCHING))  # as a document search starts; defaulted so cards saved before this existed have it
    disclosure: str = "Just so you know, I'm an AI assistant."


class Expression(BaseModel):
    deliveries: list[str] = Field(default_factory=list)
    sounds: list[str] = Field(default_factory=list)
    max_tags_per_reply: int = 1


class Voice(BaseModel):
    provider: str = "elevenlabs"
    model: str = "eleven_v4_turbo"
    voice_id: str = ""
    stability: float = 0.35
    brief: str = ""
    expression: Expression = Field(default_factory=Expression)


class Brain(BaseModel):
    chat: str = "openai:gpt-6-luna"
    compile: str = "openai:gpt-6-luna"
    memory: str = "openai:gpt-6-luna"


class Calibration(BaseModel):
    delta_norm: float
    slice: dict[str, float]
    accepted: bool
    default_decision: dict[str, str]


PRONOUNS: dict[str, dict[str, str]] = {
    "they": {"subject": "they", "object": "them", "possessive": "their"},
    "she": {"subject": "she", "object": "her", "possessive": "her"},
    "he": {"subject": "he", "object": "him", "possessive": "his"},
}


REFLEXIVE = {"they": "themself", "she": "herself", "he": "himself"}
PLURAL_VERBS = {"is": "are", "has": "have", "goes": "go", "does": "do", "was": "were"}  # for "they"; a regular verb drops its s


class _Words(dict):
    def __init__(self, owner: "Owner"):
        super().__init__(name=owner.name, reflexive=REFLEXIVE[owner.pronouns], **PRONOUNS[owner.pronouns])
        self.owner = owner

    def __missing__(self, verb: str) -> str:
        if verb not in PLURAL_VERBS and not verb.endswith("s"):
            raise KeyError(verb)  # a typo such as {possesive} fails loudly instead of printing the bare word
        return self.owner.verb(verb)


class Owner(BaseModel):
    """The person a persona stands in for. Pronouns are stated, never inferred from the name."""
    name: str
    pronouns: Literal["they", "she", "he"] = "they"
    timezone: str = "UTC"
    work_hours: tuple[int, int] = (9, 18)

    @field_validator("timezone")
    @classmethod
    def known_timezone(cls, v: str) -> str:
        try:
            ZoneInfo(v)
        except Exception as e:  # ZoneInfoNotFoundError, ValueError for malformed keys
            raise ValueError(f"unknown timezone: {v}") from e
        return v

    @field_validator("work_hours")
    @classmethod
    def forward_hours(cls, v: tuple[int, int]) -> tuple[int, int]:
        if not 0 <= v[0] < v[1] <= 24:
            raise ValueError("work_hours must be (start, end) with 0 <= start < end <= 24")
        return v

    def verb(self, third_person: str) -> str:
        """A present-tense verb agreeing with the owner's pronoun: "asks" for she and he, "ask" for they."""
        if self.pronouns != "they":
            return third_person
        return PLURAL_VERBS.get(third_person) or third_person.removesuffix("s")

    def fill(self, template: str) -> str:
        """Fills {name}, {subject}, {object}, {possessive}, {reflexive}, and any {verb} in its she/he form, e.g. "when {subject} {goes} quiet"."""
        return template.format_map(_Words(self))


class Card(BaseModel):
    slug: str
    name: str
    language: str = "en"
    identity: str
    style: list[str]
    lines: Lines
    behaviour: Behaviour = Behaviour()
    voice: Voice = Field(default_factory=Voice)
    brain: Brain = Field(default_factory=Brain)
    facts: list[str] = Field(default_factory=list)
    notes: str = ""
    room: str | None = "office"  # the sound of the place; empty or null for none
    disclose: bool = False  # say it is an AI right after the greeting; on for calls with the public
    owner: Owner | None = None  # who the persona stands in for; old cards have none, see owner_of
    agent: bool = False  # acts on the owner's real Gmail and Calendar; see agent/tools.py
    screen: bool = Field(False, exclude=True)  # the person sees the swarm (the owner at /home): the swarm tool is offered. Set per session by owner_view, never stored
    created_at: str = ""
    calibration: Calibration | None = None

    @field_validator("slug")
    @classmethod
    def safe_slug(cls, v: str) -> str:
        if not SLUG.fullmatch(v):
            raise ValueError("slug must be 1-64 lowercase letters, digits, _ or -")
        return v


def owner_name(card: Card) -> str:
    """The person the persona stands in for, guessed from the card's name: "Digital Dana" stands in for Dana."""
    return re.sub(r"^(digital|virtual|ai)\s+", "", card.name.strip(), flags=re.I) or card.name


def owner_of(card: Card) -> Owner:
    """The card's owner; an old card without one gets the name guess, with default pronouns and timezone."""
    return card.owner or Owner(name=owner_name(card))


def owner_view(card: Card) -> Card:
    """The same persona, told it is talking to its owner at their own desk rather than to a caller. Not stored."""
    return card.model_copy(update={"identity": card.identity + owner_of(card).fill(SEAT), "screen": True})


SEAT = (" Right now you are not on a call with anyone else: the person talking to you is {name} {reflexive}, the owner, at {possessive} own desk in the studio. "
        "Speak to {object} as {possessive} own assistant: say \"you\" and \"your calendar\", never the third person and never \"{name}'s\". Nobody needs to be reached or booked on {possessive} behalf unless {subject} {asks}. "
        "You can act on {possessive} calendar and inbox, both real, the same way, and the same confirmations apply. "
        "On {possessive} screen your body is a swarm of glowing dots that forms your face. When {subject} {asks} you to look somewhere or change how your eyes behave, call the swarm tool; when {subject} {asks} you to move, go somewhere on screen or get out of the way, call the move tool; then say in a few words what you did. "
        "A last line starting [screen: says what is on {possessive} screen right now, where your face sits, where your eyes are, what they do when {subject} {is} quiet, and how long {subject} {has} been quiet; use it to pick targets and never read it out. "
        "Silence is part of the conversation: your idle setting is how your face stays alive while {subject} {reads} or {thinks}, so keep it fitting what is happening.")
