"""Render one carved wood sign per puzzle from art/sign.blend.

Run from a shell:

    /Applications/Blender.app/Contents/MacOS/Blender -b art/sign.blend \
        --python tools/build_signs.py

Every puzzle in ui/registry.gd gets assets/signs/<id>.png: the sign's plank,
leaves and screws exactly as modelled, with the title and motto swapped in.
The .blend is the source -- this only sets two Text bodies and renders, so the
board itself can only be changed by editing art/sign.blend.

The title is shrunk to fit the plank rather than the plank stretched to the
title, so all twelve signs come out the same size and the menu's column stays
even. One line per sign: "OK <id> <path> <bytes>", with a "FIT <id>: ..." line
first when a title or motto had to be shrunk to fit the board.
"""

import re
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "signs"
REGISTRY = ROOT / "ui" / "registry.gd"

# The widest the lettering may run, in Blender units. What binds is not the
# plank (1.90 across, 1.58 of it flat inside the corner radius) but the leaf
# sprigs, which are rooted at x = +-0.79 and reach outward from there: a title
# wider than about 1.58 runs its last letter into the right-hand sprig. These
# stop short of the roots instead.
MAX_TITLE_W = 1.44
MAX_MOTTO_W = 1.40
# The sizes the sign was modelled at. A line only ever comes down from here.
BASE_TITLE = 0.30
BASE_MOTTO = 0.095
# Below this the shrink has gone far enough to be worth a word.
FIT_WARN = 0.97


def entries(text):
    """The (id, title, motto) of every puzzle in registry.gd, in menu order."""
    out = []
    for block in re.findall(r"\{(.*?)\}", text, re.S):
        got = {}
        for key in ("id", "title", "motto"):
            m = re.search(r'"%s"\s*:\s*"((?:[^"\\]|\\.)*)"' % key, block)
            if m:
                got[key] = m.group(1)
        if len(got) == 3:
            out.append((got["id"], got["title"], got["motto"]))
    return out


def width_of(ob):
    """The object's rendered width, with the text's own geometry evaluated."""
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    return ob.evaluated_get(dg).dimensions.x


def fit(ob, body, base, limit):
    """Sets the text and brings the size down until it fits. Returns the ratio."""
    ob.data.body = body
    ob.data.size = base
    # Width is very nearly linear in size, but the faux-bold offset is not, so
    # this closes the gap rather than assuming one step lands.
    for _ in range(6):
        w = width_of(ob)
        if w <= limit:
            break
        ob.data.size *= limit / w * 0.995
    return ob.data.size / base


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    title = bpy.data.objects["Sign_Title"]
    motto = bpy.data.objects["Sign_Motto"]

    puzzles = entries(REGISTRY.read_text())
    if not puzzles:
        sys.stderr.write("no puzzles found in %s\n" % REGISTRY)
        sys.exit(1)

    for pid, title_text, motto_text in puzzles:
        t_ratio = fit(title, title_text.upper(), BASE_TITLE, MAX_TITLE_W)
        m_ratio = fit(motto, motto_text.upper(), BASE_MOTTO, MAX_MOTTO_W)
        if min(t_ratio, m_ratio) < FIT_WARN:
            print("FIT %s: title %.0f%%, motto %.0f%% of the modelled size"
                  % (pid, t_ratio * 100, m_ratio * 100))
        path = OUT / ("%s.png" % pid)
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        print("OK %s %s %d" % (pid, path.relative_to(ROOT), path.stat().st_size))


main()
