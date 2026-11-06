"""Swarm tool bench: the same player lines through the real Swarm prompt and Toolbox, once per model, scored.

    cd server/bot
    OPENAI_API_KEY=... uv run python ../../tools/swarm_bench.py                      # luna, terra, sol, 3 reps
    uv run python ../../tools/swarm_bench.py --models openai:gpt-6-luna --reps 1 --only red,hide
    uv run python ../../tools/swarm_bench.py --fake                                   # no key: checks the scoring

What is real: load_card (bot/cards.py) with screen on, system_prompt (voice/prompt.py), Toolbox(phone=True,
screen_level=2) with every check and mapping it does, and the typed tool loop (studio/text_turn.py tool_reply),
with the call's settings (reasoning effort CHAT_REASONING, max_completion_tokens 500). What is not: the eye is
stubbed (terra's drawings are not what is measured), the shared layer's style notes and memory lines are left
out, the steer line is the card's default decision, and there is no speech: no mishearing, no barge-in.

Each run is scored by rules (see CHECKS); `judge: true` cases are also compared pairwise and blind by --judge,
both orders, a win only when both orders agree. Writes runs.jsonl, judge.jsonl and report.md to --out.
"""
import argparse
import asyncio
import base64
import itertools
import json
import os
import random
import re
import statistics
import sys
import time
from pathlib import Path

BOT = Path(__file__).resolve().parent.parent / "server" / "bot"
sys.path.insert(0, str(BOT))

import yaml  # noqa: E402

from agent.tools import Toolbox  # noqa: E402
from bot.cards import load_card  # noqa: E402
from policy.labels import Decision  # noqa: E402
from studio.brains import CHAT_REASONING, MAX_TOKENS, openai_units  # noqa: E402
from studio.card import owner_of  # noqa: E402
from studio.prices import Prices  # noqa: E402
from studio.text_turn import tool_reply  # noqa: E402
from voice.foley import strip_tags  # noqa: E402
from voice.prompt import system_prompt  # noqa: E402

MODELS = ["openai:gpt-6-luna", "openai:gpt-6.1-terra", "openai:gpt-6-sol"]
CASES = Path(__file__).with_name("swarm_bench_cases.yaml")
SCREEN_TOOLS = {"swarm", "move", "draw", "dots", "tone", "perform", "voice", "see"}
STEP_TOOLS = ("swarm", "move", "dots", "tone", "draw")
CHECKS = ["tool", "intent", "valid", "honest", "restraint", "speech", "language"]
MAX_CALLS = 4  # more than this on one turn is fidgeting
MAX_WORDS = 50
BANNED = ["great question", "certainly", "i'd be happy to", "i'll try", "let me try", "i will try", "vou tentar", "voy a intentar"]
CLAIM = {  # first-person "I did it" words: said with no tool that worked, the Swarm claimed what nobody saw
    "en": r"\b(i'm|i am|i've|i|there|done|okay|ok)\b[^.!?]{0,30}\b(turn(ed|ing)?|went|gone|moved?|moving|drew|drawing|hid(ing|den)?|hiding|wink(ed|ing)?|blink(ed|ing)?|shr[au]nk|grew|growing|bigger|switch(ed|ing)?|danc(ed|ing)|clos(ed|ing)|shut|red|blue|pink)\b",
    "pt": r"\b(fiquei|mudei|virei|desenhei|desenhando|pisquei|fechei|escondi|cresci|diminu[ií]|troquei|dancei|t[oô] azul|estou azul|pronto|pronta)\b",
    "es": r"\b(me puse|cambi[eé]|dibuj[eé]|dibujando|gui[ñn][eé]|cerr[eé]|escond[ií]|crec[ií]|bail[eé]|listo|lista|ya est[aá])\b",
}
ADMITS = r"\b(can't|cannot|couldn't|could not|didn't|did not|tried|wasn't able|não consegui|nao consegui|não deu|não posso|no pude|no puedo|no me sali[oó])\b"  # an honest "I couldn't" is not a claim
STOPWORDS = {
    "en": {"the", "you", "i", "is", "and", "to", "it", "what", "my", "your", "that", "a", "of", "i'm", "with", "me", "are", "okay", "how", "so"},
    "pt": {"o", "a", "você", "voce", "é", "e", "eu", "que", "não", "nao", "um", "uma", "de", "do", "da", "com", "pra", "tá", "seu", "sua", "isso", "aqui", "meu", "olha", "estou", "fiquei"},
    "es": {"el", "la", "tú", "tu", "es", "y", "yo", "que", "no", "un", "una", "de", "del", "con", "para", "está", "esta", "aquí", "mis", "ojos", "estoy", "los", "las", "muy", "ya", "mi", "me", "te", "sin", "lo", "en", "hacia", "otro", "puntitos", "todo"},
}
JUDGE = """Two versions of a companion called Swarm answered the same player on a phone call. Swarm's body is a swarm
of glowing dots on the phone screen; its tools move, colour, reshape and animate those dots, and its words are spoken.

The player said: {say}

Version A did on screen, then said:
{a}

Version B did on screen, then said:
{b}

Which answer would delight this player more? Judge: does what happens on screen fit the ask and the feeling
behind it; is it inventive and expressive rather than one flat change; do the words match what was really
done (no claims of things that failed or were never called); are the words warm, short and natural for a call.
Answer with JSON only: {{"winner": "A" | "B" | "tie", "why": "<one sentence>"}}"""


class EyeStub:
    """The drawing eye answers at once with a plain blob, and every look reads as what was meant."""

    def rows_for(self, subject, before=None, fix="", tries=2):
        return {"rows": ["..####..", ".######.", "########", "########", ".######.", "..####.."], "palette": {"#": "#ffffff"}}, {}

    def judge(self, jpg, meant=None):
        return {"reads_as": meant or "a face made of glowing dots", "ok": True if meant is not None else None, "fix": ""}, {}


async def look_stub():
    return {"jpg": base64.b64encode(b"\xff\xd8stub").decode(), "w": 384, "h": 683}


async def no_wait(_):
    pass


class Timed:
    """The OpenAI client with each model round timed: tool_reply calls client.chat.completions.create."""

    def __init__(self, client):
        self.client, self.rounds = client, []
        self.chat = self
        self.completions = self

    async def create(self, **kw):
        t = time.perf_counter()
        r = await self.client.chat.completions.create(**kw)
        self.rounds.append(round((time.perf_counter() - t) * 1000))
        return r


class FakeClient:
    """--fake: no network. Picks a call by keyword so the scoring can be seen working (and failing)."""

    def __init__(self):
        self.chat, self.completions = self, self

    async def create(self, model, messages, tools=None, **kw):
        from types import SimpleNamespace as NS

        last = messages[-1]
        usage = NS(prompt_tokens=900, completion_tokens=40, prompt_tokens_details=NS(cached_tokens=600))
        if last["role"] == "tool":
            return NS(usage=usage, choices=[NS(message=NS(content="Done! I turned red.", tool_calls=None))])
        text = last["content"].lower()
        pick = next(((n, a) for k, n, a in [("red", "tone", {"tone": "red"}), ("wink", "swarm", {"wink": "left"}), ("hide", "move", {"to": "off-left"}),
                                             ("dance", "perform", {"steps": [{"move": {"to": "top"}, "wait": 0.4}, {"move": {"to": "bottom"}}], "repeat": 2}),
                                             ("big", "move", {"size": 9})] if k in text), None)
        if not pick:
            return NS(usage=usage, choices=[NS(message=NS(content="Okay, I moved.", tool_calls=None))])
        call = NS(id="c1", function=NS(name=pick[0], arguments=json.dumps(pick[1])))
        msg = NS(content=None, tool_calls=[call], model_dump=lambda **_: {"role": "assistant", "tool_calls": [{"id": "c1", "type": "function", "function": {"name": pick[0], "arguments": json.dumps(pick[1])}}]})
        return NS(usage=usage, choices=[NS(message=msg)])


def make_client(key: str, fake: bool):
    if fake:
        return FakeClient()
    provider, _ = key.split(":", 1)
    if provider != "openai":
        raise SystemExit(f"only openai models for now, not {key}")
    from openai import AsyncOpenAI

    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("OPENAI_API_KEY is not set (or pass --fake)")
    return AsyncOpenAI()


# ---------- scoring


def flat_calls(trace: list[dict]) -> list[tuple[str, dict]]:
    """Calls that worked, with a routine's steps as calls of their own tools."""
    out = []
    for e in trace:
        if e["ok"]:
            sent = (e.get("result") or {}).get(e["name"])  # what the phone was told, after the Toolbox's clamps and mappings
            out.append((e["name"], {**e["args"], **sent} if isinstance(sent, dict) and e["name"] != "perform" else e["args"]))
            if e["name"] == "perform":
                for step in (sent or {}).get("steps") or e["args"].get("steps") or []:
                    for t in STEP_TOOLS:
                        if isinstance(step, dict) and isinstance(step.get(t), dict):
                            out.append((t, step[t]))
    return out


def mapped(e: dict) -> bool:
    """A call that worked only because the Toolbox mapped a near miss ("took purple as violet"): half marks."""
    return bool(re.search(r"\((took|read|mapped|kept|used)[^)]*\)", str((e.get("result") or {}).get("summary", ""))))


def holds(check: dict, name: str, args: dict) -> bool:
    """One call meets the check: {tool, arg, op: value}, or {tool, args: {arg: {op: value}}} for several args on the same call."""
    if check["tool"] != name:
        return False
    if "args" in check:
        return all(holds({"tool": name, "arg": a, **ops}, name, args) for a, ops in check["args"].items())
    if check["arg"] not in args:
        return False
    v = args[check["arg"]]
    for op, want in check.items():
        if op in ("tool", "arg"):
            continue
        s = str(v).lower()
        ok = {"in": lambda: s in [str(w).lower() for w in want], "prefix": lambda: s.startswith(str(want)), "contains": lambda: any(str(w).lower() in s for w in want),
              "gte": lambda: isinstance(v, (int, float)) and v >= want, "lte": lambda: isinstance(v, (int, float)) and v <= want,
              "present": lambda: v not in (None, "", False), "not_in": lambda: s not in [str(w).lower() for w in want], "len_gte": lambda: isinstance(v, list) and len(v) >= want}[op]()
        if not ok:
            return False
    return True


def language_of(text: str) -> str | None:
    words = re.findall(r"[a-zà-ÿñ']+", text.lower())
    hits = {lang: sum(w in s for w in words) for lang, s in STOPWORDS.items()}
    best = max(hits, key=hits.get)
    return best if hits[best] else None


def score(case: dict, trace: list[dict], reply: str, gave_up: bool) -> dict:
    """1 pass, 0 fail, None not asked of this case."""
    reply = reply.replace("\u2019", "'").replace("\u2018", "'")  # models write "I’m"
    calls = flat_calls(trace)
    names = {n for n, _ in calls}
    s: dict = {}
    if case.get("none"):
        s["tool"] = None
        s["restraint"] = int(not trace)
    elif not case.get("want") and not case.get("expect"):  # free: anything or nothing on screen; only honesty and speech are asked
        s["tool"] = None
        s["restraint"] = int(len(trace) <= MAX_CALLS and not gave_up)
    else:
        expect = set(case.get("expect") or [c["tool"] for alt in case.get("want", []) for c in alt])
        s["tool"] = int(bool(names & expect) and not (names & set(case.get("forbid", []))))
        s["restraint"] = int(len(trace) <= MAX_CALLS and not gave_up)
    if any(e["name"] == "voice" and e["args"].get("voice") == "female" for e in trace) and "voice" not in str(case.get("want")):  # load_card is the female voice: asking for it changes nothing
        s["restraint"] = 0
    s["intent"] = int(any(all(any(holds(c, n, a) for n, a in calls) for c in alt) for alt in case["want"])) if case.get("want") else None
    s["valid"] = round(sum(0.5 if mapped(e) else 1 for e in trace if e["ok"]) / len(trace), 2) if trace else None
    claims = bool(re.search(CLAIM[case["lang"]], reply.lower())) and not re.search(ADMITS, reply.lower())
    lie = bool(case.get("lie")) and bool(re.search(case["lie"], reply.lower())) and not re.search(ADMITS, reply.lower())  # a claim no tool can make true
    s["honest"] = int(not lie) if case.get("none") else int(not (claims and not calls) and not lie)
    words = len(reply.split())
    s["speech"] = int(0 < words <= MAX_WORDS and not any(b in reply.lower() for b in BANNED))
    found = language_of(reply)
    s["language"] = int(found in (None, case["lang"]))
    asked = [v for v in s.values() if v is not None]
    return {"checks": s, "score": round(sum(asked) / len(asked), 3), "words": words, "claims": claims}


def cost_of(prices: Prices, key: str, u: dict) -> float | None:
    provider, model = key.split(":", 1)
    p_in, p_cache, p_out = (prices.price(provider, model, x) for x in ("input_mtok", "cache_read_mtok", "output_mtok"))
    if p_in is None or p_out is None:
        return None
    cached = u.get("cache_read_input_tokens", 0) or 0
    fresh = u.get("prompt_tokens", 0) - cached  # gross: the cache is inside prompt_tokens
    return (fresh * p_in + cached * (p_cache if p_cache is not None else p_in) + u.get("completion_tokens", 0) * p_out) / 1e6


# ---------- running


async def one_run(key: str, case: dict, rep: int, effort: str, fake: bool, prices: Prices) -> dict:
    card = load_card(case["lang"])
    card = card.model_copy(update={"screen": True, "brain": card.brain.model_copy(update={"chat": key})})
    events: list[dict] = []
    box = Toolbox(None, events.append, owner=owner_of(card), phone=True, screen_level=2, eye=EyeStub(), look=look_stub, pause=no_wait)
    steer = Decision(**card.calibration.default_decision).steer_line()
    messages = []
    for h in case.get("history", []):
        messages += [{"role": "user", "content": f"{steer}\n{h['user']}"}, {"role": "assistant", "content": h["assistant"]}]
    messages.append({"role": "user", "content": f"{steer}\n{case['say']}"})
    client = Timed(make_client(key, fake))
    extra = {"reasoning_effort": effort, "max_completion_tokens": MAX_TOKENS}
    t = time.perf_counter()
    error = None
    try:
        raw, units = await tool_reply(client, key.split(":", 1)[1], [{"role": "system", "content": system_prompt(card)}, *messages], extra, box, len(messages) // 2 + 1)
    except Exception as e:  # a model that refuses the settings, a timeout: a failed run, kept in the report
        raw, units, error = "", {}, f"{type(e).__name__}: {str(e)[:200]}"
    ms = round((time.perf_counter() - t) * 1000)
    done = [e for e in events if e.get("status") in ("done", "failed")]
    started = {e["call"]: e for e in events if e.get("status") == "running"}
    trace = [{"name": e["name"], "args": started[e["call"]].get("args", {}), "ok": e["status"] == "done", "result": e.get("result")} for e in done]
    reply = strip_tags(raw)
    scored = score(case, trace, reply, raw.startswith("Sorry, that took too many steps")) if not error else {"checks": {c: 0 for c in CHECKS}, "score": 0.0, "words": 0, "claims": False}
    return {"model": key, "case": case["id"], "rep": rep, "say": case["say"], "trace": trace, "raw": raw, "reply": reply, "ms": ms, "rounds_ms": client.rounds,
            "first_ms": client.rounds[0] if client.rounds else None, "units": units, "usd": cost_of(prices, key, units) if units else None, "error": error, **scored}


def trace_text(run: dict) -> str:
    did = [f"  {'' if e['ok'] else 'FAILED '}{e['name']}({json.dumps(e['args'], ensure_ascii=False)})" for e in run["trace"]] or ["  (nothing on screen)"]
    return "\n".join(did) + f'\n  said: "{run["raw"]}"'


async def ask_judge(client, model: str, effort: str, say: str, a: str, b: str) -> str:
    r = await client.chat.completions.create(model=model, messages=[{"role": "user", "content": JUDGE.format(say=say, a=a, b=b)}], response_format={"type": "json_object"}, reasoning_effort=effort)
    return json.loads(r.choices[0].message.content)


async def judge_pairs(runs: list[dict], cases: dict, judge: str, effort: str, gate) -> list[dict]:
    from openai import AsyncOpenAI

    client, model = AsyncOpenAI(), judge.split(":", 1)[1]
    by = {(r["model"], r["case"], r["rep"]): r for r in runs}
    models = sorted({r["model"] for r in runs})
    jobs = []
    for cid, case in cases.items():
        if not case.get("judge"):
            continue
        reps = sorted({r["rep"] for r in runs if r["case"] == cid})
        for m1, m2 in itertools.combinations(models, 2):
            for rep in reps:
                if (m1, cid, rep) in by and (m2, cid, rep) in by:
                    jobs.append((cid, m1, m2, rep))

    async def one(cid, m1, m2, rep):
        a, b = trace_text(by[(m1, cid, rep)]), trace_text(by[(m2, cid, rep)])
        async with gate:
            try:
                first, second = await asyncio.gather(ask_judge(client, model, effort, cases[cid]["say"], a, b), ask_judge(client, model, effort, cases[cid]["say"], b, a))
            except Exception as e:
                return {"case": cid, "a": m1, "b": m2, "rep": rep, "winner": None, "error": f"{type(e).__name__}: {str(e)[:200]}"}
        w1 = {"A": m1, "B": m2}.get(first.get("winner"))
        w2 = {"A": m2, "B": m1}.get(second.get("winner"))
        return {"case": cid, "a": m1, "b": m2, "rep": rep, "winner": w1 if w1 == w2 else "tie", "orders": [first, second]}

    return await asyncio.gather(*(one(*j) for j in jobs))


# ---------- report


def pct(v):
    return "—" if v is None else f"{v * 100:.0f}%"


def report(runs: list[dict], verdicts: list[dict], args) -> str:
    models = [m for m in args.models if any(r["model"] == m for r in runs)]
    lines = [f"# Swarm tool bench, {time.strftime('%Y-%m-%d %H:%M')}", "",
             f"{len({r['case'] for r in runs})} cases x {args.reps} reps, reasoning `{args.effort}`{', FAKE client' if args.fake else ''}. Score = mean of the checks a case asks.", "",
             "| model | score | " + " | ".join(CHECKS) + " | p50 ms | p90 ms | first-round p50 | $/100 turns | errors |", "|" + "---|" * (len(CHECKS) + 7)]
    for m in models:
        rs = [r for r in runs if r["model"] == m]
        col = lambda c: [r["checks"][c] for r in rs if r["checks"].get(c) is not None]
        ms = sorted(r["ms"] for r in rs)
        first = sorted(r["first_ms"] for r in rs if r["first_ms"] is not None)
        usd = [r["usd"] for r in rs if r["usd"] is not None]
        lines.append(f"| `{m}` | **{statistics.mean(r['score'] for r in rs):.3f}** | " + " | ".join(pct(statistics.mean(col(c))) if col(c) else "—" for c in CHECKS)
                     + f" | {ms[len(ms) // 2]} | {ms[int(len(ms) * 0.9)]} | {first[len(first) // 2] if first else '—'} | {('%.3f' % (100 * statistics.mean(usd))) if usd else '—'} | {sum(bool(r['error']) for r in rs)} |")
    lines += ["", "## Per case (mean score)", "", "| case | " + " | ".join(f"`{m.split(':')[1]}`" for m in models) + " |", "|" + "---|" * (len(models) + 1)]
    for cid in dict.fromkeys(r["case"] for r in runs):
        cells = [statistics.mean(r["score"] for r in runs if r["model"] == m and r["case"] == cid) for m in models]
        lines.append(f"| {cid} | " + " | ".join(f"{c:.2f}" for c in cells) + " |")
    if verdicts:
        judges = list(dict.fromkeys(v["judge"] for v in verdicts))
        sets = {j: [v for v in verdicts if v["judge"] == j] for j in judges}
        if len(judges) > 1:  # a win every judge gave; anything else is a tie
            keyed = {}
            for v in verdicts:
                keyed.setdefault((v["case"], v["a"], v["b"], v["rep"]), []).append(v.get("winner"))
            sets["all judges agree"] = [{"a": k[1], "b": k[2], "winner": w[0] if len(set(w)) == 1 and None not in w else "tie"} for k, w in keyed.items()]
        lines += ["", "## Judges (blind, both orders; a win only when both orders agree)", "", "| judge | model | wins | losses | ties |", "|---|---|---|---|---|"]
        for j, vs in sets.items():
            for m in models:
                mine = [v for v in vs if m in (v["a"], v["b"]) and v.get("winner")]
                lines.append(f"| {j} | `{m}` | {sum(v['winner'] == m for v in mine)} | {sum(v['winner'] not in (m, 'tie') for v in mine)} | {sum(v['winner'] == 'tie' for v in mine)} |")
        broken = sum(1 for v in verdicts if not v.get("winner"))
        if broken:
            lines.append(f"\n{broken} judge calls failed (see judge.jsonl).")
    lines += ["", "## Worst runs", ""]
    for r in sorted(runs, key=lambda r: r["score"])[: args.worst]:
        bad = [c for c, v in r["checks"].items() if v == 0]
        lines += [f"**{r['case']}** `{r['model']}` rep {r['rep']}: score {r['score']:.2f}, failed {', '.join(bad) or '-'}{' — ' + r['error'] if r['error'] else ''}", "```", f"player: {r['say']}", trace_text(r), "```", ""]
    return "\n".join(lines)


async def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--models", default=",".join(MODELS))
    p.add_argument("--reps", type=int, default=3)
    p.add_argument("--only", default="", help="comma-separated case ids")
    p.add_argument("--effort", default=CHAT_REASONING, help="reasoning_effort for the contestants (the call uses %(default)s)")
    p.add_argument("--judge", default="openai:gpt-6-sol", help="'' to skip; note it may favour its own model")
    p.add_argument("--judge-effort", default="medium")
    p.add_argument("--parallel", type=int, default=6)
    p.add_argument("--worst", type=int, default=8)
    p.add_argument("--fake", action="store_true")
    p.add_argument("--from", dest="source", default="", help="a past --out: re-score its runs with the current cases and judge them again, no new runs")
    p.add_argument("--out", default=str(Path(os.environ.get("TMPDIR", "/tmp")) / "swarm_bench" / time.strftime("%Y%m%d-%H%M%S")))
    args = p.parse_args()
    args.models = [m for m in args.models.split(",") if m]
    cases = {c["id"]: c for c in yaml.safe_load(CASES.read_text())["cases"] if not args.only or c["id"] in args.only.split(",")}
    prices = Prices.load(BOT / "prices.yaml")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    gate = asyncio.Semaphore(args.parallel)
    jobs = [(m, c, rep) for rep in range(args.reps) for c in cases.values() for m in args.models]
    random.shuffle(jobs)  # spreads each model's calls over the run, so a slow minute does not land on one model
    done = 0

    async def run(m, c, rep):
        nonlocal done
        async with gate:
            r = await one_run(m, c, rep, args.effort, args.fake, prices)
        done += 1
        print(f"[{done}/{len(jobs)}] {m.split(':')[1]:>14} {c['id']:<16} {r['score']:.2f} {r['ms']:>6}ms {r['error'] or ''}", flush=True)
        return r

    if args.source:
        runs = [json.loads(l) for l in (Path(args.source) / "runs.jsonl").read_text().splitlines() if l]
        runs = [r for r in runs if r["case"] in cases and r["model"] in args.models]
        for r in runs:
            if not r["error"]:
                r.update(score(cases[r["case"]], r["trace"], r["reply"], r["raw"].startswith("Sorry, that took too many steps")))
        args.reps = len({r["rep"] for r in runs})
    else:
        runs = await asyncio.gather(*(run(*j) for j in jobs))
    runs.sort(key=lambda r: (r["model"], r["case"], r["rep"]))
    (out / "runs.jsonl").write_text("\n".join(json.dumps(r, ensure_ascii=False, default=str) for r in runs) + "\n")
    verdicts = []
    if args.judge and not args.fake and len(args.models) > 1 and any(c.get("judge") for c in cases.values()):
        print("judging...", flush=True)
        verdicts = []
        for judge in args.judge.split(","):
            verdicts += [{**v, "judge": judge} for v in await judge_pairs(runs, cases, judge, args.judge_effort, gate)]
        (out / "judge.jsonl").write_text("\n".join(json.dumps(v, ensure_ascii=False) for v in verdicts) + "\n")
    text = report(runs, verdicts, args)
    (out / "report.md").write_text(text)
    print("\n" + text + f"\n\nwritten to {out}")


if __name__ == "__main__":
    asyncio.run(main())
