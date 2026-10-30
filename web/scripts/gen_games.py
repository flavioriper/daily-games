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

# The upright middle of an 810 by 1440 screen: every board fits it, the top bar
# and the tray under it do not.
BOX = (0, 290, 810, 1370)
PAPER = (246, 239, 226)
(WEB / "public/games").mkdir(parents=True, exist_ok=True)
for game in games:
    shot = Image.open(ROOT / f"build/site_shots/{game['id']}.png").convert("RGB")
    tile = shot.crop(BOX).resize((240, 320), Image.LANCZOS)
    tile.save(WEB / f"public/games/{game['id']}.webp", quality=82)
    # The tile's plate: the screen's own colour (its saturated pixels, since
    # most of a screen is cream) laid thin over paper, so every game sits on a
    # pale tint of its own world.
    small = tile.resize((60, 80), Image.BOX)
    vivid = [px for px in small.getdata() if max(px) - min(px) > 60]
    if len(vivid) < 40:
        vivid = [px for px in small.getdata() if max(px) - min(px) > 24] or [(170, 190, 140)]
    r, g, b = (sum(c[i] for c in vivid) / len(vivid) for i in range(3))
    game["tint"] = "#%02x%02x%02x" % tuple(round(p * 0.74 + c * 0.26) for p, c in zip(PAPER, (r, g, b)))

(WEB / "src/data/games.json").write_text(json.dumps(games, ensure_ascii=False, indent=1) + "\n")

# The hero's fan of phones: five whole screens, no Peeplet on any of them
# (docs/agents/website.md), at half size.
HERO = ["minigolf", "honeycomb", "buttons", "boats", "posy"]
(WEB / "public/phones").mkdir(parents=True, exist_ok=True)
for id_ in HERO:
    shot = Image.open(ROOT / f"build/site_shots/{id_}.png").convert("RGB")
    shot.resize((405, 720), Image.LANCZOS).save(WEB / f"public/phones/{id_}.webp", quality=84)
print(len(games), "games")

# The page's Peeplets (the user, 2026-10-30), rendered by
# tests/_shot_site_peeplets.gd into build/site_peeplets: the viewport hands
# them over premultiplied, so they are straightened, trimmed and saved with
# their alpha. Never hand-edited.
PEEPLETS = ROOT / "build/site_peeplets"
(WEB / "public/peeplets").mkdir(parents=True, exist_ok=True)
for png in sorted(PEEPLETS.glob("*.png")):
    im = Image.open(png).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if 0 < a < 255:
                px[x, y] = (min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a), a)
    box = im.getbbox()
    im = im.crop((box[0] - 4, max(0, box[1] - 4), box[2] + 4, min(im.height, box[3] + 4)))
    im.save(WEB / f"public/peeplets/{png.stem}.webp", quality=92, method=6)
    print(png.stem, im.size)
