"""The slow half of memory, always after the turn: writing a note, weighing a new fact against old ones, summarising a call. Costs land in the ledger as kind `memory`."""
from pydantic import BaseModel

from studio.brains import openai_units

NOTE = "From what this person just said, write one short third-person note worth keeping, using only what they said. If nothing is worth keeping, return an empty note."
WEIGH = """A new note about a person may repeat, change or add to what is already known.
Choose one action: `add` if it is new, `update` if it replaces an existing fact (give that fact's number in `replaces`), `ignore` if it is already known or not a lasting fact about this person.
`fact` is the fact to store, one short third-person phrase."""
SUMMARY = "Summarise this phone call in two or three sentences for the assistant to read before the next call: what was discussed, what was decided, what is open. Third person."
PROMOTE = "These notes were taken during a call. Return only those that are lasting facts about the person, as short third-person phrases. An empty list is fine."
SCRUB = "Rewrite this call summary without the stated fact or anything that reveals it. Change nothing else."


class Note(BaseModel):
    note: str


class Weighed(BaseModel):
    action: str
    replaces: int | None = None
    fact: str = ""


class Summary(BaseModel):
    summary: str


class Promoted(BaseModel):
    facts: list[str]


async def ask(client, brain_key: str, system: str, user: str, schema, ledger, ids: dict):
    provider, model = brain_key.split(":", 1)
    if provider == "openai":
        r = await client.chat.completions.parse(model=model, max_completion_tokens=400, response_format=schema, messages=[{"role": "system", "content": system}, {"role": "user", "content": user}])
        if ledger:
            ledger.record(kind="memory", provider=provider, model=model, source="sdk", units=openai_units(r.usage), **ids)
        return r.choices[0].message.parsed
    r = await client.messages.parse(model=model, max_tokens=400, system=system, output_format=schema, thinking={"type": "disabled"}, messages=[{"role": "user", "content": user}])
    if ledger:
        ledger.record(kind="memory", provider="anthropic", model=model, source="sdk", units={"prompt_tokens": r.usage.input_tokens, "completion_tokens": r.usage.output_tokens, "gross": False}, **ids)
    return r.parsed_output


async def write_note(text: str, client, brain: str, ledger, ids: dict) -> str:
    parsed = await ask(client, brain, NOTE, text, Note, ledger, ids)
    return parsed.note.strip() if parsed else ""


async def weigh(note: str, similar: list[str], client, brain: str, ledger, ids: dict) -> Weighed:
    known = "\n".join(f"{i}: {f}" for i, f in enumerate(similar)) or "nothing yet"
    parsed = await ask(client, brain, WEIGH, f"Known:\n{known}\n\nNew note: {note}", Weighed, ledger, ids)
    if parsed is None or parsed.action not in ("add", "update", "ignore"):
        return Weighed(action="ignore")
    if parsed.action == "update" and (parsed.replaces is None or not 0 <= parsed.replaces < len(similar)):
        return Weighed(action="add", fact=parsed.fact or note)
    return Weighed(action=parsed.action, replaces=parsed.replaces, fact=parsed.fact or note)


async def summarise(lines: str, client, brain: str, ledger, ids: dict) -> str:
    parsed = await ask(client, brain, SUMMARY, lines, Summary, ledger, ids)
    return parsed.summary.strip() if parsed else ""


async def lasting(notes: list[str], client, brain: str, ledger, ids: dict) -> list[str]:
    parsed = await ask(client, brain, PROMOTE, "\n".join(notes), Promoted, ledger, ids)
    return parsed.facts if parsed else []


async def scrub(summary: str, fact: str, client, brain: str, ledger, ids: dict) -> str:
    parsed = await ask(client, brain, SCRUB, f"Fact to remove: {fact}\n\nSummary: {summary}", Summary, ledger, ids)
    return parsed.summary.strip() if parsed else summary
