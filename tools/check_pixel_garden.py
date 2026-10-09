#!/usr/bin/env python3
"""Pixel Garden's bank: the validator, and a contact sheet of the pictures.

    python3 tools/check_pixel_garden.py                    # validate content/pixel_garden.json
    python3 tools/check_pixel_garden.py --sheet out.png    # and draw every picture as beads
    python3 tools/check_pixel_garden.py --sheet out.png --band 2 --skip 10

The rules (spec 2026-09-27, section 3): a band's pictures are all its size,
in its count of colours, 30 to 70% filled, never touching all four edges,
and no id or name twice. The sheet needs Pillow.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "content" / "pixel_garden.json"
SIZES = [10, 12, 14, 16]
COLOURS = [(3, 4), (4, 5), (5, 6), (6, 7)]
# core/palette.gd's PG_BEADS.
BEADS = {
    "red": "e0503a", "orange": "f08a2c", "yellow": "f4c640", "cream": "f3e6c8",
    "white": "fbf7ee", "pink": "f4a3b4", "rose": "d9607a", "lilac": "b99ad8",
    "purple": "7e5aa6", "sky": "8cc4e8", "blue": "4a7fc1", "teal": "4fae9c",
    "lime": "a8cf5a", "green": "5fa845", "forest": "2f7a3f", "tan": "d4a56a",
    "brown": "8a5a36", "dark": "4a3226", "grey": "a9a39a",
}


def check(bank):
    errors = []
    palette = bank["palette"]
    ids, names = set(), set()
    for b, pics in enumerate(bank["bands"]):
        n = SIZES[b]
        lo, hi = COLOURS[b]
        for pic in pics:
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
            if not lo <= len(used) <= hi:
                bad("%d colours, wants %d-%d" % (len(used), lo, hi))
            filled = sum(c != "." for c in "".join(rows)) / float(n * n)
            if not 0.30 <= filled <= 0.70:
                bad("%.0f%% filled" % (filled * 100))
            edges = [any(c != "." for c in rows[0]), any(c != "." for c in rows[-1]),
                     any(r[0] != "." for r in rows), any(r[-1] != "." for r in rows)]
            if all(edges):
                bad("touches all four edges")
    return errors


def sheet(bank, out, band, skip, cell):
    from PIL import Image, ImageDraw
    palette = bank["palette"]
    bands = [band] if band >= 0 else range(len(bank["bands"]))
    per_row = 10
    pad, label = 14, 16
    tile = 16 * cell + pad
    rows_of = [max(1, -(-len(bank["bands"][b][skip:]) // per_row)) for b in bands]
    img = Image.new("RGB", (per_row * tile + pad, sum(rows_of) * (tile + label) + pad), "#efe6d2")
    d = ImageDraw.Draw(img)
    y0 = pad
    for b, nrows in zip(bands, rows_of):
        for i, pic in enumerate(bank["bands"][b][skip:]):
            x = pad + (i % per_row) * tile
            y = y0 + (i // per_row) * (tile + label)
            n = len(pic["rows"])
            d.rectangle([x - 3, y - 3, x + n * cell + 2, y + n * cell + 2], fill="#fbf7ee")
            for r, row in enumerate(pic["rows"]):
                for c, ch in enumerate(row):
                    box = [x + c * cell + 1, y + r * cell + 1, x + (c + 1) * cell - 1, y + (r + 1) * cell - 1]
                    if ch == ".":
                        m = cell // 2 - 1
                        d.ellipse([box[0] + m, box[1] + m, box[2] - m, box[3] - m], fill="#ddd2bb")
                        continue
                    rgb = tuple(int(BEADS[palette[ch]][k:k + 2], 16) for k in (0, 2, 4))
                    d.ellipse(box, fill=tuple(int(v * 0.72) for v in rgb))
                    d.ellipse([box[0] + 1, box[1] + 1, box[2] - 1, box[3] - 1], fill=rgb)
            d.text((x, y + 16 * cell + 1), pic["id"], fill="#4a3226")
        y0 += nrows * (tile + label)
    img.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bank", default=str(BANK))
    ap.add_argument("--sheet")
    ap.add_argument("--band", type=int, default=-1)
    ap.add_argument("--skip", type=int, default=0, help="leave out the first N pictures of each band")
    ap.add_argument("--cell", type=int, default=10)
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
