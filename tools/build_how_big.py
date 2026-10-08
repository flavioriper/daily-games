#!/usr/bin/env python3
"""How Big? -- silhouettes and the size table, from sources to shipped data.

Reads   tools/how_big/items.json      the table: one row per item, its size
                                      facts and where its shape comes from
        tools/how_big/src/<id>.svg    the animal silhouettes (PhyloPic, CC0 or
                                      Public Domain Mark only -- asserted here)
Writes  content/how_big_shapes.json   {"id": {"w","h","loops","tris"}}
        content/how_big.json          {"items": [...]} without the shape block
        tools/how_big/SOURCES.md      one row per item: source, licence, URL
        a contact sheet PNG           with --sheet <path>

Objects (balls, door, bicycle, car, bus) are not downloaded: they are built
below with shapely, one function each, named in the row's shape.made.

Every shape ends as: larger bbox side = 1000, origin at the bbox's top-left,
y down, integer coordinates, rings + an earcut triangle list.

Setup (once; the venv is ignored by git):
    python3 -m venv tools/how_big/.venv
    tools/how_big/.venv/bin/pip install shapely mapbox-earcut svgelements pillow numpy

Run (-I because src/ holds downloaded files):
    tools/how_big/.venv/bin/python -I tools/build_how_big.py [--fetch] [--sheet out.png] [--only id,id]

--fetch downloads any missing src/<id>.svg from PhyloPic by the row's uuid.
"""
import json
import math
import os
import sys
import urllib.request

import mapbox_earcut
import numpy as np
import shapely
from shapely import affinity
from shapely.geometry import LineString, MultiPolygon, Point, Polygon, box
from shapely.ops import unary_union

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HB = os.path.join(ROOT, "tools", "how_big")
SRC = os.path.join(HB, "src")
OK_LICENCES = {
    "https://creativecommons.org/publicdomain/zero/1.0/": "CC0 1.0",
    "https://creativecommons.org/publicdomain/mark/1.0/": "Public Domain Mark 1.0",
}
SIDE = 1000
MAX_POINTS = 400
API = "https://api.phylopic.org"


# ---------------------------------------------------------------- svg -> polygon

def _rings(path):
    """Every subpath of an svgelements Path as a list of (x, y)."""
    from svgelements import Close, Line, Move
    out = []
    for sub in path.as_subpaths():
        pts = []
        for seg in sub:
            if isinstance(seg, Move):
                continue
            if isinstance(seg, (Line, Close)):
                if seg.start is not None and not pts:
                    pts.append((seg.start.x, seg.start.y))
                if seg.end is not None:
                    pts.append((seg.end.x, seg.end.y))
                continue
            if not pts:
                pts.append((seg.start.x, seg.start.y))
            for i in range(1, 13):
                p = seg.point(i / 12.0)
                pts.append((p.x, p.y))
        if len(pts) >= 3:
            out.append(pts)
    return out


def _is_light(fill):
    if fill is None or fill.value is None:
        return False
    return (fill.red + fill.green + fill.blue) / 3.0 > 200


def svg_polygon(path):
    """The black of an SVG as one shapely geometry. Each path fills even-odd
    (potrace's holes wind the other way, so nonzero agrees); a path filled
    near-white is cut out of what lies under it."""
    from svgelements import SVG, Path, Shape
    geom = Polygon()
    for el in SVG.parse(path, reify=True).elements():
        if not isinstance(el, Shape):
            continue
        fill = getattr(el, "fill", None)
        if fill is not None and fill.value is None:
            continue
        p = el if isinstance(el, Path) else Path(el)
        p.reify()
        part = Polygon()
        for ring in _rings(p):
            poly = Polygon(ring).buffer(0)
            part = part.symmetric_difference(poly)
        geom = geom.difference(part) if _is_light(fill) else geom.union(part)
    return geom


# ------------------------------------------------------------ authored objects
# Each returns a shapely geometry in any unit, y UP; build() flips it.

def _line(pts, w):
    return LineString(pts).buffer(w, cap_style="round", join_style="round")


def _round(poly, r):
    return poly.buffer(-r).buffer(2 * r).buffer(-r)


def _ngon(cx, cy, r, n, rot):
    return Polygon([(cx + r * math.cos(rot + i * math.tau / n),
                     cy + r * math.sin(rot + i * math.tau / n)) for i in range(n)])


def make_tennis_ball():
    R = 100.0
    disc = Point(0, 0).buffer(R, 64)
    seam = unary_union([
        Point(-148, 0).buffer(112, 64).exterior.buffer(4.5),
        Point(148, 0).buffer(112, 64).exterior.buffer(4.5),
    ])
    return disc.difference(seam.intersection(Point(0, 0).buffer(R - 7, 64)))


def make_football():
    R = 100.0
    disc = Point(0, 0).buffer(R, 72)
    inner = Point(0, 0).buffer(R - 5, 72)
    cuts = [_ngon(0, 0, 33, 5, math.pi / 2)]
    seams = []
    outer = []
    for k in range(5):
        a = math.pi / 2 + k * math.tau / 5
        # a neighbouring panel, foreshortened towards the rim
        pent = _ngon(0, 0, 34, 5, math.pi)          # a vertex pointing at the centre
        pent = affinity.scale(pent, 0.62, 1.0, origin=(0, 0))
        pent = affinity.translate(pent, 80, 0)
        pent = affinity.rotate(pent, math.degrees(a), origin=(0, 0))
        cuts.append(pent)
        outer.append(list(pent.exterior.coords)[:5])
        seams.append(((33 * math.cos(a), 33 * math.sin(a)), outer[-1][0]))
    for k in range(5):
        a, b = outer[k], outer[(k + 1) % 5]
        seams.append((a[4], b[1]))
    for k in range(5):
        for v in (outer[k][2], outer[k][3]):
            d = math.hypot(*v)
            seams.append((v, (v[0] / d * R, v[1] / d * R)))
    lines = unary_union([_line(s, 2.6) for s in seams])
    return disc.difference(unary_union(cuts + [lines]).intersection(inner))


def make_door():
    # A six-panel door leaf, 762 x 2032 mm drawn in cm.
    w, h = 76.2, 203.2
    leaf = box(0, 0, w, h)
    cuts = []
    for (y0, y1) in ((14, 62), (72, 138), (148, 189)):
        for (x0, x1) in ((9, 34), (42.2, 67.2)):
            ring = _round(box(x0, y0, x1, y1), 1.5)
            cuts.append(ring.difference(ring.buffer(-1.6)))
    cuts.append(Point(w - 5.5, 98).buffer(2.6, 24))
    return leaf.difference(unary_union(cuts))


def _wheel(cx, cy, r, hub):
    tyre = Point(cx, cy).buffer(r, 48)
    return tyre.difference(Point(cx, cy).buffer(hub, 32)).union(Point(cx, cy).buffer(hub * 0.45, 20))


def make_car():
    # A hatchback, 428 long x 146 tall (cm), nose to the right.
    body = Polygon([(6, 24), (2, 50), (4, 82), (14, 104), (34, 130), (72, 144), (150, 146),
                    (212, 141), (286, 101), (378, 88), (418, 72), (426, 46), (423, 24)])
    body = _round(body, 5)
    wheels = [(86, 31), (346, 31)]
    for (x, y) in wheels:
        body = body.difference(Point(x, y).buffer(37, 48))
    glass = [
        Polygon([(186, 103), (186, 135), (212, 134), (270, 103)]),
        Polygon([(104, 103), (104, 136), (178, 136), (178, 103)]),
        Polygon([(96, 103), (96, 135), (62, 130), (40, 103)]),
    ]
    body = body.difference(unary_union([_round(g, 2.5) for g in glass]))
    return unary_union([body] + [_wheel(x, y, 31, 15) for (x, y) in wheels])


def make_bus():
    # A 12 m low-floor city bus, 1200 x 310 (cm), nose to the right.
    body = _round(Polygon([(0, 30), (0, 300), (1150, 300), (1188, 280), (1200, 150), (1200, 30)]), 14)
    body = body.union(box(60, 300, 1000, 310).buffer(3))
    wheels = [(330, 48), (925, 48)]
    for (x, y) in wheels:
        body = body.difference(Point(x, y).buffer(57, 48))
    cuts = []
    x = 34
    for w in (120, 120, 120, 120):                      # glass behind the middle door
        cuts.append(box(x, 150, x + w, 258)); x += w + 12
    for dx in (0, 54):                                  # the middle door, two leaves
        cuts.append(box(x + dx, 52, x + dx + 46, 258))
    x += 112
    for w in (120, 120, 100):
        cuts.append(box(x, 150, x + w, 258)); x += w + 12
    for dx in (0, 44):                                  # the front door
        cuts.append(box(x + dx, 52, x + dx + 38, 258))
    cuts.append(Polygon([(1128, 130), (1128, 262), (1158, 262), (1180, 250), (1188, 130)]))  # windscreen
    body = body.difference(unary_union([_round(c, 4) for c in cuts]))
    return unary_union([body] + [_wheel(x, y, 48, 24) for (x, y) in wheels])


def make_bicycle():
    # A road bike, 173 long x ~100 tall (cm), nose to the right.
    r = 34.0
    rear, front = (34.0, 34.0), (139.0, 34.0)
    parts = []
    for (cx, cy) in (rear, front):
        rim = Point(cx, cy).buffer(r, 64).difference(Point(cx, cy).buffer(r - 3.6, 64))
        spokes = [_line([(cx, cy), (cx + (r - 2) * math.cos(a), cy + (r - 2) * math.sin(a))], 0.42)
                  for a in (i * math.tau / 12 + 0.13 for i in range(12))]
        parts += [rim, Point(cx, cy).buffer(2.6, 16)] + spokes
    bb, seat, head, crown = (72.0, 31.0), (61.0, 80.0), (118.0, 84.0), (123.0, 68.0)
    tube = 1.5
    parts += [
        _line([rear, bb], 1.2), _line([bb, seat], tube), _line([seat, rear], 1.1),
        _line([seat, head], tube), _line([bb, crown], tube + 0.2), _line([head, crown], tube + 0.2),
        _line([crown, (131, 52), front], 1.3),
        _line([seat, (58.3, 92)], 1.3),
        affinity.rotate(affinity.scale(Point(55.5, 93.5).buffer(1), 12.5, 2.4), 3),   # saddle
        _line([head, (116.6, 90.5), (126, 93.5)], 1.3),                            # stem
        _line([(126, 93.5), (133, 93), (136, 88), (133.5, 82.5), (128.5, 82)], 1.2),  # drop bar
        Point(*bb).buffer(8.5, 32).difference(Point(*bb).buffer(5.6, 24)), Point(*bb).buffer(2.4, 16),
        _line([bb, (78.5, 15.5)], 1.1), _line([(74.5, 14.6), (83.5, 14.6)], 1.3),        # crank, pedal
        _line([bb, (65.5, 46.5)], 1.1), _line([(61.5, 47.4), (69.5, 47.4)], 1.3),
        _line([(34, 37.2), (72, 39.3)], 0.45), _line([(34, 30.8), (72, 22.6)], 0.45),    # chain
    ]
    return unary_union(parts)


MAKERS = {f[5:]: g for f, g in list(globals().items()) if f.startswith("make_")}


# ------------------------------------------------------------------- pipeline

def _polys(g):
    if g.is_empty:
        return []
    if g.geom_type == "Polygon":
        return [g]
    if g.geom_type in ("MultiPolygon", "GeometryCollection"):
        return [p for q in g.geoms for p in _polys(q)]
    return []


def _count(g):
    return sum(len(p.exterior.coords) - 1 + sum(len(i.coords) - 1 for i in p.interiors) for p in _polys(g))


def _despeck(g, min_area):
    out = []
    for p in _polys(g):
        if p.area < min_area:
            continue
        out.append(Polygon(p.exterior, [i for i in p.interiors if Polygon(i).area >= min_area]))
    return unary_union(out)


def normalise(g, shape):
    """Any geometry (y down) -> integer geometry in the 1000-box."""
    def fit(g):
        x0, y0, x1, y1 = g.bounds
        s = SIDE / max(x1 - x0, y1 - y0)
        return affinity.scale(affinity.translate(g, -x0, -y0), s, s, origin=(0, 0))

    g = shapely.make_valid(g)
    if shape.get("rotate"):
        g = affinity.rotate(g, shape["rotate"], origin="centroid")
    if shape.get("flip"):
        g = affinity.scale(g, -1, 1, origin=(0, 0))
    g = fit(g)
    if shape.get("crop"):                      # [x0, y0, x1, y1] fractions of the bbox, y down
        x0, y0, x1, y1 = g.bounds
        c = shape["crop"]
        g = fit(g.intersection(box(x0 + c[0] * (x1 - x0), y0 + c[1] * (y1 - y0),
                                   x0 + c[2] * (x1 - x0), y0 + c[3] * (y1 - y0))))
    if shape.get("fill_holes"):
        g = unary_union([Polygon(p.exterior) for p in _polys(g)])
    r = shape.get("open", 0.0)                 # a morphological open: shaves hairs and whiskers
    if r:
        g = g.buffer(-r).buffer(r)
    r = shape.get("close", 0.0)                # and a close: heals hairline gaps
    if r:
        g = g.buffer(r).buffer(-r)
    if shape.get("largest"):
        g = max(_polys(g), key=lambda p: p.area)
    area = unary_union(_polys(g)).area
    g = fit(_despeck(g, shape.get("speck", 0.0005) * area))
    tol = shape.get("tol", 1.5)
    while True:
        s = fit(shapely.make_valid(g.simplify(tol, preserve_topology=True)))
        s = shapely.set_precision(s, 1.0)
        s = _despeck(s, 0.0005 * area)
        if _count(s) <= shape.get("max_points", MAX_POINTS):
            break
        tol *= 1.25
    x0, y0, x1, y1 = s.bounds
    s = affinity.translate(s, -x0, -y0)
    return s, tol


def triangulate(g):
    loops, tris, tri_area = [], [], 0.0
    for p in _polys(g):
        rings = [list(p.exterior.coords)[:-1]] + [list(i.coords)[:-1] for i in p.interiors]
        verts = np.array([v for r in rings for v in r], dtype=np.float64).reshape(-1, 2)
        ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
        idx = mapbox_earcut.triangulate_float64(verts, ends)
        for r in rings:
            loops.append([int(round(c)) for v in r for c in v])
        for a, b, c in idx.reshape(-1, 3):
            (ax, ay), (bx, by), (cx, cy) = verts[a], verts[b], verts[c]
            tri_area += abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2.0
            tris += [int(ax), int(ay), int(bx), int(by), int(cx), int(cy)]
    return loops, tris, tri_area


def fetch(item):
    sh = item["shape"]
    req = urllib.request.Request(API + "/images/" + sh["phylopic"],
                                 headers={"User-Agent": "how-big-build/1.0"})
    meta = json.load(urllib.request.urlopen(req, timeout=60))
    lic = meta["_links"]["license"]["href"]
    assert lic in OK_LICENCES, "%s: licence %s is not CC0/PDM" % (item["id"], lic)
    assert lic == sh["licence"], "%s: licence changed upstream" % item["id"]
    data = urllib.request.urlopen(urllib.request.Request(
        meta["_links"]["vectorFile"]["href"], headers={"User-Agent": "how-big-build/1.0"}), timeout=60).read()
    with open(os.path.join(SRC, item["id"] + ".svg"), "wb") as f:
        f.write(data)


def build(item):
    sh = item["shape"]
    if "made" in sh:
        g = affinity.scale(MAKERS[sh["made"]](), 1, -1, origin=(0, 0))
    else:
        assert sh["licence"] in OK_LICENCES, "%s: licence %s is not CC0/PDM" % (item["id"], sh["licence"])
        g = svg_polygon(os.path.join(SRC, item["id"] + ".svg"))
    g, tol = normalise(g, sh)
    loops, tris, tri_area = triangulate(g)
    assert abs(tri_area - g.area) <= 0.01 * g.area, "%s: triangles cover %.0f of %.0f" % (item["id"], tri_area, g.area)
    x0, y0, x1, y1 = g.bounds
    w, h = int(round(x1)), int(round(y1))
    assert (x0, y0) == (0, 0) and max(w, h) == SIDE, "%s: bbox %s" % (item["id"], g.bounds)
    n = sum(len(l) // 2 for l in loops)
    print("%-12s %4dx%-4d  %3d pts  %3d tris  %d loops  tol %.2f" % (item["id"], w, h, n, len(tris) // 6, len(loops), tol), flush=True)
    return {"w": w, "h": h, "loops": loops, "tris": tris}


# ------------------------------------------------------------------- outputs

def size_text(m):
    if m < 0.01:
        return "%.1f mm" % (m * 1000)
    if m < 1:
        return "%.1f cm" % (m * 100)
    return "%.2f m" % m


def write_sources(items):
    rows = ["# How Big? -- where each silhouette came from", "",
            "Written by `tools/build_how_big.py` from `items.json`; edit that, not this.",
            "PhyloPic shapes are accepted only under CC0 1.0 or the Public Domain Mark,",
            "so the game owes no attribution. Objects are drawn by the tool itself.", "",
            "| id | source | taxon / what | by | licence | URL |", "|---|---|---|---|---|---|"]
    for it in items:
        sh = it["shape"]
        if "made" in sh:
            rows.append("| %s | authored | %s | this project (`make_%s` in the tool) | own work | -- |" % (it["id"], it["name_en"], sh["made"]))
        else:
            rows.append("| %s | PhyloPic | *%s* | %s | %s | https://www.phylopic.org/images/%s |" % (
                it["id"], sh["taxon"], sh.get("by") or "--", OK_LICENCES[sh["licence"]], sh["phylopic"]))
    with open(os.path.join(HB, "SOURCES.md"), "w") as f:
        f.write("\n".join(rows) + "\n")


def write_sheet(items, shapes, path):
    from PIL import Image, ImageDraw, ImageFont
    T, PAD, CAP, COLS = 340, 34, 46, 6
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
    except OSError:
        font = ImageFont.load_default()
    per = COLS * 5
    for page in range(0, len(items), per):
        chunk = items[page:page + per]
        rows = (len(chunk) + COLS - 1) // COLS
        img = Image.new("RGB", (COLS * T, rows * (T + CAP)), (246, 240, 224))
        d = ImageDraw.Draw(img)
        for i, it in enumerate(chunk):
            s = shapes[it["id"]]
            ox, oy = (i % COLS) * T + PAD, (i // COLS) * (T + CAP) + PAD
            k = (T - 2 * PAD) / float(SIDE)
            ox += (T - 2 * PAD - s["w"] * k) / 2
            oy += (T - 2 * PAD - s["h"] * k) / 2
            t = s["tris"]
            for j in range(0, len(t), 6):
                d.polygon([(ox + t[j + a] * k, oy + t[j + a + 1] * k) for a in (0, 2, 4)], fill=(20, 20, 20))
            red, grey = (214, 40, 40), (120, 130, 200)
            if it["measure"] == "tall":
                x = ox - 12
                for f in range(11):                     # a tick every tenth, 0 at the ground
                    y = oy + s["h"] * k * (1 - f / 10.0)
                    d.line([(x - 12, y), (x - 8, y)], fill=grey)
                ya, yb = (oy + s["h"] * k * (1 - it[e]) for e in ("from", "to"))
                d.line([(x, ya), (x, yb)], fill=red, width=2)
                for y in (ya, yb):
                    d.line([(x - 5, y), (x + 5, y)], fill=red, width=2)
                    d.line([(x + 5, y), (ox + s["w"] * k, y)], fill=(214, 40, 40), width=1)
            else:
                y = oy + s["h"] * k + 12
                for f in range(11):
                    x = ox + s["w"] * k * f / 10.0
                    d.line([(x, y + 8), (x, y + 12)], fill=grey)
                xa, xb = (ox + s["w"] * k * it[e] for e in ("from", "to"))
                d.line([(xa, y), (xb, y)], fill=red, width=2)
                for x in (xa, xb):
                    d.line([(x, y - 5), (x, y + 5)], fill=red, width=2)
                    d.line([(x, y - 5), (x, oy)], fill=(214, 40, 40), width=1)
            cx, cy = (i % COLS) * T + 6, (i // COLS) * (T + CAP) + T + 4
            n = sum(len(l) // 2 for l in s["loops"])
            d.text((cx, cy), "%s  %d pts  %s" % (it["id"], n, it["kind"]), fill=(0, 0, 0), font=font)
            d.text((cx, cy + 16), "%s %s %s  [%.2f-%.2f]" % (size_text(it["size_m"]), it["measure"], it["what_en"], it["from"], it["to"]), fill=red, font=font)
        out = path if page == 0 else path.replace(".png", "_%d.png" % (page // per + 1))
        img.save(out)
        print("sheet", out)


def main(argv):
    with open(os.path.join(HB, "items.json")) as f:
        items = json.load(f)["items"]
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
    ids = [it["id"] for it in items]
    assert len(ids) == len(set(ids)), "duplicate id"
    shapes_path = os.path.join(ROOT, "content", "how_big_shapes.json")
    shapes = {}
    if only and os.path.exists(shapes_path):
        with open(shapes_path) as f:
            shapes = json.load(f)
    for it in items:
        if only and it["id"] not in only:
            continue
        if "phylopic" in it["shape"] and "--fetch" in argv and not os.path.exists(os.path.join(SRC, it["id"] + ".svg")):
            fetch(it)
        shapes[it["id"]] = build(it)
    shapes = {i: shapes[i] for i in ids if i in shapes}
    with open(shapes_path, "w") as f:
        f.write("{\n" + ",\n".join('"%s": %s' % (k, json.dumps(v, separators=(",", ":"))) for k, v in shapes.items()) + "\n}\n")
    table = []
    for it in sorted(items, key=lambda it: it["size_m"]):
        assert it["kind"] in ("insect", "animal", "sea", "dino", "object", "person"), it["id"]
        assert it["measure"] in ("tall", "long") and 0.0 <= it["from"] < it["to"] <= 1.0, it["id"]
        assert it["source"].startswith("https://") and len(it["fact_en"]) <= 95, it["id"]
        row = {"id": it["id"], "label": "HB_ITEM_" + it["id"].upper()}
        row.update({k: it[k] for k in ("name_en", "kind", "size_m", "measure", "what_en", "from", "to", "fact_en", "source")})
        table.append(row)
    with open(os.path.join(ROOT, "content", "how_big.json"), "w") as f:
        f.write('{"items": [\n' + ",\n".join("  " + json.dumps(r, ensure_ascii=False) for r in table) + "\n]}\n")
    write_sources(items)
    print("shapes %.0f KB, %d items" % (os.path.getsize(shapes_path) / 1024.0, len(shapes)))
    if "--sheet" in argv:
        write_sheet(sorted(items, key=lambda it: it["size_m"]), shapes, argv[argv.index("--sheet") + 1])


if __name__ == "__main__":
    main(sys.argv[1:])
