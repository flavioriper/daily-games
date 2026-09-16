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
    # An assembly: the cube body, side 0.84, standing on the platform, plus
    # the sun and moon inlaid in its walls, which reach 0.87 across.
    "tile": (1.0, 1.0, 0.9),
    "rim_edge": (1.0, 0.5, 0.12),
    "rim_corner": (0.5, 0.5, 0.12),
    # Island scenery: a tree stands well above a piece, so it gets the
    # mascot footprint and its own taller budget.
    "tree": (1.4, 1.4, 2.0),
    # Code Break pieces (docs/superpowers/specs/2026-09-14-codebreak-3d-design.md,
    # section 1): a slab, a dome, a pip and a lid, all inside one cell.
    "socket": (1.0, 1.0, 0.15),
    "peg": (0.7, 0.7, 0.5),
    "pip": (0.3, 0.3, 0.2),
    "lid": (1.0, 1.0, 0.3),
    # Pipes pieces (docs/superpowers/specs/2026-09-14-pipes-3d-design.md,
    # section 1): a pad, the five pipe shapes whose arms reach the cell edge,
    # and a bolted valve ring.
    "pipe_pad": (1.0, 1.0, 0.15),
    "pipe_cap": (1.0, 1.0, 0.38),
    "pipe_straight": (1.0, 1.0, 0.38),
    "pipe_elbow": (1.0, 1.0, 0.38),
    "pipe_tee": (1.0, 1.0, 0.38),
    "pipe_cross": (1.0, 1.0, 0.38),
    "valve": (0.65, 0.65, 0.12),
    # Pipes' island (docs/superpowers/specs/2026-09-15-pipes-iso-design.md,
    # section 9): the block the island is built out of, the pump that lifts
    # water a level, and the tank and pool at the two ends of a run. The block
    # is exact rather than budgeted -- see EXACT below. The pump is a pipe
    # stood on end and so is two arms tall where a lying piece is one: its hub
    # is a whole arm up, which is the only way a down mouth reaching ARM_LEN
    # lands on the base instead of under it. The drain is given the pipes' own
    # 0.38 and not the 0.3 the spec's table guessed, because the arm it wears
    # puts a mouth collar at TUBE_Y + COLLAR_R like every other piece.
    "block": (1.0, 1.0, 1.02),
    "pump": (1.0, 1.0, 1.0),
    "source_tank": (1.0, 1.0, 0.6),
    "drain_pool": (1.0, 1.0, 0.38),
    # Balance pieces (the design agreed 2026-09-15). Three of these are the
    # first slots that are deliberately bigger than a cell, so their budgets
    # are the piece's real span rather than the usual 1 x 1: a beam reaches a
    # pan's hang point each way, a pan's dish is wider than a cell, and a
    # plinth covers the two cells whose taps add and remove a disc. All stay
    # centred on the origin, so none of them needs a LOPSIDED exemption.
    "scale_stand": (0.7, 0.7, 1.1),
    "scale_beam": (3.2, 0.3, 0.3),
    "scale_pan": (1.3, 1.3, 0.4),
    "plinth": (1.0, 2.0, 0.2),
    "weight_disc": (0.65, 0.65, 0.12),
    "token_ball": (0.5, 0.5, 0.35),
    "token_cube": (0.5, 0.5, 0.35),
    "token_prism": (0.5, 0.5, 0.35),
    "token_gem": (0.5, 0.5, 0.35),
    "token_cross": (0.5, 0.5, 0.35),
    # Untangle: the mooring post a rope is made fast to. The rope itself is
    # not a slot -- the board rebuilds it as a tube from its own simulation
    # every frame it moves, so there is nothing to export.
    "post": (0.5, 0.5, 0.7),
    # Shikaku (the design agreed 2026-09-15): a plot floor, the dry-stone wall
    # that divides two plots, the block that closes a corner, and the marker
    # stone carrying the clue's numeral. `wall_edge` is modelled exactly one
    # cell long because the board stretches it along X to cover a whole run of
    # seam, the way the platform slab is stretched -- a short one would leave
    # a gap at the end of every run.
    "plot_pad": (1.0, 1.0, 0.15),
    "wall_edge": (1.0, 0.25, 0.25),
    "wall_post": (0.3, 0.3, 0.3),
    "clue_stone": (0.7, 0.7, 0.24),
    # Tents (the design agreed 2026-09-15): the turf cell, the conifer a tent
    # is pitched beside, the tent, and the cairn that rules a cell out. The
    # row and column counts are `clue_stone` again, laid on the stone margin.
    "turf_pad": (1.0, 1.0, 0.12),
    "camp_tree": (0.7, 0.7, 0.8),
    "tent": (0.7, 0.7, 0.45),
    "cairn": (0.5, 0.5, 0.3),
    # Light Up (the design agreed 2026-09-15): the block of stone that stops
    # the light, carrying its clue on its crown, and the lantern the player
    # sets down. The court's floor is Shikaku's `plot_pad` and the chip that
    # rules a cell out is Tents' `cairn`, so neither needs a row of its own.
    "wall_block": (1.0, 1.0, 0.44),
    "lantern": (0.6, 0.6, 0.55),
    # Nonogram and One Line (the designs agreed 2026-09-15): the slate tile a
    # filled cell carries, and one cell's length of plank. The nonogram's
    # sockets are Shikaku's `plot_pad`, its clues are `clue_stone` and its
    # ruled-out marks are Tents' `cairn`; One Line's posts are Untangle's
    # `post`. Only these two are new. `plank` is modelled exactly one cell
    # long because the board stretches it along X to span two posts, and a
    # board's lines run diagonally as well as straight, so there is no single
    # length to model -- the same arrangement `wall_edge` has.
    "mosaic_tile": (1.0, 1.0, 0.16),
    "plank": (1.0, 0.34, 0.14),
    # Horse Pen (the design agreed 2026-09-15): the horse, standing in profile
    # along X on one cell; one cell's length of timber fence, exactly a cell
    # long so a run of fences reads as one unbroken rail; and an apple. The
    # meadow is Tents' `turf_pad` and a pond is Shikaku's `plot_pad` wearing
    # the water material, so neither needs a row.
    "horse": (0.9, 0.9, 0.9),
    "fence": (1.0, 0.3, 0.5),
    "apple": (0.45, 0.45, 0.45),
    # Horse Pen's polish pass (docs/brainstorm/concepts.html, the Horse Pen
    # tab): the hay bale that replaced the see-through fence, the water
    # channel that replaced the pond -- tiled edge to edge along a stream, so
    # its footprint is exact, not merely budgeted -- and the two pieces the
    # board scatters as MultiMeshes, a tuft of wheat and a flower.
    "bale": (0.8, 0.8, 0.5),
    "channel": (1.0, 1.0, 0.1),
    "stalk": (0.3, 0.3, 0.32),
    "flower": (0.25, 0.25, 0.08),
    # Snake Apple (the design agreed 2026-09-15): the snake's head, cut from
    # a BlenderKit snake and facing +X with its neck at the origin, and the
    # burrow it goes home to. The body is not a slot: the board builds it as
    # a tube along the snake's cells, the way Untangle builds its ropes.
    "snake_head": (0.9, 0.9, 0.5),
    "burrow": (1.0, 1.0, 0.14),
    # Code Break's screen (docs/superpowers/specs/2026-09-15-codebreak-screen-design.md):
    # the deck strip the board is laid on -- exactly a cell long because the
    # board stretches it along X, and tiled edge to edge along Y with half a
    # gap at each edge, so its depth is budgeted, not exact -- and the
    # scenery around it. The signpost is wider than a cell on purpose: the
    # plank hangs from an arm beside the post.
    "deck": (1.0, 1.0, 0.62),
    "pier_post": (0.4, 0.4, 2.1),
    "boulder": (1.0, 1.0, 0.6),
    "bush": (1.0, 1.0, 0.7),
    "daisy": (0.3, 0.3, 0.25),
    "tuft": (0.3, 0.3, 0.25),
    "signpost": (1.4, 0.4, 1.8),
    # The menu's campsite (2026-09-16): the fence-and-sign diorama that closes
    # the first screen at the bottom. A Meshy model cut down in Blender, one
    # textured mesh rather than flat-colour layers -- see the contract's
    # "Textured props" section.
    "camp_sign": (2.0, 1.0, 0.5),
    # Peeplet's broadleaf, brought over as geometry only (art/oak.blend, from
    # the peeplet project's trees.blend) and dressed by this project's toon
    # pipeline; and the grass clump that field is scattered from.
    "oak": (1.4, 1.4, 2.0),
    "grass_clump": (0.5, 0.5, 0.45),
    # The BlenderKit grass field's own strands (art/grassfield.blend), baked
    # from a half-cell emitter carrying the source terrain's hair settings;
    # the children fan out past the emitter, hence the wider footprint.
    "grass_patch": (0.8, 0.8, 0.45),
}
DEFAULT_LIMIT = (1.0, 1.0, 0.6)  # unknown slots
# Mascots are assemblies and stand taller than a piece; one budget for all of
# them, so a new character needs no new row here.
MASCOT_PREFIX = "mascot_"
MASCOT_LIMIT = (1.4, 1.4, 1.4)
# The backdrop pieces (art/landscape.blend) are scenery the camera never gets
# near, sized in tens of units rather than cells, so no footprint budget
# applies -- only the origin and base rules every slot keeps.
BACKDROP = {"meadow", "cloud", "foliage", "blossom", "hills"}
# The menu and HUD title board (art/sign.blend). It is chrome, not a piece on
# a board: it is drawn in its own SubViewport at whatever size the Control
# layout gives it, so the cell footprint rules mean nothing to it. It still
# keeps the origin and base rules every slot keeps.
SIGNS = {"title_sign"}
UNBOUNDED = {"platform", "water"} | BACKDROP | SIGNS  # no maximum; platform has its own exact check
# Slots the board tiles edge to edge, so the footprint must be exact, not
# merely within budget: the platform is stretched by (cols + 1, rows + 1) and
# the rim pieces are laid one per cell, where a short piece leaves a gap.
# A None dimension is not fixed, only budgeted: Shikaku's `wall_edge` is
# stretched along X alone, so its length must be exact while its thickness is
# the artist's to choose inside the LIMITS row.
EXACT = {"platform": (1.0, 1.0), "rim_edge": (1.0, 0.5), "rim_corner": (0.5, 0.5),
    "wall_edge": (1.0, None), "plank": (1.0, None), "fence": (1.0, None), "deck": (1.0, None),
    "channel": (1.0, 1.0), "block": (1.0, 1.0)}
# A shape whose openings cancel (an opposite pair, or all four) keeps its
# mass centred on its hub, and must pass the strict origin-at-centre check
# below -- pipe_straight and pipe_cross stay off this set on purpose. One
# whose openings do not cancel (a dead end, an elbow, a T) cannot: its hub,
# which must sit at the world origin for the piece to rotate correctly and
# for its open arms to reach the cell edge, is not the centroid of its
# lopsided footprint. A cap's hub reaches back 0.15 (TUBE_R) but its one arm
# reaches forward 0.498 (ARM_LEN) -- no rearrangement of dimensions the spec
# fixes closes that gap. These slots get a cell-containment check instead of
# origin-at-footprint-centre (see placement_problems): the footprint must
# still fit the 1 x 1 cell around the origin, just not be centred within it.
# Snake Apple's head is lopsided the same way: the back of the skull, where
# the board's body tube runs in, is the pivot and sits at the origin, and the
# head reaches forward from it along +X.
# The island's source and drain are lopsided for the pipe's own reason: each
# wears one arm of pipe, reaching the cell edge on +Y in Blender (Godot +Z)
# with its body centred on the hub, so its bounding box cannot be centred on
# the origin the board turns it about.
LOPSIDED = {"pipe_cap", "pipe_elbow", "pipe_tee", "snake_head", "source_tank", "drain_pool"}


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
    # Custom normals break the outline shell, which extrudes along them. A
    # layer with no shell (every material `_flat`) may keep them: the oak's
    # leaf cards carry normals baked from a smooth proxy so the toon band
    # sweeps the crown as one mass instead of per-card speckle.
    outlined = any(not (m and m.name.endswith("_flat")) for m in mesh.materials) or not mesh.materials
    if mesh.has_custom_normals and outlined:
        found.append("custom split normals (clear them: Mesh > Normals > Clear Custom Split Normals Data)")
    if obj.data.shape_keys and obj.modifiers:
        found.append("shape keys and modifiers together; apply the modifiers "
                     "(the glTF writer drops shape keys when it applies them)")
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
    if slot in LOPSIDED:
        # The hub, not the bounding-box centroid, sits at the origin, so the
        # footprint cannot be centred -- but it must still fit the 1 x 1 cell
        # around the origin, the same bound a centred slot gets from centring
        # plus its span check together. Origin-inside-the-bbox alone is not
        # enough: it only bounds the pivot, not whether the piece bleeds into
        # a neighbour's cell (a cap with y in [-0.05, 0.85] has span 0.9, under
        # budget, and its origin inside, but overhangs by 0.35).
        limit_x, limit_y, _ = limit_for(slot)
        if (lo.x < origin.x - limit_x * 0.5 - TOLERANCE or hi.x > origin.x + limit_x * 0.5 + TOLERANCE
                or lo.y < origin.y - limit_y * 0.5 - TOLERANCE or hi.y > origin.y + limit_y * 0.5 + TOLERANCE):
            found.append("footprint (%.3f, %.3f) .. (%.3f, %.3f) overhangs the %.1f x %.1f cell around the origin" %
                (lo.x, lo.y, hi.x, hi.y, limit_x, limit_y))
    else:
        centre_x = (lo.x + hi.x) * 0.5 - origin.x
        centre_y = (lo.y + hi.y) * 0.5 - origin.y
        if abs(centre_x) > TOLERANCE or abs(centre_y) > TOLERANCE:
            found.append("origin not at footprint centre (off by %.3f, %.3f)" % (centre_x, centre_y))
    if slot in EXACT:
        exact = EXACT[slot]
        span = (hi.x - lo.x, hi.y - lo.y)
        for axis in (0, 1):
            if exact[axis] is None:
                # Free along this axis: budgeted like any other slot instead.
                if slot in LIMITS and span[axis] > LIMITS[slot][axis] + TOLERANCE:
                    found.append("%s span %.2f exceeds %.2f on %s" %
                        (slot, span[axis], LIMITS[slot][axis], "XY"[axis]))
            elif abs(span[axis] - exact[axis]) > TOLERANCE:
                found.append("%s must be exactly %.2f on %s (got %.2f)" %
                    (slot, exact[axis], "XY"[axis], span[axis]))
        # The platform's height is free (the board never stacks on it); the
        # rim pieces and the walls keep the height budget from LIMITS.
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


# Blender's glTF writer cannot do both jobs at once: "Apply Modifiers" bakes
# the evaluated mesh and silently drops every shape key with it. A piece with
# shape keys therefore exports unapplied, which is safe because mesh_problems
# refuses the combination of shape keys and modifiers in the first place.
def apply_modifiers(objs):
    return not any(o.data.shape_keys for o in objs if o.type == "MESH")


# Only this scene: a .blend that keeps a BlenderKit scene appended beside the
# game's own (art/landscape.blend, art/grassfield.blend) would otherwise ship
# whatever happens to be selected over there.
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
            export_apply=apply_modifiers([obj] + list(obj.children_recursive)),
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_animations=False,
            use_active_scene=True,
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
        export_apply=apply_modifiers(meshes),
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        use_active_scene=True,
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
