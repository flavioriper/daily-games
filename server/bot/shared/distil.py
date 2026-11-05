"""Lessons at call end (spec amendment 2026-11-05): 0 to 3 general, impersonal lessons from a finished call, for review.

Two passes on gpt-6-luna, then a last check in code. The distil reads the cleaned transcript (no system prompt, no
knowledge or steer lines) and drafts lessons as `{kind, text}`. The scrub sees the drafts only, strips anything about a
person and refuses an item if anything personal is left. The last check refuses, when in doubt, what the scrub let
through: contact details, links, dates, money, ages, quotes, "the player said...", family, health, school, places.
What survives goes to `suggestions` as pending (no uid, no session id), where a person accepts, edits or rejects it
(tools/review_swarm_suggestions.py). Nothing here ever logs a lesson's text or the call's words: counts only.

All of it runs after `bye_ack`, in the background, with a timeout; a slow model or a down database costs the call
nothing and leaves nothing on disk.
"""
import asyncio
import json
import logging
import re
from collections import Counter

from studio.brains import openai_units

log = logging.getLogger("distil")

MODEL = "gpt-6-luna"
EFFORT = "low"
MAX_TOKENS = 2000  # reasoning counts against it
TIMEOUT_S = 90.0
LANGS = ("en", "pt", "es")
KINDS = ("question", "fix", "fact", "style")
MAX_LESSONS = 3
MAX_CHARS = 280  # a lesson is one or two short sentences
TRANSCRIPT_CHARS = 12000  # the end of a long call is enough
REASONS = ("name", "number", "place", "contact", "health", "school", "family", "quote", "personal", "not_general")
LANGUAGE = {"en": "English", "pt": "Brazilian Portuguese", "es": "Spanish"}

DISTIL = """You read the transcript of a voice call between a player of the Daily Puzzles game and the Swarm, the game's friendly companion. Find at most three general, impersonal lessons that would help the Swarm with every other player. A lesson is one of:
- question: a question about the game that players ask and the Swarm could not answer well; write it in general form, with the right answer if the call reached it.
- fix: the Swarm said something wrong about the game and was corrected; state the correct fact.
- fact: a true, general fact about the game or the Swarm that came up and is worth knowing.
- style: how the Swarm should speak to every player (length, tone, pace), only when the call clearly shows it.
Never write anything about this player: no names, ages, places, family, pets, school, health, contact details, dates, money, nor what they like, have, did or said. Never quote the player. If a lesson cannot be written without something personal, leave it out. Write each lesson in {language}, one or two short sentences, as a note for the Swarm. Most calls teach nothing: an empty list is the usual answer.
Answer JSON only: {"lessons": [{"kind": "question|fix|fact|style", "text": "..."}]}"""

SCRUB = """You are the privacy check on lessons a voice assistant wants to share with every player of a game. For each numbered lesson, first remove anything about a particular person: a name (of a person, a pet or anything they own), a number tied to a person (age, date, money, score, phone), a place (city, street, country, school, workplace), contact details (email, phone, address, link), health, school or family facts, what someone said, likes, has or did, and any quotation. Then judge what is left: "keep" only if it is a general statement about the game or about how the assistant should speak, true for every player, with nothing personal left; otherwise "refuse". When in doubt, refuse. For a refused lesson, give the main reason as one word from: name, number, place, contact, health, school, family, quote, personal, not_general.
Answer JSON only: {"verdicts": [{"n": 0, "verdict": "keep|refuse", "text": "the lesson after removal", "reason": ""}]}"""

_W = r"(?:'s)?"
CHECKS: list[tuple[str, re.Pattern]] = [(reason, re.compile(p, re.I)) for reason, p in (
    ("contact", r"https?://|www\.|\b[\w.-]+\.(?:com|org|net|io|app|br|es|pt|me)\b|\S+@\S+"),
    ("contact", r"\+?\d[\d\s().-]{6,}\d"),
    ("number", r"\b\d{4}-\d{1,2}-\d{1,2}\b|\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b|\b(?:19|20)\d{2}\b|\d{3,}"),
    ("number", r"\b(?:january|february|march|april|june|july|august|september|october|november|december"
               r"|janeiro|fevereiro|março|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro"
               r"|enero|febrero|marzo|mayo|junio|julio|septiembre|octubre|noviembre|diciembre|birthday|aniversário|cumpleaños)\b"),
    ("number", r"[$€£¥]|\bR\$|\b\d+\s*(?:dollars?|euros?|reais|real|reales|pesos?|bucks|cents?|centavos?)\b"),
    ("number", r"\byears? old\b|\baged?\s+\d|\b\d+\s*(?:anos|años|yo)\b|\b(?:tenho|tengo)\s+\d"),
    ("quote", r"[\"“”«»„]"),
    ("personal", rf"\b(?:the|this|that|a|one|o|a|esse|essa|este|esta|el|la|ese|esa)?\s*(?:player|user|caller|person|kid|child|boy|girl|he|she|they"
                 rf"|jogador|jogadora|usuário|usuária|usuario|usuaria|pessoa|criança|menino|menina|ele|ela|jugador|jugadora|persona|niño|niña|chico|chica|él|ella){_W}\s+"
                 r"(?:said|says|told|tells|mentioned|mentions|likes|liked|loves|loved|has|had|lives|lived|is|was|wants|wanted|named|called|works|goes"
                 r"|disse|diz|falou|contou|gosta|gostou|ama|tem|tinha|mora|morava|é|era|quer|queria|chama|chamou|trabalha|estuda|vai"
                 r"|dijo|dice|contó|le gusta|ama|tiene|tenía|vive|vivía|es|era|quiere|quería|llama|trabaja|estudia|va)\b"),
    ("personal", r"\b(?:i'm|i am|my name|i live|i have|eu sou|me chamo|meu nome|eu moro|eu tenho|me llamo|mi nombre|vivo en|moro em|yo tengo)\b"),
    ("family", r"\b(?:his|her|my|their|your|seu|sua|meu|minha|dele|dela|su|sus|mi|mis|tu|tus)\s+"
               r"(?:dog|cat|pet|mom|mum|mother|dad|father|sister|brother|son|daughter|wife|husband|kids?|children|grandma|grandmother|grandpa|grandfather|friend|boss|job|name|age|city|town|address|house|home|teacher|school"
               r"|cachorro|cão|gato|bicho|mãe|pai|irmã|irmão|filho|filha|esposa|marido|filhos|avó|avô|amigo|amiga|chefe|trabalho|nome|idade|cidade|endereço|casa|professor|professora|escola"
               r"|perro|gato|mascota|madre|mamá|padre|papá|hermana|hermano|hijo|hija|esposa|esposo|marido|hijos|abuela|abuelo|amigo|amiga|jefe|trabajo|nombre|edad|ciudad|dirección|casa|maestro|maestra|escuela|colegio)\b"),
    ("family", r"\b(?:mom|mum|dad|grandma|grandpa|wife|husband|boyfriend|girlfriend|mãe|pai|vovó|vovô|namorado|namorada|mamá|papá|abuela|abuelo|novio|novia)\b"),
    ("health", r"\b(?:hospital|doctor|nurse|sick|illness|disease|diagnos\w*|medicine|medication|therapy|pregnan\w*|disabilit\w*|adhd|autis\w*|cancer|depress\w*|anxiety"
               r"|médico|médica|enfermeira|doente|doença|remédio|terapia|grávida|deficiência|câncer|depressão|ansiedade"
               r"|enfermera|enfermo|enferma|enfermedad|medicina|embarazada|discapacidad|cáncer|depresión|ansiedad)\b"),
    ("school", r"\b(?:school|teacher|classroom|class of|grade \w+|homework|university|college|escola|professora?|sala de aula|lição de casa|faculdade|universidade"
               r"|escuela|colegio|maestr[oa]|profesor[a]?|tarea|universidad)\b"),
    ("place", r"\b(?:street|avenue|road|lane|rua|avenida|travessa|bairro|calle|carrera|barrio|colonia|neighbou?rhood|city of|cidade de|ciudad de|lives in|mora em|vive en)\b"),
)]


def local_refusal(text: str) -> str | None:
    """The last check, in code: the reason a lesson must not be shared, or None. Errs on refusing."""
    if not isinstance(text, str) or not text.strip() or len(text) > MAX_CHARS:
        return "not_general"
    for reason, pattern in CHECKS:
        if pattern.search(text):
            return reason
    return None


def transcript_of(messages: list[dict]) -> list[dict]:
    """The call as the summary sees it: user and assistant turns only, steer and knowledge lines gone."""
    from voice.bot import clean_transcript  # here: voice.bot imports this module

    return clean_transcript(messages)


def _lines(transcript: list[dict]) -> str:
    who = {"user": "player", "assistant": "swarm"}
    text = "\n".join(f"{who[t['role']]}: {' '.join(t['text'].split())}" for t in transcript if t.get("role") in who and t.get("text", "").strip())
    return text[-TRANSCRIPT_CHARS:]


async def _ask(client, system: str, user: str, on_usage) -> dict:
    r = await client.chat.completions.create(
        model=MODEL, reasoning_effort=EFFORT, max_completion_tokens=MAX_TOKENS, response_format={"type": "json_object"},
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
    )
    if on_usage is not None:
        try:
            on_usage(openai_units(r.usage))
        except Exception:
            log.warning("distil usage not recorded")
    try:
        out = json.loads(r.choices[0].message.content or "{}")
    except (ValueError, TypeError):
        return {}
    return out if isinstance(out, dict) else {}


async def draft(transcript: list[dict], lang: str, client, on_usage=None) -> list[dict]:
    """The first pass: up to three `{kind, text}` drafts; malformed items are dropped."""
    lines = _lines(transcript)
    if sum(1 for t in transcript if t.get("role") == "user") < 1 or sum(1 for t in transcript if t.get("role") == "assistant") < 1:
        return []
    out = await _ask(client, DISTIL.replace("{language}", LANGUAGE[lang]), lines, on_usage)
    items = out.get("lessons")
    if not isinstance(items, list):
        return []
    good = [{"kind": i["kind"], "text": " ".join(i["text"].split())} for i in items
            if isinstance(i, dict) and i.get("kind") in KINDS and isinstance(i.get("text"), str) and i["text"].strip()]
    return good[:MAX_LESSONS]


async def scrub(items: list[dict], client, on_usage=None) -> tuple[list[dict], Counter]:
    """The second pass and the last check: what may be shared, and the refusals counted by reason. A lesson with no
    clear `keep` verdict is refused."""
    refused: Counter = Counter()
    if not items:
        return [], refused
    numbered = "\n".join(f"{n}: {i['text']}" for n, i in enumerate(items))
    out = await _ask(client, SCRUB, numbered, on_usage)
    verdicts = {}
    for v in out.get("verdicts") or []:
        if isinstance(v, dict) and isinstance(v.get("n"), int) and v["n"] not in verdicts:
            verdicts[v["n"]] = v
    kept = []
    for n, item in enumerate(items):
        v = verdicts.get(n)
        if v is None or v.get("verdict") != "keep" or not isinstance(v.get("text"), str):
            reason = v.get("reason") if isinstance(v, dict) else None
            refused[reason if reason in REASONS else "personal"] += 1
            continue
        text = " ".join(v["text"].split())
        reason = local_refusal(text)
        if reason is not None:
            refused[reason] += 1
            continue
        kept.append({"kind": item["kind"], "text": text})
    return kept, refused


async def learn(shared, transcript: list[dict], lang: str, client, on_usage=None) -> int:
    """Distil, scrub and store; returns how many lessons reached the store (new or a bump of a near-duplicate)."""
    drafts = await draft(transcript, lang, client, on_usage)
    kept, refused = await scrub(drafts, client, on_usage)
    stored = 0
    for item in kept:
        if await shared.add_suggestion(lang, item["kind"], item["text"]) is not None:
            stored += 1
    log.info("call lessons: %d drafted, %d refused %s, %d stored", len(drafts), sum(refused.values()), dict(refused), stored)
    return stored


_tasks: set[asyncio.Task] = set()  # distils still running after their call ended; kept so none is collected mid-flight


def pending_tasks() -> set[asyncio.Task]:
    return {t for t in _tasks if not t.done()}


async def _guarded(shared, transcript, lang, client, on_usage, timeout: float) -> None:
    try:
        await asyncio.wait_for(learn(shared, transcript, lang, client, on_usage), timeout)
    except asyncio.TimeoutError:
        log.warning("call lessons timed out after %.0f s", timeout)
    except asyncio.CancelledError:
        raise
    except Exception as e:  # the error's text may quote the call
        log.warning("call lessons failed: %s", type(e).__name__)


def schedule(shared, transcript: list[dict], lang: str, client, on_usage=None, timeout: float = TIMEOUT_S) -> asyncio.Task | None:
    """Fire and forget: returns at once with the background task, or None when there is nothing to do."""
    if shared is None or not getattr(shared, "online", False) or lang not in LANGS or client is None or not transcript:
        return None
    task = asyncio.ensure_future(_guarded(shared, list(transcript), lang, client, on_usage, timeout))
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)
    return task


async def cancel_pending(timeout: float = 2.0) -> None:
    """Server shutdown: what is still running is dropped, never queued."""
    left = pending_tasks()
    for t in left:
        t.cancel()
    if left:
        await asyncio.wait(left, timeout=timeout)
