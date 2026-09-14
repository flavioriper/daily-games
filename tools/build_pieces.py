"""Build the procedural Binairo island pieces and save art/pieces.blend.

The tile is NOT here, and neither are the sun and the moon: the cube and the
symbols inlaid in its faces are modelled by hand in art/tile.blend and export
together as one assembly (see docs/art/blender-contract.md). This script must
never write a Tile again, or the next run would overwrite those hand edits.

Run headless, then hand the objects to the exporter in the same session:

    /Applications/Blender.app/Contents/MacOS/Blender -b \
        --python tools/build_pieces.py \
        --python tools/blender_export.py -- \
        Rim_Edge Rim_Corner

(tools/build_models.sh does exactly that and re-imports in Godot.)

Every piece follows docs/art/blender-contract.md: metric units, one unit per
cell, origin at the centre of the base, smooth shading with shared vertices,
plain-colour Principled materials, `_flat` names on surfaces that must not get
an outline and `_sway` on the ones that wave in the wind. Pieces are built
with bmesh so the script is the source of truth;
the .blend is a by-product for looking at them.

Axes: Blender is Z-up and the glTF exporter maps Blender (x, y, z) to Godot
(x, z, -y). The rim pieces are directional, and "outward" (away from the
tiles, toward the water) is Godot +Z, which is Blender -Y. Build directional
features on the -Y side.

Shape recipe ("chunky"): a flat polygon extruded to height, every edge
bevelled, then each original flat face inset by a hair. The inset matters
under toon shading: with shared smooth vertices, the bevel tilts the normals
along the rim of a flat face, and the inset confines that tilt to a thin
band so the face itself reads as one flat tone.
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
BLEND = ROOT / "art" / "pieces.blend"

# Palette (core/palette.gd), sRGB hex.
STONE = "ede2cc"
SLATE = "3f4652"
MOSS = "7fa84a"
GRASS = "a3c95e"  # tufts lighter than the moss so they read as mounds, not dirt
PETAL = "f6f1e6"
POLLEN = "f5a623"

# The tile is not built here: it is a hand-modelled cube, sun and moon in
# art/tile.blend.
RIM_H = 0.03
RIM_MAX = 0.12


# --- materials -------------------------------------------------------------

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, hex_rgb):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    r, g, b = (int(hex_rgb[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


# --- 2D outlines -----------------------------------------------------------

def square(half):
    return [(-half, -half), (half, -half), (half, half), (-half, half)]


# --- bmesh building --------------------------------------------------------

def add_prism(bm, outline, height, mat_index, bevel, segments, inset, z0=0.0):
    """Extrude `outline` from z0 to z0 + height, bevel every edge, inset the
    flat faces. Adds to `bm`; returns nothing."""
    verts = [bm.verts.new((x, y, z0)) for x, y in outline]
    base = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[base])
    top_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top_verts, vec=(0.0, 0.0, height))
    island_faces = set([base] + [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)])
    island_faces.update(f for v in top_verts for f in v.link_faces)
    island_faces = list(island_faces)
    bmesh.ops.recalc_face_normals(bm, faces=island_faces)
    island_edges = list({e for f in island_faces for e in f.edges})
    if bevel > 0.0:
        bres = bmesh.ops.bevel(bm, geom=island_edges, offset=bevel, offset_type="OFFSET",
                               segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
        bevel_faces = set(bres["faces"])
        # The bevel replaces the island's faces with new ones, so the flat
        # faces are whatever borders the bevel strip and is not part of it.
        flats = list({f for bf in bevel_faces for e in bf.edges for f in e.link_faces if f not in bevel_faces})
    else:
        bevel_faces = set()
        flats = [f for f in island_faces if f.is_valid]
    if inset > 0.0:
        for f in flats:
            if not f.is_valid:
                continue
            shortest = min(e.calc_length() for e in f.edges)
            th = min(inset, shortest * 0.35)
            if th <= 1e-4:
                continue
            bmesh.ops.inset_individual(bm, faces=[f], thickness=th, depth=0.0, use_even_offset=True)
    for f in bm.faces:
        if f.material_index == 0 and f not in _assigned:
            f.material_index = mat_index
            _assigned.add(f)


_assigned = set()


def add_blob(bm, centre, radius, z_scale, mat_index, subdivisions=2):
    m = Matrix.Translation(Vector(centre)) @ Matrix.Diagonal((1.0, 1.0, z_scale, 1.0))
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius, matrix=m)
    for v in res["verts"]:
        for f in v.link_faces:
            if f not in _assigned:
                f.material_index = mat_index
                _assigned.add(f)


def finish(bm, name, materials):
    """Smooth everything, merge shared vertices, write the object."""
    for f in bm.faces:
        f.smooth = True
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    caps = [f for f in bm.faces if len(f.verts) > 4]
    if caps:
        bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="BEAUTY")
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    lo_z = min(v.co.z for v in mesh.vertices)
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    shift = Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -lo_z))
    for v in mesh.vertices:
        v.co += shift
    mesh.update()
    return obj


def new_bm():
    _assigned.clear()
    return bmesh.new()


# --- pieces ----------------------------------------------------------------

def rim_materials():
    # The tufts, petals and pollen sway in the game's wind (a `_sway` name,
    # contract rule 11); the moss slab stays still.
    return [material("Moss_flat", MOSS), material("Grass_sway_flat", GRASS),
            material("Petal_sway_flat", PETAL), material("Pollen_sway_flat", POLLEN)]


def add_flower(bm, centre):
    cx, cy, cz = centre
    add_blob(bm, (cx, cy, cz), 0.016, 0.8, 3, subdivisions=1)
    for i in range(5):
        ang = 2 * math.pi * i / 5
        add_blob(bm, (cx + 0.027 * math.cos(ang), cy + 0.027 * math.sin(ang), cz - 0.004), 0.019, 0.5, 2, subdivisions=1)


def add_tufts(bm, rng, box, count, flower_at):
    """Grass blobs sunk into the moss slab. `box` is (x0, x1, y0, y1)."""
    x0, x1, y0, y1 = box
    for _ in range(count):
        r = rng.uniform(0.07, 0.11)
        x = rng.uniform(x0 + r, x1 - r)
        y = rng.uniform(y0 + r, y1 - r)
        # Blob bottom exactly on the slab base, so nothing pokes below z = 0
        # and finish() has no reason to lift the slab.
        add_blob(bm, (x, y, r * 0.5), r, 0.5, 1)
    fx, fy = flower_at
    add_flower(bm, (fx, fy, RIM_H + 0.045))


def build_rim_edge():
    # 1 along X, 0.5 along Y, outward side at -Y (Godot +Z). The flower sits
    # on the outer half so it shows against the water, not against the tiles.
    bm = new_bm()
    add_prism(bm, [(-0.5, -0.25), (0.5, -0.25), (0.5, 0.25), (-0.5, 0.25)], RIM_H, 0, bevel=0.008, segments=2, inset=0.01)
    add_tufts(bm, random.Random(11), (-0.5, 0.5, -0.25, 0.25), 4, (0.22, -0.12))
    return finish(bm, "Rim_Edge", rim_materials())


def build_rim_corner():
    # 0.5 by 0.5, outward corner at +X -Y (Godot +X +Z).
    bm = new_bm()
    add_prism(bm, square(0.25), RIM_H, 0, bevel=0.008, segments=2, inset=0.01)
    add_tufts(bm, random.Random(5), (-0.25, 0.25, -0.25, 0.25), 2, (0.1, -0.11))
    return finish(bm, "Rim_Corner", rim_materials())


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def main():
    clear_scene()
    objs = [build_rim_edge(), build_rim_corner()]
    for i, obj in enumerate(objs):
        obj.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    for obj in objs:
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        print("BUILT %-12s %5d verts  %.3f x %.3f x %.3f" % (
            obj.name, len(obj.data.vertices), max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    print("SAVED", BLEND)


main()
