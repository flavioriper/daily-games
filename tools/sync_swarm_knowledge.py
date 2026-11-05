#!/usr/bin/env python3
"""Sync the Swarm's curated knowledge (server/bot/knowledge/<lang>/<topic>.md) into the shared layer's database.

    cd server/bot && NEON_SWARM_URL=... uv run python ../../tools/sync_swarm_knowledge.py [--schema] [--dry-run]

One file a topic: `# Title` then paragraphs, each paragraph one `knowledge` row (source 'curated'). A sync replaces the
curated rows of every file wholesale, deletes those of files that are gone, and leaves `learned` rows alone. The
DSN comes from the environment only (NEON_SWARM_URL, or SWARM_TEST_DSN with --dev); it is never printed.
"""
import argparse
import asyncio
import os
import sys
from pathlib import Path

BOT = Path(__file__).resolve().parent.parent / "server" / "bot"
sys.path.insert(0, str(BOT))

from shared.store import SharedStore, parse_markdown  # noqa: E402

LANGS = ("en", "pt", "es")


def read_all(root: Path) -> dict[tuple[str, str], list[dict]]:
    out = {}
    for lang in LANGS:
        for f in sorted((root / lang).glob("*.md")):
            out[(lang, f.stem)] = parse_markdown(lang, f.stem, f.read_text(encoding="utf-8"))
    return out


async def sync(store: SharedStore, files: dict[tuple[str, str], list[dict]]) -> dict[str, int]:
    counts = {lang: 0 for lang in LANGS}
    for (lang, topic), rows in files.items():
        counts[lang] += await store.replace_curated(lang, topic, rows)
    await store.prune_curated(set(files), LANGS)
    return counts


async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--knowledge", type=Path, default=BOT / "knowledge")
    ap.add_argument("--schema", action="store_true", help="create the extension and tables first")
    ap.add_argument("--dry-run", action="store_true", help="parse and count only")
    ap.add_argument("--dev", action="store_true", help="read the DSN from SWARM_TEST_DSN instead of NEON_SWARM_URL")
    args = ap.parse_args()
    files = read_all(args.knowledge)
    missing = [lang for lang in LANGS if not any(lg == lang for (lg, _) in files)]
    empty = sorted(f"{lg}/{tp}" for (lg, tp), rows in files.items() if not rows)
    if missing or empty:
        # A mistyped --knowledge path or an empty file must never wipe the curated rows.
        print(f"refusing to sync: no files for {missing or 'none'}, files with no paragraphs: {empty or 'none'}", file=sys.stderr)
        return 1
    per_lang = {lang: sum(len(r) for (lg, _), r in files.items() if lg == lang) for lang in LANGS}
    print(f"{len(files)} files, rows per language: {per_lang}")
    if args.dry_run:
        return 0
    dsn = os.environ.get("SWARM_TEST_DSN" if args.dev else "NEON_SWARM_URL")
    if not dsn:
        print("no DSN in the environment", file=sys.stderr)
        return 1
    store = SharedStore(dsn)
    if args.schema:
        await store.apply_schema()
        print("schema applied")
    print("synced:", await sync(store, files))
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
