"""The swarm's eye: gpt-6.1-terra draws and looks for the voice.

Measured 2026-11-05 (docs/superpowers/specs/2026-11-04-peeplet-bot-design.md,
"Four more screen tools"): gpt-6-luna, the voice, misreads the swarm's
drawings (2 of 6); gpt-6.1-terra read 18 of 18 in about two seconds. So the
voice keeps talking and hands terra the two jobs that need eyes:

- rows_for(subject, ...)  terra writes a drawing of a thing as rows (the
  draw tool's `rows`), shaped for a swarm of dots: a bold silhouette whose
  shading is density, features as holes or dim pixels.
- judge(jpg, meant)       terra looks at the phone's snapshot(384) and says
  what it reads as, whether that is what was meant, and what to change.

This file is the server's copy-to-be: the bot fork (server/bot, plan Task 7)
imports it as agent/eye.py. Until then tools/swarm_draw_loop.py runs it
against the real swarm on this Mac. Stdlib only; the key is OPENAI_API_KEY
or ~/.config/openai/api_key. Nothing it sees or draws is written anywhere.
"""
import base64
import json
import os
import time
import urllib.error
import urllib.request

MODEL = "gpt-6.1-terra"
# Low reasoning: writing a drawing takes about 5 s instead of 8 to 15 at the
# default, and the eye catches what it gets wrong (measured 2026-11-05).
EFFORT = "low"
SIDE = (8, 32)  # rows_for asks for 12 to 20 a side; the checks allow this
BRIGHT, DIM = "#", "o"
PALETTE = {BRIGHT: "#ffffff", DIM: "#7a7a7a"}  # brightness only: the swarm keeps its tone

WRITE = """You draw for a swarm of glowing dots on a dark phone screen. Your
drawing is a grid; the dots crowd into its pixels, more into bright pixels
and outlines, fewer into dim ones, all in one colour. So only the shape and
the light and dark inside it can show.

Draw: {subject}

Rules:
- 12 to 20 pixels a side, every row exactly the same length.
- "." empty, "#" bright, "o" dim (use dim for inner lines and features that
  must show inside a shape, or cut them out with "." holes).
- One thing, centred, filling most of the grid, in its most recognisable
  view (a duck from the side, a sun as a disc with rays). No ground, no
  frame, no text.
- Bold: no lines one pixel thin unless they stand alone against empty.
{feedback}
Answer with JSON only: {{"rows": ["...", "..."]}}"""

JUDGE = """This is a phone screen. On it, a swarm of glowing dots has just
drawn something. Ignore the faint stray dots, the buttons and the small text.
It was meant to be: {meant}.

Answer with JSON only: {{"reads_as": "<what a person would say it is, in a
few words>", "ok": <true if a person would see {meant} without being told>,
"fix": "<if not ok: what to change in the shape, in one sentence; else empty>"}}"""


def _key() -> str:
    k = os.environ.get("OPENAI_API_KEY", "").strip()
    if not k:
        with open(os.path.expanduser("~/.config/openai/api_key")) as f:
            k = f.read().strip()
    return k


def _ask(content: list, timeout: float = 60.0) -> tuple[dict, dict]:
    body = {"model": MODEL, "messages": [{"role": "user", "content": content}],
            "response_format": {"type": "json_object"}, "reasoning_effort": EFFORT}
    req = urllib.request.Request("https://api.openai.com/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + _key(), "Content-Type": "application/json"})
    t = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.load(r)
    usage = dict(out.get("usage", {}), seconds=round(time.time() - t, 2))
    return json.loads(out["choices"][0]["message"]["content"]), usage


def check_rows(rows) -> str:
    """Empty when rows are a drawing the phone will take; else why not (the
    server's check before a `draw` goes down the socket)."""
    if not isinstance(rows, list) or not rows or not all(isinstance(r, str) for r in rows):
        return "rows must be a list of strings"
    w = len(rows[0])
    if any(len(r) != w for r in rows):
        return "every row must be the same length"
    if not (SIDE[0] <= w <= SIDE[1] and SIDE[0] <= len(rows) <= SIDE[1]):
        return f"a drawing is {SIDE[0]} to {SIDE[1]} pixels a side"
    if set("".join(rows)) - {".", BRIGHT, DIM}:
        return 'only ".", "#" and "o"'
    if "".join(rows).count(".") == w * len(rows):
        return "the drawing is empty"
    return ""


def rows_for(subject: str, before: list | None = None, fix: str = "", tries: int = 2) -> tuple[dict, dict]:
    """A drawing of `subject` as the draw tool's command ({rows, palette}),
    and the call's usage. `before` and `fix` are the last try and what the
    eye said was wrong with it."""
    feedback = ""
    if before:
        feedback = "\nYour last try, which did not read:\n" + "\n".join(before) + f"\nWhat to change: {fix}\n"
    last = ""
    for _ in range(tries):
        got, usage = _ask([{"type": "text", "text": WRITE.format(subject=subject, feedback=feedback + (f"\nYour answer was refused: {last}.\n" if last else ""))}])
        rows = [str(r) for r in got.get("rows", [])] if isinstance(got.get("rows"), list) else got.get("rows")
        last = check_rows(rows)
        if not last:
            return {"rows": rows, "palette": PALETTE}, usage
    raise ValueError(f"terra could not draw {subject}: {last}")


def judge(jpg: bytes, meant: str) -> tuple[dict, dict]:
    """What the snapshot reads as: {reads_as, ok, fix}, and the usage."""
    b64 = base64.b64encode(jpg).decode()
    got, usage = _ask([{"type": "text", "text": JUDGE.format(meant=meant)},
                       {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64, "detail": "high"}}])
    return {"reads_as": str(got.get("reads_as", "")), "ok": bool(got.get("ok", False)), "fix": str(got.get("fix", ""))}, usage
