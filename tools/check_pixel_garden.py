#!/usr/bin/env python3
"""Pixel Garden's bank: the validator, and a contact sheet of the pictures.

    python3 tools/check_pixel_garden.py                    # validate content/pixel_garden.json
    python3 tools/check_pixel_garden.py --sheet out.png    # and draw every picture as beads
    python3 tools/check_pixel_garden.py --sheet out.png --band 2 --skip 10

The rules: a band's pictures are all its size and in its count of colours,
and no id or name is used twice. Easy and Medium (10 and 12 square, spec
2026-09-27, section 3) are one object on a bare board: 30 to 70% filled,
never touching all four edges. Hard and Insane (24 and 32 square, painted by
tools/paint_pixel_garden.py since 2026-10-11) are whole scenes: 85 to 100%
filled, the edges theirs to touch, and no one colour 45% of the picture or
more -- or, a third of them, cut-outs (one subject on a bare board with a
line round it, as Button Box asked on 2026-10-11): told by their fill, 30 to
70%, and let 5 colours on 24 and 6 on 32. The sheet needs Pillow; a big band is laid fewer pictures across so
the sheet stays within SHEET_W pixels.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "content" / "pixel_garden.json"
SIZES = [10, 12, 24, 32]
COLOURS = [(3, 4), (4, 5), (7, 10), (8, 12)]
FILL = [(0.30, 0.70), (0.30, 0.70), (0.85, 1.00), (0.85, 1.00)]
BIG = 2          # the first band of whole scenes
CUT_FILL = (0.30, 0.70)             # a big picture this full is a cut-out
CUT_LEAST = {2: 5, 3: 6}            # and may have this few colours
MOST = 0.45      # a big picture's largest colour stays under this share
SHEET_W = 2000
# core/palette.gd's PG_BEADS.
BEADS = {
    "maroon": "a83a30", "red": "e0503a", "coral": "f28c78", "rust": "c66a24",
    "orange": "f08a2c", "yellow": "f4c640", "butter": "fbe28e", "cream": "f3e6c8",
    "white": "fbf7ee", "pink": "f4a3b4", "rose": "d9607a", "lilac": "b99ad8",
    "purple": "7e5aa6", "sky": "8cc4e8", "blue": "4a7fc1", "navy": "2e4f80",
    "teal": "4fae9c", "lime": "a8cf5a", "green": "5fa845", "forest": "2f7a3f",
    "tan": "d4a56a", "brown": "8a5a36", "dark": "4a3226", "silver": "d5d1c9",
    "grey": "a9a39a",
}


def check(bank):
    errors = []
    palette = bank["palette"]
    ids, names = set(), set()
    for b, pics in enumerate(bank["bands"]):
        n = SIZES[b]
        for pic in pics:
            lo, hi = COLOURS[b]
            pid = pic["id"]
            def bad(msg):
                errors.append("band %d %s: %s" % (b, pid, msg))
            if pid in ids:
                bad("id twice")
            if pic["name"] in names:
                bad("name twice")
            ids.add(pid)
            names.add(pic["name"])
            rows = pic["rows"]
            if len(rows) != n or any(len(r) != n for r in rows):
                bad("not %d x %d: %s" % (n, n, [len(r) for r in rows]))
                continue
            used = set("".join(rows)) - {"."}
            if used - set(palette):
                bad("unknown colours %s" % sorted(used - set(palette)))
            flat = "".join(rows)
            filled = sum(c != "." for c in flat) / float(n * n)
            cut = b >= BIG and CUT_FILL[0] <= filled <= CUT_FILL[1]
            if cut:
                lo = CUT_LEAST[b]
            if not lo <= len(used) <= hi:
                bad("%d colours, wants %d-%d" % (len(used), lo, hi))
            if not cut and not FILL[b][0] <= filled <= FILL[b][1]:
                bad("%.0f%% filled" % (filled * 100))
            if b >= BIG:
                most = max(used, key=flat.count) if used else "."
                if flat.count(most) >= MOST * n * n:
                    bad("%s is %.0f%% of it" % (palette.get(most, most), flat.count(most) * 100.0 / (n * n)))
                continue
            edges = [any(c != "." for c in rows[0]), any(c != "." for c in rows[-1]),
                     any(r[0] != "." for r in rows), any(r[-1] != "." for r in rows)]
            if all(edges):
                bad("touches all four edges")
    return errors


def sheet(bank, out, band, skip, cell):
    from PIL import Image, ImageDraw
    palette = bank["palette"]
    bands = [band] if band >= 0 else range(len(bank["bands"]))
    pad, label = 14, 16
    # One layout a band: its own bead, its own count across.
    lay = []
    for b in bands:
        pics = bank["bands"][b][skip:]
        n = max([len(p["rows"]) for p in pics] + [SIZES[b]])
        c = max(2, min(cell, (SHEET_W - 2 * pad) // n))
        tile = n * c + pad
        per_row = max(1, min(10, (SHEET_W - pad) // tile))
        lay.append((b, pics, n, c, per_row, tile, max(1, -(-len(pics) // per_row))))
    width = max(per_row * tile for _b, _p, _n, _c, per_row, tile, _r in lay) + pad
    height = sum(nrows * (tile + label) for _b, _p, _n, _c, _per, tile, nrows in lay) + pad
    img = Image.new("RGB", (width, height), "#efe6d2")
    d = ImageDraw.Draw(img)
    y0 = pad
    for b, pics, size, c, per_row, tile, nrows in lay:
        for i, pic in enumerate(pics):
            x = pad + (i % per_row) * tile
            y = y0 + (i // per_row) * (tile + label)
            n = len(pic["rows"])
            d.rectangle([x - 3, y - 3, x + n * c + 2, y + n * c + 2], fill="#fbf7ee")
            inset = 1 if c >= 8 else 0
            for r, row in enumerate(pic["rows"]):
                for k, ch in enumerate(row):
                    box = [x + k * c + inset, y + r * c + inset, x + (k + 1) * c - 1, y + (r + 1) * c - 1]
                    if ch == ".":
                        m = c // 2 - 1
                        d.ellipse([box[0] + m, box[1] + m, box[2] - m, box[3] - m], fill="#ddd2bb")
                        continue
                    rgb = tuple(int(BEADS[palette[ch]][j:j + 2], 16) for j in (0, 2, 4))
                    if c < 8:       # a bead this small is a square of its colour
                        d.rectangle(box, fill=rgb)
                        continue
                    d.ellipse(box, fill=tuple(int(v * 0.72) for v in rgb))
                    d.ellipse([box[0] + 1, box[1] + 1, box[2] - 1, box[3] - 1], fill=rgb)
            d.text((x, y + size * c + 1), pic["id"], fill="#4a3226")
        y0 += nrows * (tile + label)
    img.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bank", default=str(BANK))
    ap.add_argument("--sheet")
    ap.add_argument("--band", type=int, default=-1)
    ap.add_argument("--skip", type=int, default=0, help="leave out the first N pictures of each band")
    ap.add_argument("--cell", type=int, default=10, help="pixels a bead")
    a = ap.parse_args()
    bank = json.loads(Path(a.bank).read_text())
    errors = check(bank)
    for e in errors:
        print(e)
    print("%d pictures (%s a band), %d errors" % (
        sum(len(p) for p in bank["bands"]), ", ".join(str(len(p)) for p in bank["bands"]), len(errors)))
    if a.sheet:
        sheet(bank, a.sheet, a.band, a.skip, a.cell)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
