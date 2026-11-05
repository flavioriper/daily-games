#!/usr/bin/env python3
"""Review the Swarm's pending lessons (the shared layer's `suggestions`): nothing a call distils goes live by itself.

    cd server/bot && NEON_SWARM_URL=... uv run python ../../tools/review_swarm_suggestions.py list [--limit 50]
    ... review_swarm_suggestions.py accept <id> [--text "the lesson, edited"]
    ... review_swarm_suggestions.py reject <id>

`list` shows the pending lessons, most often seen first: id, language, kind, how many calls taught it, the days it was
first and last seen, and the text. `accept` puts a lesson into `knowledge` as `learned` (question, fix, fact) or into
`style` (key learned-<id>); `--text` accepts it edited. `reject` keeps it out for good. A person runs this (or an agent
for them). The DSN comes from the environment only (NEON_SWARM_URL, or SWARM_TEST_DSN with --dev); it is never printed.
"""
import argparse
import asyncio
import os
import re
import sys
from pathlib import Path

BOT = Path(__file__).resolve().parent.parent / "server" / "bot"
sys.path.insert(0, str(BOT))

from shared.distil import local_refusal  # noqa: E402
from shared.store import SharedStore  # noqa: E402

# A lesson came from a call: no control character, line break or direction override of it reaches the terminal.
UNSAFE = re.compile(r"[\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028-\u202e\u2066-\u2069\ufeff]")


def safe(text) -> str:
    return UNSAFE.sub(" ", str(text))


def table(rows: list[dict]) -> str:
    if not rows:
        return "no pending lessons"
    out = [f"{'id':>5}  lang  {'kind':<8}  seen  days                   text"]
    for r in rows:
        days = f"{r['first_day']}..{r['last_day']}" if r["first_day"] != r["last_day"] else str(r["first_day"])
        out.append(f"{r['id']:>5}  {safe(r['lang']):<4}  {safe(r['kind']):<8}  {r['seen']:>4}  {days:<21}  {safe(r['text'])}")
    return "\n".join(out)


async def main() -> int:
    ap = argparse.ArgumentParser(description="Review the Swarm's pending lessons.")
    ap.add_argument("--dev", action="store_true", help="read the DSN from SWARM_TEST_DSN instead of NEON_SWARM_URL")
    sub = ap.add_subparsers(dest="cmd", required=True)
    ls = sub.add_parser("list", help="pending lessons, most often seen first")
    ls.add_argument("--limit", type=int, default=50)
    ok = sub.add_parser("accept", help="into knowledge as learned, or style")
    ok.add_argument("id", type=int)
    ok.add_argument("--text", help="accept it with this text instead")
    no = sub.add_parser("reject", help="keep it out")
    no.add_argument("id", type=int)
    args = ap.parse_args()

    dsn = os.environ.get("SWARM_TEST_DSN" if args.dev else "NEON_SWARM_URL")
    if not dsn:
        print("no DSN in the environment", file=sys.stderr)
        return 1
    store = SharedStore(dsn)
    try:
        if args.cmd == "list":
            rows = await store.pending(args.limit)
            if not rows and store.down:
                print("the shared layer did not answer", file=sys.stderr)
                return 1
            print(table(rows))
            return 0
        if args.cmd == "accept":
            if args.text is not None and not args.text.strip():
                print("--text is empty", file=sys.stderr)
                return 1
            if args.text is not None and (reason := local_refusal(args.text)) is not None:
                print(f"warning: the call-end check would have refused this text ({reason}); accepting it as you wrote it", file=sys.stderr)
            done = await store.accept(args.id, args.text)
        else:
            done = await store.reject(args.id)
        print(f"{args.cmd}ed {args.id}" if done else f"{args.id}: no pending lesson with that id (or the shared layer did not answer)")
        return 0 if done else 1
    finally:
        await store.close()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
