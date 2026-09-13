"""Export selected Blender objects to the game's model slots.

Run inside Blender (Scripting tab) or from a shell:

    /Applications/Blender.app/Contents/MacOS/Blender -b my.blend \
        --python tools/blender_export.py -- [ObjectName ...]

Each object is checked against docs/art/blender-contract.md and, if it passes,
written to assets/models/<object name lowercased>.glb. One line per object:
"OK <slot> <path> <bytes>" or "SKIP <name>: <rule broken>". Exit status is 1
when anything was skipped.
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "models"
TOLERANCE = 0.001
FOOTPRINT = 1.0
MAX_HEIGHT = 0.6
UNBOUNDED = {"platform", "water"}


def world_bounds(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    if not pts:
        return None, None
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def problems(obj):
    """Every contract rule the object breaks, as short strings."""
    found = []
    if obj.type != "MESH":
        return ["not a mesh"]
    if any(abs(a) > 1e-6 for a in obj.rotation_euler):
        found.append("rotation not applied")
    if any(abs(s - 1.0) > 1e-6 for s in obj.scale):
        found.append("scale not applied")
    lo, hi = world_bounds(obj)
    if lo is None:
        return ["mesh has no vertices"]
    origin = obj.matrix_world.translation
    if abs(lo.z - origin.z) > TOLERANCE:
        found.append("base not at origin height (lowest vertex %.3f above origin)" % (lo.z - origin.z))
    centre_x = (lo.x + hi.x) * 0.5 - origin.x
    centre_y = (lo.y + hi.y) * 0.5 - origin.y
    if abs(centre_x) > TOLERANCE or abs(centre_y) > TOLERANCE:
        found.append("origin not at footprint centre (off by %.3f, %.3f)" % (centre_x, centre_y))
    if not all(p.use_smooth for p in obj.data.polygons):
        found.append("not shaded smooth")
    slot = obj.name.lower()
    if slot not in UNBOUNDED:
        if hi.x - lo.x > FOOTPRINT + TOLERANCE or hi.y - lo.y > FOOTPRINT + TOLERANCE:
            found.append("footprint %.2f x %.2f exceeds 1 x 1" % (hi.x - lo.x, hi.y - lo.y))
        if hi.z - lo.z > MAX_HEIGHT + TOLERANCE:
            found.append("height %.2f exceeds %.1f" % (hi.z - lo.z, MAX_HEIGHT))
    return found


def export(obj):
    slot = obj.name.lower()
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (slot + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj
    parked = obj.location.copy()
    obj.location = Vector((0.0, 0.0, 0.0))
    bpy.context.view_layer.update()
    try:
        bpy.ops.export_scene.gltf(
            filepath=str(path),
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_animations=False,
        )
    finally:
        obj.location = parked
        bpy.context.view_layer.update()
    return path


def pick_objects(names):
    if names:
        missing = [n for n in names if bpy.data.objects.get(n) is None]
        if missing:
            raise SystemExit("no such object: " + ", ".join(missing))
        return [bpy.data.objects[n] for n in names]
    selected = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if selected:
        return selected
    return [o for o in bpy.data.objects if o.type == "MESH" and o.parent is None]


def main():
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    skipped = 0
    for obj in pick_objects(names):
        bad = problems(obj)
        if bad:
            skipped += 1
            print("SKIP %s: %s" % (obj.name, "; ".join(bad)))
            continue
        path = export(obj)
        print("OK %s %s %d" % (obj.name.lower(), path, path.stat().st_size))
    if skipped:
        print("%d object(s) skipped" % skipped)
        if bpy.app.background:
            sys.exit(1)


main()
