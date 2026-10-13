#!/usr/bin/env python3
"""Inlines tools/days/*.json into tools/dashboard.src.html as tools/dashboard.html.

A page opened from file:// cannot fetch its neighbours, so the days ride in
the page. tools/export_days.gd writes the days.

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
    data = json.dumps({"index": index, "days": days}, separators=(",", ":")).replace("</", "<\\/")
    page = (HERE / "dashboard.src.html").read_text().replace("/*DATA*/", data, 1)
    out = HERE / "dashboard.html"
    out.write_text(page)
    count = sum(len(v) for v in days.values())
    print(f"{out}: {len(days)} boards, {count} days, {len(page) // 1024} KB")
    if "--open" in sys.argv:
        subprocess.run(["open", str(out)])


if __name__ == "__main__":
    main()
