"""Export selected Blender objects to the game's model slots.

Run inside Blender (Scripting tab) or from a shell:

    /Applications/Blender.app/Contents/MacOS/Blender -b my.blend \
        --python tools/blender_export.py -- [ObjectName | CollectionName ...]

Each object is checked against docs/art/blender-contract.md and, if it passes,
written to assets/models/<object name lowercased>.glb. A name that matches a
*collection* exports as an assembly: every mesh in it goes into one
assets/models/<collection name lowercased>.glb, checked as a single piece
(each mesh for shading and modifiers, the union for footprint and origin). One line per object:
"OK <slot> <path> <bytes>" or "SKIP <name>: <rule broken>", with a
"WARN <name>: ..." line first when something is worth saying but does not stop
the export. Exit status is 1 when anything was skipped.
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "models"
TOLERANCE = 0.001

# (max footprint x, max footprint y, max height), from the contract table
LIMITS = {
    "tile": (1.0, 1.0, 0.75),  # equilateral prism, side 0.84 -> 0.727 tall
    "emblem_sun": (0.6, 0.6, 0.08),
    "emblem_moon": (0.6, 0.6, 0.08),
    "empty_mark": (0.2, 0.2, 0.04),
    "rim_edge": (1.0, 0.5, 0.12),
    "rim_corner": (0.5, 0.5, 0.12),
}
DEFAULT_LIMIT = (1.0, 1.0, 0.6)  # unknown slots
# Mascots are assemblies and stand taller than a piece; one budget for all of
# them, so a new character needs no new row here.
MASCOT_PREFIX = "mascot_"
MASCOT_LIMIT = (1.4, 1.4, 1.4)
UNBOUNDED = {"platform", "water"}  # no maximum; platform has its own exact check
# Slots the board tiles edge to edge, so the footprint must be exact, not
# merely within budget: the platform is stretched by (cols + 1, rows + 1) and
# the rim pieces are laid one per cell, where a short piece leaves a gap.
EXACT = {"platform": (1.0, 1.0), "rim_edge": (1.0, 0.5), "rim_corner": (0.5, 0.5)}


def limit_for(slot):
    if slot.startswith(MASCOT_PREFIX):
        return MASCOT_LIMIT
    return LIMITS.get(slot, DEFAULT_LIMIT)


def world_bounds(obj, mesh):
    pts = [obj.matrix_world @ v.co for v in mesh.vertices]
    if not pts:
        return None, None
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def mesh_problems(obj):
    """Rules about one mesh: shading, normals, modifiers, applied transforms.
    Says nothing about where the mesh sits or how big it is."""
    found = []
    if obj.type != "MESH":
        return ["not a mesh"]
    if obj.parent is not None:
        found.append("object is parented; clear parent (keep transform) before export")
    if any(abs(a) > 1e-6 for a in obj.rotation_euler):
        found.append("rotation not applied")
    if any(abs(s - 1.0) > 1e-6 for s in obj.scale):
        found.append("scale not applied")
    # The export applies modifiers, so measure what the exporter will write,
    # not the pre-modifier cage: a Bevel with Harden Normals adds split
    # normals and a Solidify or Displace grows the mesh past its budget.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.data
    if not mesh.vertices:
        return ["mesh has no vertices"]
    if not all(p.use_smooth for p in mesh.polygons):
        found.append("not shaded smooth")
    if mesh.has_custom_normals:
        found.append("custom split normals (clear them: Mesh > Normals > Clear Custom Split Normals Data)")
    for mod in obj.modifiers:
        if mod.type in ("EDGE_SPLIT", "WEIGHTED_NORMAL"):
            found.append("%s modifier splits vertices, remove it" % mod.type)
        elif mod.type == "NODES" and mod.node_group and mod.node_group.name.startswith("Smooth by Angle"):
            found.append("Smooth by Angle modifier splits vertices, remove it")
        elif mod.type == "BEVEL" and getattr(mod, "harden_normals", False):
            found.append("Bevel with Harden Normals writes split normals, turn it off")
    return found


def placement_problems(slot, lo, hi, origin):
    """Rules about where a piece sits and how big it is, from its world bounds.
    One object or a whole assembly, measured the same way."""
    found = []
    if abs(lo.z - origin.z) > TOLERANCE:
        found.append("base not at origin height (lowest vertex %.3f above origin)" % (lo.z - origin.z))
    centre_x = (lo.x + hi.x) * 0.5 - origin.x
    centre_y = (lo.y + hi.y) * 0.5 - origin.y
    if abs(centre_x) > TOLERANCE or abs(centre_y) > TOLERANCE:
        found.append("origin not at footprint centre (off by %.3f, %.3f)" % (centre_x, centre_y))
    if slot in EXACT:
        exact_x, exact_y = EXACT[slot]
        if abs((hi.x - lo.x) - exact_x) > TOLERANCE or abs((hi.y - lo.y) - exact_y) > TOLERANCE:
            found.append("%s footprint must be exactly %.1f x %.1f (got %.2f x %.2f)" % (slot, exact_x, exact_y, hi.x - lo.x, hi.y - lo.y))
        # The platform's height is free (the board never stacks on it); the
        # rim pieces keep the height budget from LIMITS.
        if slot in LIMITS and hi.z - lo.z > LIMITS[slot][2] + TOLERANCE:
            found.append("height %.2f exceeds %.2f" % (hi.z - lo.z, LIMITS[slot][2]))
    elif slot not in UNBOUNDED:
        limit_x, limit_y, limit_z = limit_for(slot)
        if hi.x - lo.x > limit_x + TOLERANCE or hi.y - lo.y > limit_y + TOLERANCE:
            found.append("footprint %.2f x %.2f exceeds %.1f x %.1f" % (hi.x - lo.x, hi.y - lo.y, limit_x, limit_y))
        if hi.z - lo.z > limit_z + TOLERANCE:
            found.append("height %.2f exceeds %.2f" % (hi.z - lo.z, limit_z))
    return found


def problems(obj):
    """Every contract rule a single-object slot breaks, as short strings."""
    found = mesh_problems(obj)
    if found and found[0] in ("not a mesh", "mesh has no vertices"):
        return found
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    lo, hi = world_bounds(eval_obj, eval_obj.data)
    return found + placement_problems(obj.name.lower(), lo, hi, obj.matrix_world.translation)


def assembly_problems(coll):
    """Same rules for a collection exported as one piece: every mesh is checked
    for shading and modifiers, the union of them for footprint and origin. The
    assembly's origin is the world origin, because that is what the .glb root
    becomes in the game."""
    found = []
    meshes = [o for o in coll.objects if o.type == "MESH"]
    if not meshes:
        return ["collection has no meshes"]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lo = hi = None
    for obj in meshes:
        for note in mesh_problems(obj):
            found.append("%s: %s" % (obj.name, note))
        eval_obj = obj.evaluated_get(depsgraph)
        o_lo, o_hi = world_bounds(eval_obj, eval_obj.data)
        if o_lo is None:
            continue
        lo = o_lo if lo is None else Vector((min(lo.x, o_lo.x), min(lo.y, o_lo.y), min(lo.z, o_lo.z)))
        hi = o_hi if hi is None else Vector((max(hi.x, o_hi.x), max(hi.y, o_hi.y), max(hi.z, o_hi.z)))
    if lo is None:
        return found + ["collection has no vertices"]
    return found + placement_problems(coll.name.lower(), lo, hi, Vector((0.0, 0.0, 0.0)))


def warnings(name):
    """Things worth saying out loud that do not stop the export."""
    slot = name.lower()
    if slot.startswith(MASCOT_PREFIX):
        return []
    if slot not in LIMITS and slot not in UNBOUNDED:
        return ["slot '%s' is not one the game loads (check for a .001 suffix)" % slot]
    return []


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


def export_assembly(coll):
    """Every mesh in the collection into one .glb named after the collection."""
    slot = coll.name.lower()
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (slot + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in coll.objects if o.type == "MESH"]
    for obj in meshes:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
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
    return path


def pick_objects(names):
    if names:
        missing = [n for n in names
                   if bpy.data.objects.get(n) is None and bpy.data.collections.get(n) is None]
        if missing:
            raise SystemExit("no such object or collection: " + ", ".join(missing))
        return [bpy.data.collections[n] if bpy.data.objects.get(n) is None else bpy.data.objects[n]
                for n in names]
    selected = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if selected:
        return selected
    return [o for o in bpy.data.objects if o.type == "MESH" and o.parent is None]


def main():
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    skipped = 0
    for target in pick_objects(names):
        is_assembly = isinstance(target, bpy.types.Collection)
        bad = assembly_problems(target) if is_assembly else problems(target)
        if bad:
            skipped += 1
            print("SKIP %s: %s" % (target.name, "; ".join(bad)))
            continue
        for note in warnings(target.name):
            print("WARN %s: %s" % (target.name, note))
        path = export_assembly(target) if is_assembly else export(target)
        print("OK %s %s %d" % (target.name.lower(), path, path.stat().st_size))
    if skipped:
        print("%d object(s) skipped" % skipped)
        if bpy.app.background:
            sys.exit(1)


main()
