#!/usr/bin/env python3
"""Inlines tools/days/*.json into tools/dashboard.src.html as tools/dashboard.html.

A page opened from file:// cannot fetch its neighbours, so the days ride in
the page, and so does tools/beads.js, the picture maker's converter.
tools/export_days.gd writes the days.

    python3 tools/build_dashboard.py [--open]
"""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DAYS = HERE / "days"


def main() -> None:
    index = json.loads((DAYS / "index.json").read_text())
    days = {}
    for board in index["boards"]:
        path = DAYS / f"{board['id']}.json"
        days[board["id"]] = json.loads(path.read_text()) if path.exists() else []
    # "</" would end the script element the data sits in.
    gallery = DAYS / "gallery.json"
    pictures = json.loads(gallery.read_text()) if gallery.exists() else {"beads": {}, "sets": []}
    # The themed days tools/themed_days.sh made; their drawings stay files
    # beside them, which a page may show from file:// though not read.
    themed = [json.loads(f.read_text()) for f in sorted((DAYS / "themed").glob("[0-9]*.json"))]
    data = json.dumps({"index": index, "days": days, "gallery": pictures, "themed": themed},
                      separators=(",", ":")).replace("</", "<\\/")
    page = (HERE / "dashboard.src.html").read_text().replace("/*BEADS*/", (HERE / "beads.js").read_text(), 1)
    page = page.replace("/*DATA*/", data, 1)
    out = HERE / "dashboard.html"
    out.write_text(page)
    count = sum(len(v) for v in days.values())
    print(f"{out}: {len(days)} boards, {count} days, {len(page) // 1024} KB")
    if "--open" in sys.argv:
        subprocess.run(["open", str(out)])


if __name__ == "__main__":
    main()
