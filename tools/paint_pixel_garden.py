#!/usr/bin/env python3
"""Pixel Garden's big pictures, painted by script: the source of record.

    python3 tools/paint_pixel_garden.py                 # repaint bands 2 and 3 of content/pixel_garden.json
    python3 tools/paint_pixel_garden.py --out x.json    # the same bank, written somewhere else
    python3 tools/paint_pixel_garden.py --list          # only the table: colours, fill, the largest colour

Hard (band 2) is 24 pegs square and Insane (band 3) is 32, since 2026-10-11:
whole scenes -- a sky, a ground, a subject and its details -- where Easy and
Medium (bands 0 and 1, hand-typed in the bank and never touched here) are one
object on a bare board. Button Box reads the same bank.

A picture is a function that paints a Pic (a grid of the bank's nineteen
palette chars, '.' a bare peg) with the helpers below. Nothing here is random
past a seeded Random, so a run always writes the same bank. The rules a big
picture keeps (tools/check_pixel_garden.py holds them too): 85 to 100% of the
pegs filled, 7 to 10 colours on 24 and 8 to 12 on 32, no colour 45% of the
picture, no colour of fewer than six pegs, and calm areas -- every bead is placed by hand along a dragged run,
and on Button Box a run of one colour is a piece, so a sky or a lawn is a few
long runs with accents and never a field of single pegs.

The chars: r red, o orange, y yellow, c cream, w white, p pink, s rose,
l lilac, u purple, k sky, b blue, t teal, i lime, g green, f forest, n tan,
m brown, d dark, e grey.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "content" / "pixel_garden.json"
PALETTE = "roycwpslukbtigfnmde"
SIZES = {2: 24, 3: 32}
COLOURS = {2: (7, 10), 3: (8, 12)}
FILL = (0.85, 1.00)
MOST = 0.45
LEAST = 6       # a colour has this many pegs or it is not in the picture (Button Box cuts a colour into runs)


# ---------------------------------------------------------------- the painter

class Pic:
    """A square of pegs. x runs right, y runs down, both from 0; every shape
    is clipped to the board, and every corner given is inside the shape."""

    def __init__(self, n, bg="."):
        self.n = n
        self.g = [[bg] * n for _ in range(n)]
        self.clip = None    # (x0, y0, x1, y1): nothing is painted outside it while set

    def rows(self):
        return ["".join(r) for r in self.g]

    def get(self, x, y):
        if 0 <= x < self.n and 0 <= y < self.n:
            return self.g[y][x]
        return ""

    def put(self, x, y, ch, only=None):
        x, y = int(x), int(y)
        if self.clip and not (self.clip[0] <= x <= self.clip[2] and self.clip[1] <= y <= self.clip[3]):
            return
        if 0 <= x < self.n and 0 <= y < self.n and (only is None or self.g[y][x] in only):
            self.g[y][x] = ch

    def dots(self, ch, *xy, only=None):
        """Single pegs: dots('r', (3, 4), (5, 6))."""
        for x, y in xy:
            self.put(x, y, ch, only)

    def fill(self, ch):
        self.rect(0, 0, self.n - 1, self.n - 1, ch)

    def rect(self, x0, y0, x1, y1, ch, only=None):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, ch, only)

    def ellipse(self, cx, cy, rx, ry, ch, only=None):
        """Pegs whose centres lie in the ellipse; a centre of .5 makes an even width."""
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, ch, only)

    def line(self, x0, y0, x1, y1, ch, only=None):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, ch, only)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, pts, ch, only=None):
        """A filled polygon through peg centres, its edges drawn."""
        ys = [p[1] for p in pts]
        for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
            xs = []
            for i, (ax, ay) in enumerate(pts):
                bx, by = pts[(i + 1) % len(pts)]
                if (ay <= y < by) or (by <= y < ay):
                    xs.append(ax + (y - ay) * (bx - ax) / float(by - ay))
            xs.sort()
            for a, b in zip(xs[0::2], xs[1::2]):
                for x in range(int(math.ceil(a - 0.01)), int(math.floor(b + 0.01)) + 1):
                    self.put(x, y, ch, only)
        for i, (ax, ay) in enumerate(pts):
            bx, by = pts[(i + 1) % len(pts)]
            self.line(round(ax), round(ay), round(bx), round(by), ch, only)

    def span(self, y, x0, x1, ch, only=None):
        self.rect(x0, y, x1, y, ch, only)

    def taper(self, cx, y0, y1, hw0, hw1, ch, only=None):
        """Rows y0..y1 centred on cx, the half-width running hw0 to hw1 (a roof, a tower, a tent)."""
        for y in range(int(y0), int(y1) + 1):
            t = 0.0 if y1 == y0 else (y - y0) / float(y1 - y0)
            hw = hw0 + (hw1 - hw0) * t
            self.span(y, int(math.ceil(cx - hw - 0.01)), int(math.floor(cx + hw + 0.01)), ch, only)

    def land(self, top, ch, only=None):
        """Everything from top(x) down to the bottom edge: a hill line."""
        for x in range(self.n):
            for y in range(max(0, int(round(top(x)))), self.n):
                self.put(x, y, ch, only)

    def stamp(self, x, y, rows, flip=False):
        """A sprite from short row strings; a space leaves the peg as it was."""
        for j, row in enumerate(rows):
            row = row[::-1] if flip else row
            for i, ch in enumerate(row):
                if ch != " ":
                    self.put(x + i, y + j, ch)

    def swap(self, x0, y0, x1, y1, a, b):
        self.rect(x0, y0, x1, y1, b, only=a)

    def dither(self, x0, y0, x1, y1, ch, only=None, phase=0):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                if (x + y + phase) % 2 == 0:
                    self.put(x, y, ch, only)

    def speckle(self, x0, y0, x1, y1, ch, count, only, seed, gap=2, length=1):
        """`count` accents (runs of `length` across) on the pegs of `only`,
        no two nearer than `gap`, from a seeded Random: the same every run."""
        rng = random.Random(seed)
        done = []
        tries = 0
        while len(done) < count and tries < 4000:
            tries += 1
            x, y = rng.randint(x0, x1 - length + 1), rng.randint(y0, y1)
            if any(self.get(x + k, y) not in only or self.get(x + k, y) == "" for k in range(length)):
                continue
            if any(abs(x - a) <= gap + length - 1 and abs(y - b) <= gap for a, b in done):
                continue
            done.append((x, y))
        for x, y in done:
            for k in range(length):
                self.put(x + k, y, ch)

    def outline(self, of, ch, over=None, box=None, sides=((1, 0), (-1, 0), (0, 1), (0, -1))):
        """Pegs beside a peg of `of` (and not of it) become ch; `over` narrows
        what may be painted, `sides` which neighbours count."""
        x0, y0, x1, y1 = box or (0, 0, self.n - 1, self.n - 1)
        hit = []
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = self.g[y][x]
                if c in of or (over is not None and c not in over):
                    continue
                if any(self.get(x + dx, y + dy) != "" and self.get(x + dx, y + dy) in of for dx, dy in sides):
                    hit.append((x, y))
        for x, y in hit:
            self.g[y][x] = ch

    def rim(self, of, ch, sides=((1, 0),), box=None, out=None):
        """Shade inside a shape: a peg of `of` whose neighbour on a side is
        not of it (and is of `out`, if given) becomes ch."""
        x0, y0, x1, y1 = box or (0, 0, self.n - 1, self.n - 1)
        hit = []
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.g[y][x] not in of:
                    continue
                for dx, dy in sides:
                    c = self.get(x + dx, y + dy)
                    if c not in of and c != ch and (out is None or c in out):
                        hit.append((x, y))
                        break
        for x, y in hit:
            self.g[y][x] = ch


# ---------------------------------------------------------------- the motifs

def cloud(p, x, y, w=6, ch="w"):
    """Flat-bottomed: its bottom row is w wide at y, starting at x."""
    p.span(y, x, x + w - 1, ch)
    p.span(y - 1, x + 1, x + w - 2, ch)
    if w >= 6:
        p.span(y - 2, x + 2, x + w - 4, ch)


def pine(p, cx, base, h, ch="f", trunk="m", snow=None):
    """A fir of h rows of boughs standing on `base`, one trunk row under them."""
    seq = []
    t = 0
    while len(seq) < h:
        seq += [t, t + 1, t + 2]
        t += 1
    seq = seq[:h]
    top = base - h
    for i, hw in enumerate(seq):
        p.span(top + i, cx - hw, cx + hw, ch)
        if snow and i % 3 == 0:
            p.span(top + i, cx - hw, cx + hw, snow)
    if trunk:
        p.put(cx, base, trunk)


def bird(p, x, y, ch="d"):
    """A far gull: a shallow v, three pegs wide."""
    p.dots(ch, (x, y), (x + 1, y + 1), (x + 2, y))


def daisy(p, x, y, petal="w", eye="y"):
    p.dots(petal, (x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1))
    p.put(x, y, eye)


def turn(rows):
    """A sprite turned a quarter clockwise."""
    w = max(len(r) for r in rows)
    rows = [r.ljust(w) for r in rows]
    return ["".join(rows[len(rows) - 1 - j][i] for j in range(len(rows))) for i in range(w)]


def tuft(p, x, y, ch="i"):
    p.dots(ch, (x, y), (x + 1, y - 1), (x + 2, y))


# ---------------------------------------------------------------- band 2: 24 x 24

def cottage():
    p = Pic(24, "k")
    p.ellipse(20, 4, 2.3, 2.3, "y")
    cloud(p, 1, 5, 7)
    # the hedge behind, then the lawn
    p.ellipse(2, 15, 4.5, 4, "f")
    p.ellipse(21.5, 15, 4, 3.5, "f")
    p.rect(0, 17, 23, 23, "g")
    # chimney behind the roof
    p.rect(15, 4, 16, 8, "m")
    p.dots("w", (16, 2), (17, 1), (18, 1))
    # walls and roof
    p.rect(6, 11, 17, 18, "c")
    p.taper(11.5, 4, 10, 1, 7, "r")
    p.span(10, 4, 19, "m")
    p.rect(11, 6, 12, 7, "b")
    # door, windows, window boxes
    p.rect(11, 14, 12, 18, "m")
    p.put(12, 16, "y")
    p.rect(7, 12, 9, 14, "b")
    p.rect(14, 12, 16, 14, "b")
    p.span(13, 7, 9, "w")
    p.span(13, 14, 16, "w")
    p.dots("w", (8, 12), (8, 14), (15, 12), (15, 14))
    p.span(15, 7, 9, "r")
    p.span(15, 14, 16, "r")
    p.dots("y", (8, 15), (15, 15))
    # the path
    p.taper(11.5, 19, 23, 1.5, 4, "n")
    # bushes with roses, the picket fence
    p.ellipse(3.5, 18.5, 2.2, 1.6, "f")
    p.ellipse(20, 18.5, 2.2, 1.6, "f")
    p.dots("r", (3, 18), (20, 18))
    p.dots("y", (4, 19), (21, 19))
    for x in (0, 2, 4, 6):
        p.rect(x, 20, x, 22, "w")
        p.rect(23 - x, 20, 23 - x, 22, "w")
    p.span(21, 0, 6, "w")
    p.span(21, 17, 23, "w")
    return p


def night_owl():
    p = Pic(24, "b")
    p.rect(0, 0, 23, 6, "u")
    p.ellipse(19, 4, 2.6, 2.6, "c")
    p.dots("y", (2, 2), (6, 4), (11, 1), (2, 9), (21, 11), (4, 14), (20, 15))
    # the far wood and the bough
    for cx, h in ((1, 4), (5, 3), (18, 3), (22, 5)):
        pine(p, cx, 23, h, trunk=None)
    p.rect(0, 22, 23, 23, "f")
    p.rect(0, 18, 23, 19, "m")
    p.span(19, 0, 23, "d")
    p.ellipse(2, 17, 2.4, 1.6, "f")
    p.ellipse(21.5, 17, 2.4, 1.6, "f")
    # the owl
    p.ellipse(11.5, 11.5, 5.2, 6.4, "m")
    p.dots("m", (7, 4), (7, 5), (8, 5), (16, 4), (16, 5), (15, 5), (8, 4), (15, 4))
    p.ellipse(11.5, 13.6, 3.2, 3.6, "n")
    p.dots("m", (10, 12), (13, 12), (11, 14), (12, 14), (10, 16), (13, 16))
    p.rect(6, 10, 7, 15, "d", only="m")
    p.rect(16, 10, 17, 15, "d", only="m")
    p.ellipse(9.3, 8.5, 2.1, 2.1, "c")
    p.ellipse(13.7, 8.5, 2.1, 2.1, "c")
    p.rect(9, 8, 10, 9, "d")
    p.rect(13, 8, 14, 9, "d")
    p.dots("y", (9, 8), (13, 8))
    p.dots("o", (11, 10), (12, 10), (11, 11), (12, 11))
    p.dots("o", (9, 18), (10, 18), (13, 18), (14, 18))
    return p


def bunny_meadow():
    p = Pic(24, "k")
    p.ellipse(3, 3, 2.3, 2.3, "y")
    cloud(p, 14, 4, 8)
    bird(p, 8, 2)
    bird(p, 9, 6)
    # the wood behind, so the ears stand against it
    for cx in (1, 5, 9, 13, 17, 21):
        p.ellipse(cx + 0.5, 9.5, 2.8, 2.8, "f")
    p.rect(0, 10, 23, 13, "f")
    p.rect(0, 13, 23, 23, "g")
    p.ellipse(4, 14, 6, 1.6, "i")
    p.ellipse(20, 14.5, 5, 1.4, "i")
    # the bunny, looking right
    p.ellipse(10, 17.2, 5.4, 3.7, "w")
    p.ellipse(15.5, 13.2, 2.9, 2.7, "w")
    p.rect(13, 5, 14, 11, "w")
    p.rect(16, 5, 17, 11, "w")
    p.rect(14, 6, 14, 10, "p")
    p.rect(16, 6, 16, 10, "p")
    p.put(16, 13, "d")
    p.put(18, 14, "p")
    p.rect(14, 18, 16, 20, "w")
    p.span(21, 6, 16, "c", only="w")
    p.span(20, 5, 16, "c", only="w")
    p.dots("c", (12, 16), (12, 17), (11, 18), (10, 19), (13, 15))
    p.ellipse(4.2, 16.6, 1.6, 1.6, "c")
    # a carrot, daisies, tufts
    p.span(20, 19, 22, "o")
    p.span(21, 20, 21, "o")
    p.dots("i", (18, 19), (18, 20), (18, 21))
    daisy(p, 3, 20)
    daisy(p, 21, 16)
    daisy(p, 9, 22, petal="p")
    tuft(p, 0, 17)
    tuft(p, 13, 22)
    tuft(p, 20, 23)
    return p


def pumpkin_patch():
    p = Pic(24, "k")
    cloud(p, 2, 4, 7)
    cloud(p, 15, 6, 6)
    # the hedge and the white fence
    for cx in (1, 5, 9, 13, 17, 21):
        p.ellipse(cx + 0.5, 9.5, 2.6, 2.2, "f")
    p.rect(0, 10, 23, 13, "f")
    for x in range(1, 24, 3):
        p.rect(x, 10, x, 14, "w")
    p.span(11, 0, 23, "w")
    p.span(13, 0, 23, "w")
    p.rect(0, 14, 23, 23, "g")
    p.ellipse(11.5, 22.5, 12.5, 3.2, "n")
    # the pumpkins
    for cx, cy, rx, ry in ((11.5, 17.2, 5.2, 4.4), (2.5, 20.4, 2.9, 2.2), (20.5, 20.6, 3, 2.3)):
        p.span(int(cy + ry) + 1, int(cx - rx) + 2, int(cx + rx) - 1, "m")
        p.ellipse(cx, cy, rx, ry, "o")
        for y in range(int(cy - ry), int(cy + ry) + 1):
            v = (y - cy) / ry
            if abs(v) < 0.8 and rx > 4:
                for side in (-1, 1):
                    p.put(int(round(cx + side * 0.42 * rx * math.sqrt(1 - v * v))), y, "m", only="o")
        p.ellipse(cx - rx * 0.62, cy - ry * 0.25, max(0.5, rx * 0.12), ry * 0.38, "y", only="o")
        p.rect(int(cx), int(cy - ry) - 1, int(cx) + (1 if rx > 4 else 0), int(cy - ry), "f")
    p.dots("f", (13, 11))
    # leaves on the vine
    p.ellipse(6, 15.5, 1.8, 1.1, "f")
    p.ellipse(18, 16, 1.8, 1.1, "f")
    p.dots("y", (1, 16), (22, 15))
    return p


def duck_pond():
    p = Pic(24, "k")
    cloud(p, 2, 3, 7)
    for cx in (2, 7, 12, 17, 22):
        p.ellipse(cx, 8, 3, 2.6, "f")
    p.rect(0, 9, 23, 10, "g")
    p.rect(0, 11, 23, 23, "b")
    for y, x0, x1 in ((12, 17, 22), (14, 5, 8), (21, 9, 15), (23, 16, 22)):
        p.span(y, x0, x1, "t")
    # the duck
    p.ellipse(11, 16, 5.6, 3, "w")
    p.dots("w", (5, 14), (6, 14), (5, 13), (4, 13))
    p.rect(14, 12, 16, 15, "w")
    p.ellipse(15.5, 10.4, 2.3, 2.2, "w")
    p.put(16, 10, "d")
    p.dots("o", (18, 11), (19, 11), (18, 10), (19, 10), (20, 11))
    p.ellipse(10, 16.2, 3.2, 1.5, "c")
    p.rect(19, 15, 21, 16, "w")
    p.dots("w", (21, 14), (22, 14))
    p.put(23, 14, "o")
    p.span(17, 18, 22, "k")
    p.span(15, 8, 11, "w")
    p.span(19, 4, 18, "k")
    p.span(20, 7, 15, "t")
    # the bulrushes in front, the lily pads
    for x, top in ((1, 12), (3, 14)):
        p.rect(x, top, x, 23, "g")
        p.rect(x, top, x, top + 2, "d")
    p.dots("g", (2, 20), (0, 18))
    p.ellipse(19.5, 19.5, 2.6, 1.2, "g")
    p.span(19, 19, 21, "p")
    p.ellipse(8, 22.6, 2, 0.9, "g")
    p.span(22, 7, 9, "p")
    return p


def balloon_ride():
    p = Pic(24, "k")
    cloud(p, 0, 7, 6)
    cloud(p, 17, 4, 7)
    cloud(p, 18, 13, 6)
    # the hills, a valley between them
    p.ellipse(1, 23, 9, 7, "i")
    p.ellipse(22, 23, 9, 7, "i")
    p.ellipse(11.5, 24, 12, 4.5, "g")
    for cx, base in ((3, 20), (20, 20), (22, 22)):
        pine(p, cx, base, 3, trunk=None)
    p.stamp(6, 20, [" r ", "rrr", "mmm"])
    # the balloon
    cx, cy, rx, ry = 10.5, 7.2, 6.6, 7.0
    for y in range(0, 16):
        for x in range(0, 24):
            v = (y - cy) / ry
            if abs(v) >= 1:
                continue
            u = (x - cx) / (rx * math.sqrt(1 - v * v))
            if abs(u) <= 1:
                p.put(x, y, "ryryr"[min(4, int((u + 1) * 2.5))])
    p.span(14, 8, 13, "r")
    p.span(15, 9, 12, "y")
    p.dots("d", (9, 16), (12, 16))
    p.rect(9, 17, 12, 18, "m")
    p.span(17, 9, 12, "d")
    bird(p, 1, 2)
    bird(p, 19, 9)
    return p


def sailing_day():
    p = Pic(24, "k")
    p.ellipse(4, 4, 2.3, 2.3, "y")
    cloud(p, 15, 4, 8)
    # the island and the sea
    p.ellipse(20.5, 13.5, 4, 2.6, "g")
    p.span(13, 16, 23, "n")
    p.rect(0, 14, 23, 23, "b")
    p.span(14, 17, 23, "n")
    for y, x0, x1 in ((15, 0, 2), (15, 21, 23), (19, 1, 5), (21, 14, 20), (23, 4, 9), (18, 20, 23)):
        p.span(y, x0, x1, "t")
    # the boat
    p.rect(11, 1, 11, 15, "d")
    for y in range(3, 14):
        p.span(y, 12, 12 + int((y - 3) * 0.75), "w")
    for y in range(5, 14):
        p.span(y, 10 - int((y - 5) * 0.7), 10, "r" if (y // 2) % 2 else "w")
    p.dots("r", (12, 1), (13, 1), (12, 2))
    p.span(15, 3, 19, "d")
    p.span(16, 4, 18, "r")
    p.span(17, 5, 17, "r")
    p.span(16, 6, 16, "w")
    p.span(18, 4, 18, "k")
    p.span(19, 7, 15, "t")
    bird(p, 5, 9)
    bird(p, 19, 8)
    return p


def apple_orchard():
    p = Pic(24, "k")
    p.ellipse(21, 2, 2.3, 2.3, "y")
    cloud(p, 16, 6, 6)
    p.ellipse(20, 15, 5, 3, "i")
    p.rect(0, 16, 23, 23, "g")
    # the far tree
    p.rect(20, 13, 20, 16, "m")
    p.ellipse(20, 10.5, 3.2, 3.2, "f")
    p.dots("r", (19, 10), (21, 12), (21, 9))
    # the big tree
    p.rect(8, 12, 10, 19, "m")
    p.rect(10, 12, 10, 19, "d")
    p.dots("m", (7, 19))
    p.dots("d", (11, 19))
    p.ellipse(9, 7.5, 8.4, 6.6, "f")
    p.ellipse(6.5, 5.5, 5, 3.4, "g")
    p.ellipse(12.5, 9, 2.6, 1.6, "g")
    p.dots("r", (4, 4), (8, 3), (12, 5), (2, 8), (6, 9), (10, 7), (14, 10), (9, 12), (15, 6), (4, 12))
    # the basket and the windfalls
    p.rect(14, 19, 19, 22, "n")
    p.span(19, 13, 20, "m")
    p.dots("m", (15, 21), (17, 21), (16, 22), (18, 22), (14, 22))
    p.span(18, 14, 19, "r")
    p.span(17, 15, 18, "r")
    p.put(16, 17, "y")
    p.dots("r", (3, 21), (6, 22), (22, 20))
    tuft(p, 0, 18)
    tuft(p, 20, 23)
    daisy(p, 2, 22, petal="w", eye="y")
    return p


def snow_day():
    p = Pic(24, "k")
    p.dots("w", (2, 2), (7, 4), (17, 2), (21, 5), (4, 8), (19, 9))
    # lilac hills far off, firs, the snow
    p.land(lambda x: 12.5 + 1.4 * math.sin(x / 5.0), "l")
    pine(p, 3, 19, 9)
    pine(p, 20, 18, 8)
    p.dots("w", (3, 10), (2, 13), (4, 16), (20, 10), (21, 13), (19, 16))
    p.land(lambda x: 19.4 + 0.8 * math.cos((x - 12) / 4.0), "w")
    # the snowman, shaded down its right side
    cx = 12
    balls = ((cx, 17.4, 4.6, 4.1), (cx, 11.6, 3.5, 3.1), (cx, 7, 2.6, 2.6))
    mask = Pic(24)
    for b in balls:
        mask.ellipse(b[0], b[1], b[2], b[3], "w")
        p.ellipse(b[0], b[1], b[2], b[3], "w")
    for y in range(24):
        for x in range(24):
            if mask.get(x, y) == "w" and mask.get(x + 1, y) != "w" and x > cx:
                p.put(x, y, "e")
    p.span(14, 10, 14, "e")
    p.span(22, 9, 18, "e")
    # hat, scarf, face, buttons, arms
    p.rect(10, 1, 14, 3, "d")
    p.span(3, 10, 14, "r")
    p.span(4, 8, 16, "d")
    p.span(9, 9, 15, "r")
    p.rect(14, 10, 15, 12, "r")
    p.dots("d", (11, 6), (13, 6))
    p.dots("o", (12, 7), (13, 7), (14, 7))
    p.dots("o", (12, 12), (12, 16), (12, 18))
    p.line(8, 11, 5, 8, "m")
    p.dots("m", (5, 7), (4, 9))
    p.line(16, 11, 19, 8, "m")
    p.dots("m", (19, 7), (20, 9))
    return p


def campfire_night():
    p = Pic(24, "b")
    p.rect(0, 0, 23, 5, "u")
    p.ellipse(19, 3.5, 2.2, 2.2, "c")
    p.dots("y", (2, 1), (7, 3), (13, 1), (15, 6), (1, 8), (22, 9))
    for cx, base, h in ((1, 16, 10), (22, 16, 9), (5, 16, 5), (15, 16, 6)):
        pine(p, cx, base, h, trunk=None)
    p.rect(0, 16, 23, 23, "g")
    p.span(16, 0, 23, "f")
    # the tent
    p.taper(8, 7, 19, 0, 7.5, "o")
    for y in range(8, 20):
        p.span(y, 9, 8 + int((y - 7) * 0.64), "y", only="o")
    for y in range(13, 20):
        hw = int((y - 12) * 0.4)
        p.span(y, 8 - hw, 8 + hw, "d")
    p.dots("m", (8, 6), (7, 5), (9, 5))
    # the fire
    p.ellipse(19, 17.6, 2.3, 3.4, "r")
    p.ellipse(19, 18.6, 1.4, 2.3, "o")
    p.dots("y", (19, 19), (19, 20), (19, 18))
    p.span(21, 16, 22, "m")
    p.dots("d", (17, 22), (21, 22))
    p.dots("o", (18, 12), (20, 11))
    p.rect(12, 21, 14, 22, "m")
    p.span(21, 12, 14, "d")
    return p


def autumn_hedgehog():
    p = Pic(24, "k")
    # the wood behind
    p.rect(0, 7, 23, 12, "f")
    for cx in (8, 12, 16):
        p.ellipse(cx, 7, 2.6, 2, "f")
    p.rect(2, 0, 4, 13, "m")
    p.rect(19, 0, 21, 13, "m")
    p.rect(4, 0, 4, 13, "d")
    p.rect(21, 0, 21, 13, "d")
    p.ellipse(3, 1.5, 5.5, 3.4, "o")
    p.ellipse(20, 1.5, 5.5, 3.4, "o")
    p.ellipse(1.5, 1, 2.2, 1.4, "y")
    p.ellipse(21.5, 1, 2.2, 1.4, "y")
    p.ellipse(5.5, 3, 1.6, 1, "r")
    p.ellipse(17.5, 3, 1.6, 1, "r")
    p.rect(0, 13, 23, 23, "g")
    # the hedgehog, nose to the right
    p.ellipse(10.5, 16, 6.6, 4.6, "m")
    for y in range(11, 21):
        for x in range(3, 18):
            if p.get(x, y) == "m" and (x + 2 * y) % 5 == 0 and y < 19:
                p.put(x, y, "d")
    p.ellipse(17.2, 17.6, 3.4, 2.3, "c")
    p.span(19, 6, 15, "c", only="md")
    p.span(20, 6, 16, "c", only="md")
    p.put(21, 17, "d")
    p.put(17, 16, "d")
    p.dots("m", (14, 13), (15, 13))
    p.dots("d", (7, 21), (8, 21), (13, 21), (14, 21))
    # a toadstool and the fallen leaves
    p.rect(2, 19, 3, 21, "w")
    p.ellipse(2.5, 17.6, 2.6, 1.6, "r")
    p.dots("w", (1, 17), (3, 18), (4, 17))
    for x, y, ch in ((20, 21, "o"), (10, 23, "r"), (5, 14, "y"), (21, 14, "o"), (17, 22, "y"), (0, 22, "o")):
        p.span(y, x, x + 1, ch)
    return p


def tulip_fields():
    p = Pic(24, "k")
    cloud(p, 0, 4, 7)
    cloud(p, 17, 7, 6)
    for cx in range(1, 24, 4):
        p.ellipse(cx, 11.6, 2.2, 1.4, "g")
    # the windmill
    p.taper(12, 5, 12, 2, 4, "c")
    p.rect(10, 3, 14, 4, "m")
    p.span(2, 11, 13, "m")
    p.rect(12, 10, 12, 12, "m")
    p.put(12, 8, "d")
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        p.line(12 + dx, 6 + dy, 12 + dx * 6, 6 + dy * 6, "d")
        p.line(12 + dx * 3, 6 + dy * 2, 12 + dx * 7, 6 + dy * 6, "w") if dx * dy < 0 else \
            p.line(12 + dx * 2, 6 + dy * 3, 12 + dx * 6, 6 + dy * 7, "w")
    p.put(12, 6, "d")
    # the fields
    for y, ch in ((12, "g"), (13, "r"), (14, "r"), (15, "g"), (16, "y"), (17, "y"), (18, "g"),
                  (19, "p"), (20, "p"), (21, "g"), (22, "r"), (23, "r")):
        p.span(y, 0, 23, ch, only="k" if y == 12 else None)
    p.taper(12, 13, 23, 0.5, 3, "n")
    return p


# ---------------------------------------------------------------- band 3: 32 x 32


def cat_in_box():
    p = Pic(32, "k")
    # sun, clouds, the sea, the sand
    p.ellipse(4.5, 4.5, 3, 3, "y")
    cloud(p, 22, 3, 9)
    cloud(p, 25, 11, 6)
    cloud(p, 1, 15, 6)
    p.rect(0, 18, 31, 20, "b")
    p.span(19, 0, 5, "t")
    p.span(20, 26, 31, "t")
    p.rect(0, 21, 31, 31, "c")
    # the box: the dark inside, the flaps, the front
    p.rect(8, 17, 23, 19, "m")
    p.poly([(7, 17), (3, 14), (2, 16), (6, 20)], "n")
    p.poly([(24, 17), (28, 14), (29, 16), (25, 20)], "n")
    p.rect(7, 20, 24, 28, "n")
    p.outline("n", "d", over="kbctw", box=(0, 12, 31, 31))
    p.span(20, 7, 24, "d")
    p.rect(15, 21, 16, 28, "c")
    p.rect(19, 23, 22, 25, "m")
    p.span(30, 9, 27, "n")
    for y, x0, x1 in ((23, 0, 3), (24, 28, 31), (27, 0, 2), (31, 2, 7), (27, 29, 31)):
        p.span(y, x0, x1, "n")
    # the cat
    p.rect(11, 16, 20, 19, "o")
    p.ellipse(15.5, 12, 6.3, 5.2, "o")
    p.taper(11, 4, 8, 0, 2, "o")
    p.taper(20, 4, 8, 0, 2, "o")
    p.dots("p", (11, 6), (11, 7), (20, 6), (20, 7))
    p.stamp(24, 6, ["  ww", "  oo", " oo ", " oo ", "oo  ", "oo  ", "oo  ", "oo  "])
    p.outline("op", "m", over="k", box=(4, 2, 30, 17))
    p.ellipse(15.5, 14.6, 3.2, 2.2, "w")
    p.rect(14, 17, 17, 19, "w")
    p.dots("p", (15, 13), (16, 13))
    p.dots("d", (15, 15), (16, 15))
    for ex in (12, 18):
        p.rect(ex, 10, ex + 1, 11, "g")
        p.put(ex + (1 if ex < 15 else 0), 10, "d")
    p.dots("m", (15, 7), (16, 7), (15, 8), (16, 8), (13, 7), (18, 7), (10, 13), (11, 14), (21, 13), (20, 14))
    # paws over the edge, the tail
    p.rect(10, 19, 12, 21, "w")
    p.rect(19, 19, 21, 21, "w")
    p.dots("d", (11, 21), (20, 21))
    # a starfish and a shell
    p.stamp(27, 28, [" p ", "ppp", "p p"])
    p.dots("p", (3, 29), (4, 29), (3, 28))
    return p


def woodland_fox():
    p = Pic(32, "k")
    # the wood: canopy, trunks, the undergrowth
    p.rect(0, 0, 31, 4, "f")
    for cx, cy, rx, ry in ((3, 5, 5, 3), (11, 4, 4, 2.6), (20, 4.5, 5, 3), (28, 5, 4.5, 3.4)):
        p.ellipse(cx, cy, rx, ry, "f")
    for cx, cy, rx, ry in ((4, 1.5, 3.5, 1.2), (14, 1, 4, 1), (24, 2, 4, 1.4)):
        p.ellipse(cx, cy, rx, ry, "g")
    p.rect(2, 7, 4, 22, "m")
    p.rect(4, 7, 4, 22, "d")
    p.rect(27, 8, 29, 22, "m")
    p.rect(29, 8, 29, 22, "d")
    p.rect(22, 7, 22, 19, "m")
    p.rect(9, 6, 9, 19, "m")
    for cx in (1, 7, 13, 19, 25, 30):
        p.ellipse(cx, 19.5, 3.6, 2.6, "g")
    p.rect(0, 20, 31, 22, "g")
    p.rect(0, 22, 31, 31, "i")
    p.ellipse(16, 29.5, 11, 2.4, "g")
    # the fox, sitting, looking left
    p.ellipse(24, 26.2, 5, 2.4, "o")
    p.ellipse(28, 25.4, 2.2, 1.8, "w")
    p.ellipse(17.5, 21.5, 4.6, 6, "o")
    p.ellipse(14.6, 22.5, 2.2, 3.8, "w")
    p.rect(13, 24, 14, 28, "o")
    p.rect(16, 25, 17, 28, "o")
    p.rect(13, 27, 14, 28, "d")
    p.rect(16, 27, 17, 28, "d")
    p.ellipse(19.5, 26.6, 2.6, 1.8, "o")
    p.ellipse(13.5, 13.6, 4.6, 3.6, "o")
    p.taper(10.5, 7, 10, 0, 1.6, "o")
    p.taper(16.5, 7, 10, 0, 1.6, "o")
    p.dots("d", (10, 7), (10, 8), (16, 7), (16, 8), (17, 8), (11, 8))
    p.span(14, 7, 11, "w")
    p.span(15, 6, 12, "w")
    p.span(16, 8, 13, "w")
    p.span(17, 11, 14, "w")
    p.dots("d", (6, 14), (5, 15), (6, 15))
    p.dots("d", (11, 13), (15, 13))
    # toadstools, ferns, buttercups
    p.rect(4, 27, 5, 29, "c")
    p.ellipse(4.5, 25.8, 2.8, 1.6, "r")
    p.dots("w", (3, 25), (6, 26))
    p.rect(8, 29, 8, 30, "c")
    p.span(28, 7, 9, "r")
    for x, y in ((28, 29), (1, 23), (23, 30), (9, 24), (30, 24), (11, 30)):
        p.put(x, y, "y")
    tuft(p, 26, 30, "g")
    tuft(p, 0, 30, "g")
    tuft(p, 23, 23, "g")
    return p


def red_barn():
    p = Pic(32, "k")
    p.ellipse(4.5, 4.5, 3, 3, "y")
    cloud(p, 20, 4, 9)
    cloud(p, 9, 7, 6)
    # far hills, the yard
    p.land(lambda x: 18.5 + 1.6 * math.sin(x / 4.5), "f")
    p.rect(0, 22, 31, 31, "g")
    # the silo
    p.ellipse(25.5, 11, 2.6, 2.6, "d")
    p.rect(23, 11, 28, 25, "e")
    p.rect(24, 12, 24, 25, "w")
    p.span(15, 23, 28, "d")
    p.span(20, 23, 28, "d")
    # the barn: grey roof, red gable
    for y, x0, x1 in ((5, 12, 17), (6, 10, 19), (7, 8, 21), (8, 7, 22), (9, 6, 23)):
        p.span(y, x0, x1, "e")
    p.rect(5, 10, 24, 12, "e")
    for y, x0, x1 in ((7, 12, 17), (8, 10, 19), (9, 9, 20), (10, 8, 21)):
        p.span(y, x0, x1, "r")
    p.rect(7, 11, 22, 25, "r")
    p.rect(13, 9, 16, 12, "w")
    p.rect(14, 10, 15, 12, "d")
    p.rect(10, 16, 19, 25, "w")
    p.rect(11, 17, 18, 25, "r")
    p.line(11, 17, 18, 24, "w")
    p.line(18, 17, 11, 24, "w")
    p.rect(14, 17, 15, 25, "w")
    p.span(13, 7, 22, "w")
    p.dots("d", (14, 3), (15, 3), (14, 4), (16, 2), (13, 2))
    # the yard: a path, hay, a fence, hens
    p.taper(14.5, 26, 31, 4, 7, "n")
    p.rect(1, 23, 5, 26, "y")
    p.dots("o", (2, 24), (3, 24), (4, 25), (2, 25), (3, 26))
    p.span(27, 1, 5, "f")
    for x in (25, 28, 31):
        p.rect(x, 26, x, 30, "w")
    p.span(27, 24, 31, "w")
    p.span(29, 24, 31, "w")
    p.stamp(3, 28, [" r ", "wwo", "ww "])
    p.stamp(20, 28, ["r  ", "ww ", "www"], flip=True)
    return p


def koi_pond():
    p = Pic(32, "g")
    # the bank: bushes in the corners, the stones, the water
    for cx, cy in ((1, 1), (30, 1), (0, 30), (30, 30)):
        p.ellipse(cx, cy, 3.6, 3.6, "f")
    p.ellipse(15.5, 15.5, 14.2, 13, "e")
    p.ellipse(15.5, 15.5, 13.2, 12, "t")
    p.ellipse(15.5, 16, 10.4, 9, "b")
    for x, y in ((6, 4), (14, 2), (24, 4), (29, 13), (27, 25), (17, 28), (6, 26), (1, 17)):
        p.span(y, x, x + 1, "d", only="e")
    # ripples
    for y, x0, x1 in ((24, 12, 18), (13, 20, 24)):
        p.span(y, x0, x1, "k")
    # the koi
    koi = [" doowwo  o", "oooowwoooo", " doowwo  o"]
    red = [" dwrrww  w", "wwwrrwwrww", " dwrrww  w"]
    p.stamp(7, 11, koi)
    p.stamp(14, 19, red, flip=True)
    p.stamp(20, 8, turn(koi))
    # lily pads and their flowers
    for cx, cy, r in ((7, 8, 2.3), (24, 22, 2.6), (23, 8, 1.8), (9, 24, 1.8)):
        p.ellipse(cx, cy, r, r, "g")
        p.ellipse(cx - 0.6, cy - 0.6, r * 0.45, r * 0.45, "i")
        p.put(int(cx + r), int(cy), "t")
    p.stamp(23, 21, [" p ", "pwp", " p "])
    p.stamp(6, 7, [" p ", "pwp", " p "])
    # the bank's flowers
    daisy(p, 5, 1, petal="w", eye="o")
    daisy(p, 26, 29, petal="w", eye="o")
    p.dots("p", (9, 0), (22, 31), (0, 9))
    tuft(p, 23, 0)
    tuft(p, 4, 30)
    tuft(p, 0, 22)
    tuft(p, 29, 7)
    return p


def mushroom_house():
    p = Pic(32, "k")
    cloud(p, 0, 4, 7)
    cloud(p, 25, 7, 7)
    # the cap
    p.clip = (0, 0, 31, 14)
    p.ellipse(15.5, 14, 13, 11.5, "r")
    p.clip = None
    p.rim("r", "s", sides=((1, 0), (2, 0)), box=(16, 2, 31, 14), out="k")
    for cx, cy, rx, ry in ((8, 10, 2.2, 1.6), (15, 6.5, 2.6, 2), (23, 10.5, 2, 1.5), (12.5, 12.5, 1, 0.8), (19.5, 12, 1, 0.8)):
        p.ellipse(cx, cy, rx, ry, "w")
    p.span(14, 3, 28, "s")
    p.span(15, 5, 26, "c")
    p.span(15, 6, 25, "n", only="c")
    p.span(15, 5, 26, "n")
    # the stalk: a house
    p.taper(15.5, 16, 27, 5.5, 7, "c")
    p.rim("c", "n", sides=((1, 0), (2, 0)), box=(16, 16, 31, 27), out="k")
    p.rect(12, 21, 15, 27, "m")
    p.span(20, 13, 14, "m")
    p.put(14, 24, "y")
    p.rect(17, 18, 20, 21, "m")
    p.rect(18, 19, 19, 20, "y")
    p.rect(10, 17, 11, 18, "m")
    p.put(10, 17, "y")
    # the garden
    p.ellipse(1, 24, 4, 4.5, "f")
    p.ellipse(30.5, 24, 4, 5, "f")
    p.rect(0, 26, 31, 31, "g")
    p.taper(13.5, 28, 31, 1.5, 4, "n")
    p.rect(5, 25, 6, 27, "c")
    p.ellipse(5.5, 23.8, 2.8, 1.7, "r")
    p.dots("w", (4, 23), (7, 24))
    p.rect(26, 26, 26, 28, "c")
    p.span(25, 25, 27, "r")
    p.put(26, 24, "r")
    daisy(p, 22, 29)
    daisy(p, 3, 30)
    p.dots("y", (1, 23), (30, 22), (29, 25), (2, 26))
    tuft(p, 8, 30)
    tuft(p, 27, 31)
    tuft(p, 19, 27)
    return p


def lighthouse():
    p = Pic(32, "k")
    p.ellipse(26, 5, 2.8, 2.8, "y")
    cloud(p, 15, 9, 8)
    cloud(p, 0, 4, 6)
    bird(p, 19, 3)
    bird(p, 24, 13)
    # the sea
    p.rect(0, 19, 31, 31, "b")
    for y, x0, x1 in ((20, 22, 29), (23, 17, 23), (26, 24, 31), (29, 15, 22), (21, 14, 17)):
        p.span(y, x0, x1, "t")
    # a far sail
    p.stamp(25, 15, [" w ", "ww ", "www", "ddd"])
    # the headland: rock under turf
    top = lambda x: 19 + max(0.0, (x - 9) * 0.55) ** 1.25
    for x in range(0, 21):
        y0 = int(round(top(x)))
        for y in range(y0, 32):
            p.put(x, y, "e")
        p.put(x, y0, "g")
        p.put(x, y0 + 1, "g")
    for x, y, n in ((2, 24, 3), (8, 27, 3), (1, 29, 2), (12, 30, 3)):
        p.line(x, y, x + n, y + 1, "d", only="e")
    p.outline("e", "w", over="b", box=(8, 20, 31, 31))
    # the keeper's house
    p.rect(12, 16, 16, 19, "c")
    p.taper(14, 13, 15, 0.5, 3, "r")
    p.put(14, 17, "d")
    p.rect(14, 18, 14, 19, "d")
    # the tower
    p.taper(6.5, 6, 20, 2.5, 4, "w")
    for y in (8, 9, 12, 13, 16, 17):
        p.swap(0, y, 12, y, "w", "r")
    p.rim("wr", "e", sides=((1, 0),), box=(0, 6, 12, 20), out="kc")
    p.rect(6, 18, 7, 20, "d")
    p.dots("d", (6, 10), (7, 14))
    p.span(5, 3, 10, "d")
    p.rect(5, 2, 8, 4, "y")
    p.dots("d", (4, 2), (4, 3), (4, 4), (9, 2), (9, 3), (9, 4))
    p.taper(6.5, 0, 1, 0.5, 2.5, "r")
    return p


def sheep_hill():
    p = Pic(32, "k")
    p.ellipse(26.5, 4.5, 3, 3, "y")
    cloud(p, 2, 5, 9)
    cloud(p, 14, 9, 7)
    # the hills
    p.land(lambda x: 15 + 1.8 * math.sin(x / 5.0 + 2.2), "f")
    p.land(lambda x: 17.5 - 4.5 * math.exp(-((x - 15) / 13.0) ** 2), "g")
    p.land(lambda x: 27.5 + 2.0 * math.sin(x / 6.0 + 1.0), "i")
    # a tree on the far slope
    p.rect(28, 12, 28, 15, "m")
    p.ellipse(28, 9.5, 2.6, 2.8, "f")
    # the ewe, looking left
    for cx, cy, r in ((16, 18, 5.2), (11.5, 16.5, 3), (20.5, 16.5, 3.2), (12, 20, 3), (20.5, 20, 3.2), (16, 14.6, 3)):
        p.ellipse(cx, cy, r, r * 0.9, "w")
    p.ellipse(16, 22, 6, 1.4, "c", only="w")
    p.dots("c", (13, 17), (14, 16), (18, 18), (19, 17), (15, 20), (16, 19))
    p.rect(12, 23, 13, 26, "d")
    p.rect(19, 23, 20, 26, "d")
    p.ellipse(8.2, 17.4, 2.4, 3, "d")
    p.dots("d", (10, 15), (11, 15), (6, 15))
    p.put(8, 17, "w")
    p.ellipse(9.5, 14, 1.8, 1.2, "w")
    # the lamb
    for cx, cy, r in ((26, 22.5, 2.6), (24.5, 22, 1.8), (27.5, 22, 1.8)):
        p.ellipse(cx, cy, r, r * 0.85, "w")
    p.ellipse(23, 21, 1.3, 1.5, "d")
    p.put(23, 21, "w")
    p.rect(25, 25, 25, 26, "d")
    p.rect(28, 25, 28, 26, "d")
    # the fence and the flowers
    for x in (1, 6, 11):
        p.rect(x, 26, x, 30, "m")
    p.span(27, 0, 12, "m")
    p.span(29, 0, 12, "m")
    for x, y, ch in ((16, 29, "y"), (21, 30, "p"), (27, 29, "y"), (30, 31, "p"), (15, 31, "p"), (22, 30, "p"), (29, 31, "p"), (14, 31, "p"), (3, 22, "y"), (30, 19, "y")):
        p.put(x, y, ch)
    tuft(p, 23, 28, "g")
    tuft(p, 17, 27, "i")
    tuft(p, 2, 19, "i")
    return p


def bee_garden():
    p = Pic(32, "k")
    cloud(p, 11, 4, 10)
    # the picket fence and the lawn
    for x in range(0, 32, 3):
        p.rect(x, 17, x, 23, "w")
    p.span(19, 0, 31, "w")
    p.span(22, 0, 31, "w")
    p.rect(0, 24, 31, 31, "g")
    # the hive on its bench
    for y in range(8, 23):
        v = (y - 8) / 14.0
        hw = 1.2 + 6.4 * math.sqrt(min(1.0, v * 1.5))
        p.span(y, int(math.ceil(15.5 - hw)), int(math.floor(15.5 + hw)), "o" if y % 3 == 1 else "y")
    p.ellipse(15.5, 20.6, 1.5, 1.6, "d")
    p.rect(7, 23, 24, 24, "m")
    p.span(24, 7, 24, "d")
    p.rect(9, 25, 10, 28, "m")
    p.rect(21, 25, 22, 28, "m")
    # the sunflowers
    for sx, sy in ((4, 8), (27, 6)):
        p.rect(sx, sy + 3, sx, 27, "f")
        p.ellipse(sx - 2, sy + 9, 1.8, 1, "f")
        p.ellipse(sx + 2, sy + 12, 1.8, 1, "f")
        p.ellipse(sx, sy, 3.6, 3.6, "y")
        p.dots("k", (sx - 3, sy - 2), (sx + 3, sy - 2), (sx - 3, sy + 2), (sx + 3, sy + 2), only="y")
        p.ellipse(sx, sy, 1.6, 1.6, "m")
    # the bees
    for x, y, f in ((9, 12, False), (21, 5, True), (22, 15, True), (8, 3, False)):
        p.stamp(x, y, [" w ", "ydy"], flip=f)
    # lavender and tufts
    for x in (13, 15, 17, 19):
        p.rect(x, 26, x, 28, "l")
        p.put(x, 29, "f")
    for x in (1, 6, 25, 29):
        p.rect(x, 27, x, 28, "p")
        p.put(x, 29, "f")
    tuft(p, 2, 31, "i")
    tuft(p, 26, 31, "i")
    tuft(p, 11, 30, "i")
    return p


def mountain_lake():
    p = Pic(32, "k")
    p.ellipse(25.5, 4.5, 3, 3, "y")
    cloud(p, 1, 4, 7)
    # the far range, the peaks and their snow
    p.poly([(0, 18), (0, 11), (4, 8), (8, 12), (20, 12), (27, 8), (31, 11), (31, 18)], "l")
    p.poly([(3, 18), (14, 3), (25, 18)], "e")
    p.poly([(19, 18), (26, 10), (31, 15), (31, 18)], "e")
    p.poly([(14, 3), (11, 7), (13, 7), (14, 9), (16, 7), (18, 8)], "w")
    p.dots("w", (26, 10), (25, 11), (26, 11), (27, 11))
    p.dots("w", (12, 9), (11, 10), (16, 10), (17, 11), (22, 14), (9, 13), (8, 14))
    # firs along the far shore, the lake
    for cx, h in ((1, 6), (4, 4), (8, 5), (22, 4), (26, 6), (30, 5), (17, 3), (12, 3)):
        pine(p, cx, 19, h, trunk=None)
    p.rect(0, 19, 31, 19, "f")
    p.rect(0, 20, 31, 28, "b")
    for y in range(20, 25):
        hw = (25 - y) * 1.3
        p.span(y, int(14 - hw), int(14 + hw), "t")
    for y, x0, x1 in ((22, 22, 27), (25, 2, 6), (26, 18, 24), (21, 1, 3)):
        p.span(y, x0, x1, "k")
    # the near shore, a canoe, two firs
    p.land(lambda x: 28.5 - 1.5 * math.cos((x - 15.5) / 6.0), "g")
    p.stamp(12, 25, ["r      r", "rrrrrrrr", " mmmmmm "])
    pine(p, 3, 30, 13)
    pine(p, 28, 31, 11)
    p.dots("y", (9, 30), (20, 31), (23, 29))
    return p


def treehouse():
    p = Pic(32, "k")
    cloud(p, 0, 16, 6)
    cloud(p, 25, 19, 6)
    p.rect(0, 27, 31, 31, "g")
    # the trunk, the boughs
    p.rect(13, 12, 18, 28, "m")
    p.dots("m", (12, 27), (12, 28), (19, 27), (19, 28), (11, 28), (20, 28))
    p.rect(18, 12, 18, 28, "d")
    p.dots("d", (15, 23), (15, 24), (14, 26))
    p.line(18, 14, 27, 11, "m")
    p.line(13, 15, 4, 12, "m")
    # the canopy
    p.ellipse(15.5, 6, 15.5, 7, "f")
    p.ellipse(4, 10, 4.5, 3, "f")
    p.ellipse(27, 10, 4.5, 3, "f")
    for cx, cy, rx, ry in ((8, 3, 5, 1.8), (22, 2.5, 4.5, 1.5), (3.5, 8.5, 2.5, 1), (27, 8, 2.6, 1)):
        p.ellipse(cx, cy, rx, ry, "g")
    # the house
    p.rect(8, 11, 22, 18, "n")
    for y in (13, 16):
        p.span(y, 8, 22, "c")
    p.taper(15, 5, 10, 2, 9, "r")
    p.span(10, 6, 24, "d")
    p.rect(10, 13, 13, 16, "m")
    p.rect(11, 14, 12, 15, "y")
    p.rect(17, 13, 20, 18, "m")
    p.put(18, 16, "y")
    p.rect(6, 19, 24, 19, "m")
    p.span(20, 6, 24, "d")
    # the ladder, the swing
    for y in range(21, 28):
        p.put(14, y, "c")
        p.put(17, y, "c")
        if y % 2 == 0:
            p.span(y, 15, 16, "c")
    p.rect(26, 12, 26, 22, "d")
    p.stamp(25, 22, ["ddd", "d d", "ddd"])
    # the garden
    daisy(p, 4, 29)
    daisy(p, 24, 30)
    p.dots("r", (8, 30), (29, 28), (1, 31))
    tuft(p, 9, 28, "i")
    tuft(p, 20, 31, "i")
    tuft(p, 28, 31, "i")
    return p


def bear():
    p = Pic(32, "k")
    cloud(p, 12, 3, 8)
    # firs behind, the glade
    for cx, base, h in ((2, 19, 14), (7, 19, 9), (29, 19, 15), (24, 19, 10)):
        pine(p, cx, base, h, trunk=None)
    p.rect(0, 19, 31, 31, "g")
    p.land(lambda x: 28 + 1.5 * math.sin(x / 5.0), "i")
    # the bear
    p.ellipse(10.5, 6.5, 2.2, 2.2, "m")
    p.ellipse(20.5, 6.5, 2.2, 2.2, "m")
    p.ellipse(15.5, 21, 7.2, 7, "m")
    p.ellipse(15.5, 10.5, 5.8, 5, "m")
    p.ellipse(9.5, 27.4, 3, 2.3, "m")
    p.ellipse(21.5, 27.4, 3, 2.3, "m")
    p.outline("m", "d", over="kfgiw")
    p.dots("n", (10, 6), (11, 6), (20, 6), (21, 6))
    p.ellipse(15.5, 12.4, 2.8, 2.2, "n")
    p.dots("d", (15, 11), (16, 11), (15, 13), (16, 13), (13, 9), (18, 9))
    p.ellipse(15.5, 22, 4.4, 4.6, "n")
    p.ellipse(9.5, 27.6, 1.6, 1.2, "n")
    p.ellipse(21.5, 27.6, 1.6, 1.2, "n")
    # the honey pot in its paws
    p.ellipse(15.5, 21.8, 3.6, 3.3, "o")
    p.span(18, 12, 19, "y")
    p.span(19, 13, 18, "y")
    p.dots("y", (14, 20), (14, 21), (17, 20))
    p.rect(14, 22, 17, 23, "c")
    p.outline("oy", "d", over="nm", box=(9, 16, 22, 27))
    p.ellipse(11, 21.5, 1.6, 2, "m")
    p.ellipse(20, 21.5, 1.6, 2, "m")
    # bees, flowers
    for x, y, f in ((23, 12, True), (5, 14, False), (25, 22, True)):
        p.stamp(x, y, [" w ", "ydy"], flip=f)
    daisy(p, 3, 24)
    daisy(p, 28, 26)
    p.dots("r", (1, 29), (2, 29), (26, 30), (27, 30), (5, 21), (29, 21))
    return p


def snowy_cabin():
    p = Pic(32, "b")
    p.rect(0, 0, 31, 7, "u")
    p.ellipse(26, 4, 2.3, 2.3, "c")
    p.dots("y", (2, 2), (8, 5), (14, 1), (19, 4), (4, 10), (29, 11), (11, 9), (30, 1))
    # moonlit hills, the snow
    p.land(lambda x: 17 + 1.6 * math.sin(x / 4.0 + 0.5), "k")
    p.land(lambda x: 23.5 + 1.0 * math.cos((x - 15) / 5.0), "w")
    # the cabin
    p.rect(20, 6, 21, 12, "r")
    p.span(5, 20, 21, "w")
    p.dots("e", (21, 3), (22, 2), (22, 1), (23, 0))
    p.rect(8, 15, 23, 24, "m")
    for y in (17, 20, 23):
        p.span(y, 8, 23, "d")
    p.taper(15.5, 8, 14, 2, 10, "w")
    p.span(14, 5, 26, "e")
    p.rect(14, 18, 17, 24, "r")
    p.put(16, 21, "y")
    for x in (10, 20):
        p.rect(x - 1, 17, x + 2, 21, "d")
        p.rect(x, 18, x + 1, 20, "y")
    p.rect(14, 10, 17, 12, "m")
    p.rect(15, 11, 16, 12, "y")
    # light on the snow, a path, the firs
    p.span(25, 9, 12, "c")
    p.span(25, 19, 22, "c")
    p.taper(15.5, 25, 31, 2, 4, "k")
    pine(p, 3, 25, 14)
    pine(p, 28, 26, 15)
    for cx, top, base in ((3, 11, 25), (28, 11, 26)):
        for y in range(top, base, 3):
            hw = (y - top) // 3
            p.span(y, cx - hw, cx + max(0, hw - 1), "w", only="f")
    for y, x0, x1 in ((28, 1, 7), (30, 22, 29), (27, 22, 25)):
        p.span(y, x0, x1, "k")
    return p


# ---------------------------------------------------------------- the bank

# (band, id, English name for the locale table, painter)
PICTURES = [
    (2, "cottage", cottage),
    (2, "night_owl", night_owl),
    (2, "bunny_meadow", bunny_meadow),
    (2, "pumpkin_patch", pumpkin_patch),
    (2, "duck_pond", duck_pond),
    (2, "balloon_ride", balloon_ride),
    (2, "sailing_day", sailing_day),
    (2, "apple_orchard", apple_orchard),
    (2, "snow_day", snow_day),
    (2, "campfire_night", campfire_night),
    (2, "autumn_hedgehog", autumn_hedgehog),
    (2, "tulip_fields", tulip_fields),
    (3, "cat_in_box", cat_in_box),
    (3, "woodland_fox", woodland_fox),
    (3, "red_barn", red_barn),
    (3, "koi_pond", koi_pond),
    (3, "mushroom_house", mushroom_house),
    (3, "lighthouse", lighthouse),
    (3, "sheep_hill", sheep_hill),
    (3, "bee_garden", bee_garden),
    (3, "mountain_lake", mountain_lake),
    (3, "treehouse", treehouse),
    (3, "bear", bear),
    (3, "snowy_cabin", snowy_cabin),
]


def stats(band, rows):
    n = SIZES[band]
    flat = "".join(rows)
    used = sorted(set(flat) - {"."}, key=lambda c: -flat.count(c))
    most = used[0] if used else "."
    return {
        "colours": len(used),
        "fill": sum(c != "." for c in flat) / float(n * n),
        "most": most,
        "share": flat.count(most) / float(n * n),
        "used": "".join(used),
    }


def problems(band, pid, rows):
    n = SIZES[band]
    out = []
    if len(rows) != n or any(len(r) != n for r in rows):
        return ["not %d x %d" % (n, n)]
    if set("".join(rows)) - set(PALETTE) - {"."}:
        out.append("unknown chars %s" % sorted(set("".join(rows)) - set(PALETTE) - {"."}))
    s = stats(band, rows)
    lo, hi = COLOURS[band]
    if not lo <= s["colours"] <= hi:
        out.append("%d colours, wants %d-%d" % (s["colours"], lo, hi))
    if not FILL[0] <= s["fill"] <= FILL[1]:
        out.append("%.0f%% filled" % (s["fill"] * 100))
    if s["share"] >= MOST:
        out.append("%s is %.0f%% of it" % (s["most"], s["share"] * 100))
    flat = "".join(rows)
    few = ["%s %d" % (c, flat.count(c)) for c in s["used"] if flat.count(c) < LEAST]
    if few:
        out.append("under %d pegs: %s" % (LEAST, ", ".join(few)))
    return out


def paint_all(only=None):
    bands = {2: [], 3: []}
    bad = 0
    for band, pid, fn in PICTURES:
        if only and pid not in only:
            continue
        rows = fn().rows()
        s = stats(band, rows)
        errs = problems(band, pid, rows)
        bad += len(errs)
        print("band %d  %-18s %2d colours  %3.0f%% filled  %s %2.0f%%  %s%s" % (
            band, pid, s["colours"], s["fill"] * 100, s["most"], s["share"] * 100, s["used"],
            "   <-- " + "; ".join(errs) if errs else ""))
        bands[band].append({"id": pid, "name": "PG_PIC_" + pid.upper(), "rows": rows})
    return bands, bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bank", default=str(BANK), help="the bank whose bands 0 and 1 are kept")
    ap.add_argument("--out", help="where to write (default: the bank itself)")
    ap.add_argument("--list", action="store_true", help="print the table and write nothing")
    ap.add_argument("--only", nargs="*", help="paint only these ids (for a look; never the bank itself)")
    ap.add_argument("--force", action="store_true", help="write even with a rule broken")
    a = ap.parse_args()
    bands, bad = paint_all(a.only)
    print("%d pictures painted, %d problems" % (sum(len(v) for v in bands.values()), bad))
    if a.list:
        return 1 if bad else 0
    if bad and not a.force:
        print("nothing written")
        return 1
    out = Path(a.out) if a.out else Path(a.bank)
    if a.only and out.resolve() == BANK.resolve():
        print("--only never writes the bank itself; give --out")
        return 1
    bank = json.loads(Path(a.bank).read_text())
    bank["bands"][2] = bands[2]
    bank["bands"][3] = bands[3]
    out.write_text(json.dumps(bank, indent=1, ensure_ascii=False) + "\n")
    print("wrote %s" % out)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
