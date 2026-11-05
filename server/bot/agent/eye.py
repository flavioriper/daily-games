"""The swarm's eye: gpt-6.1-terra draws and looks for the voice.

Copied from tools/swarm_eye.py (measured 2026-11-05, spec "Four more screen
tools"): gpt-6-luna, the voice, misreads the swarm's drawings (2 of 6);
gpt-6.1-terra read 18 of 18 in about two seconds. So the voice keeps talking
and hands terra the two jobs that need eyes:

- rows_for(subject, ...)  the draw tool's `subject`: terra writes the thing as
  rows shaped for a swarm of dots.
- judge(jpg, meant)       the see tool: terra looks at the phone's
  snapshot(384) and says what it reads as, whether that is what was meant,
  and what to change.

Stdlib only; the key is OPENAI_API_KEY. Nothing it sees or draws is written
anywhere. `Eye(ask=...)` takes the model call, so tests never dial out.
"""
import base64
import json
import os
import time
import urllib.request
from typing import Callable

MODEL = "gpt-6.1-terra"
# Low reasoning: writing a drawing takes about 5 s instead of 8 to 15 at the
# default, and the eye catches what it gets wrong (measured 2026-11-05).
EFFORT = "low"
SIDE = (8, 32)  # rows_for asks for 12 to 20 a side; the checks allow this
BRIGHT, DIM = "#", "o"
PALETTE = {BRIGHT: "#ffffff", DIM: "#7a7a7a"}  # brightness only: the swarm keeps its tone
FACE = "a face made of glowing dots"  # what the screen should show when nothing was drawn
WRITE_TIMEOUT = 13.0  # a try; the draw tool waits 30 s for two
JUDGE_TIMEOUT = 8.0  # the see tool waits 12 s: 2 for the phone, this for the eye

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

LOOK = """This is a phone screen. On it, a swarm of glowing dots has just
drawn something. Ignore the faint stray dots, the buttons and the small text.

Answer with JSON only: {{"reads_as": "<what a person would say it is, in a
few words>"}}"""

Ask = Callable[..., tuple[dict, dict]]  # (content, timeout=seconds) -> (answer, usage)


def _key() -> str:
    k = os.environ.get("OPENAI_API_KEY", "").strip()
    if not k:
        raise RuntimeError("OPENAI_API_KEY is not set")
    return k


def openai_ask(content: list, timeout: float = 60.0) -> tuple[dict, dict]:
    """One JSON answer from terra for a user message of `content` parts, and its usage."""
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
    """Empty when rows are a drawing terra may hand down; else why not."""
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


class Eye:
    """Blocking calls: run them off the event loop (asyncio.to_thread)."""

    def __init__(self, ask: Ask = openai_ask):
        self.ask = ask

    def rows_for(self, subject: str, before: list | None = None, fix: str = "", tries: int = 2) -> tuple[dict, dict]:
        """A drawing of `subject` as the draw tool's command ({rows, palette}), and the usage of the last try. `before` and `fix` are the last try and what the eye said was wrong with it."""
        feedback = ""
        if before:
            feedback = "\nYour last try, which did not read:\n" + "\n".join(before) + f"\nWhat to change: {fix}\n"
        last, usage = "", {}
        for _ in range(tries):
            got, usage = self.ask([{"type": "text", "text": WRITE.format(subject=subject, feedback=feedback + (f"\nYour answer was refused: {last}.\n" if last else ""))}], timeout=WRITE_TIMEOUT)
            rows = [str(r) for r in got.get("rows", [])] if isinstance(got.get("rows"), list) else got.get("rows")
            last = check_rows(rows)
            if not last:
                return {"rows": rows, "palette": dict(PALETTE)}, usage
        raise ValueError(f"terra could not draw {subject}: {last}")

    def judge(self, jpg: bytes, meant: str | None = None) -> tuple[dict, dict]:
        """What the snapshot reads as: {reads_as, ok, fix}, and the usage. `meant` None: nothing is drawn, so the face is what should show; "" : an open look (today's picture, whose name the server does not know), ok None for the voice to compare."""
        b64 = base64.b64encode(jpg).decode()
        image = {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64, "detail": "high"}}
        if meant == "":
            got, usage = self.ask([{"type": "text", "text": LOOK}, image], timeout=JUDGE_TIMEOUT)
            return {"reads_as": str(got.get("reads_as", "")), "ok": None, "fix": ""}, usage
        meant = meant or FACE
        got, usage = self.ask([{"type": "text", "text": JUDGE.format(meant=meant)}, image], timeout=JUDGE_TIMEOUT)
        return {"reads_as": str(got.get("reads_as", "")), "ok": bool(got.get("ok", False)), "fix": str(got.get("fix", ""))}, usage
