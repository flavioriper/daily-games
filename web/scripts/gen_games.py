#!/usr/bin/env python3
"""Writes src/data/games.json from the game's own registry and locale rows, and
web/public/games/<id>.webp from build/site_shots (tests/_shot_site.gd), so a
new board or a reworded blurb reaches the site by running this again."""
import csv
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"
registry = (ROOT / "ui/registry.gd").read_text()
arcade_tab = (ROOT / "ui/menu/arcade_tab.gd").read_text()
versus_tab = (ROOT / "ui/menu/versus_tab.gd").read_text()

rows = {}
for name in ("locale/boards.csv", "locale/ui.csv"):
    with open(ROOT / name, encoding="utf8") as f:
        for r in csv.reader(f):
            if len(r) >= 4:
                rows[r[0]] = r[1:4]


def names(src):
    m = re.search(r"const NAMES := \{(.*?)\}", src, re.S)
    return dict(re.findall(r'"(\w+)": "([^"]+)"', m.group(1)))


def order(src):
    return re.findall(r'"(\w+)"', re.search(r"const GAMES := \[(.*?)\]", src).group(1))


def text(*keys):
    for key in keys:
        if key in rows and rows[key][0]:
            return dict(zip(("en", "pt", "es"), rows[key]))
    raise SystemExit(f"no text for {keys}")


games = []
for id_, title, blurb in re.findall(r'"id": "(\w+)",.*?"title": "([^"]+)",.*?"blurb": "(\w+)"', registry, re.S):
    if id_ != "marigold":
        games.append({"id": id_, "title": title, "group": "puzzles", "text": text(blurb)})
blurbs = dict(re.findall(r'"id": "(\w+)",.*?"blurb": "(\w+)"', registry, re.S))
for id_ in order(arcade_tab):
    key = blurbs.get(id_) or {"factory": "FACTORY_BLURB", "bagatelle": "BG_MOTTO"}.get(id_, f"ARC_{id_.upper()}_BLURB")
    games.append({"id": id_, "title": names(arcade_tab)[id_], "group": "arcade", "text": text(key)})
for id_ in order(versus_tab):
    up = id_.upper()
    games.append({"id": id_, "title": names(versus_tab)[id_], "group": "versus",
                  "text": text(f"VS_{up}_BLURB", f"VS_{up}_SHORT")})

(WEB / "src/data/games.json").write_text(json.dumps(games, ensure_ascii=False, indent=1) + "\n")

# The upright middle of an 810 by 1440 screen: every board fits it, the top bar
# and the tray under it do not.
BOX = (0, 290, 810, 1370)
(WEB / "public/games").mkdir(parents=True, exist_ok=True)
for game in games:
    shot = Image.open(ROOT / f"build/site_shots/{game['id']}.png").convert("RGB")
    shot.crop(BOX).resize((240, 320), Image.LANCZOS).save(WEB / f"public/games/{game['id']}.webp", quality=82)
print(len(games), "games")
