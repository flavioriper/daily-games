"""Build every Binairo island piece procedurally and save art/pieces.blend.

Run headless, then hand the objects to the exporter in the same session:

    /Applications/Blender.app/Contents/MacOS/Blender -b \
        --python tools/build_pieces.py \
        --python tools/blender_export.py -- \
        Tile Emblem_Sun Emblem_Moon Empty_Mark Rim_Edge Rim_Corner

(tools/build_models.sh does exactly that and re-imports in Godot.)

Every piece follows docs/art/blender-contract.md: metric units, one unit per
cell, origin at the centre of the base, smooth shading with shared vertices,
plain-colour Principled materials, `_flat` names on surfaces that must not get
an outline. Pieces are built with bmesh so the script is the source of truth;
the .blend is a by-product for looking at them.

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
SUN = "f5a623"
MOON = "f6f1e6"
MARK = "cbbd9f"
MOSS = "7fa84a"
GRASS = "a3c95e"  # tufts lighter than the moss so they read as mounds, not dirt
PETAL = "f6f1e6"
POLLEN = "f5a623"

TILE_H = 0.14
EMBLEM_H = 0.05
MARK_H = 0.03
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


def diamond(half):
    return [(0.0, -half), (half, 0.0), (0.0, half), (-half, 0.0)]


def circle(radius, n, cx=0.0, cy=0.0):
    return [(cx + radius * math.cos(2 * math.pi * i / n), cy + radius * math.sin(2 * math.pi * i / n)) for i in range(n)]


def ray(angle, r0, r1, w0, w1):
    """Tapered ray from radius r0 (width w0) to r1 (width w1), pointing at angle."""
    ca, sa = math.cos(angle), math.sin(angle)
    def at(r, w):
        return (r * ca - w * sa, r * sa + w * ca)
    return [at(r0, -w0 / 2), at(r1, -w1 / 2), at(r1, w1 / 2), at(r0, w0 / 2)]


def crescent(r_out, r_in, d, tip=0.012, n=48):
    """Outer disc minus an inner disc whose centre is offset by vector d.
    Horns are blunted by `tip` so the bevel has something to hold on to."""
    dv = Vector(d)
    dist = dv.length
    u = dv / dist
    perp = Vector((-u.y, u.x))
    a = (r_out ** 2 - r_in ** 2 + dist ** 2) / (2 * dist)
    h = math.sqrt(r_out ** 2 - a ** 2)
    theta_o = math.atan2(h, a) + tip / r_out
    theta_i = math.atan2(h, a - dist) + tip / r_in
    pts = []
    for i in range(n + 1):
        th = theta_o + (2 * math.pi - 2 * theta_o) * i / n
        p = (math.cos(th) * u + math.sin(th) * perp) * r_out
        pts.append((p.x, p.y))
    for i in range(n + 1):
        th = (2 * math.pi - theta_i) - (2 * math.pi - 2 * theta_i) * i / n
        p = dv + (math.cos(th) * u + math.sin(th) * perp) * r_in
        pts.append((p.x, p.y))
    return pts


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
        flats = [f for f in island_faces if f.is_valid and f not in bevel_faces]
        # The bevel replaces the island's faces with new ones; collect the flat
        # faces again from the bevel result's neighbourhood.
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

def build_tile():
    bm = new_bm()
    add_prism(bm, square(0.47), TILE_H, 0, bevel=0.045, segments=3, inset=0.02)
    return finish(bm, "Tile", [material("Stone", STONE)])


def build_sun():
    bm = new_bm()
    add_prism(bm, circle(0.16, 32), EMBLEM_H, 0, bevel=0.014, segments=2, inset=0.01)
    for i in range(8):
        ang = 2 * math.pi * i / 8 + math.pi / 8
        # Fat rays: the 0.02 outline eats a strip off every side.
        add_prism(bm, ray(ang, 0.195, 0.29, 0.1, 0.062), EMBLEM_H, 0, bevel=0.012, segments=2, inset=0.008)
    return finish(bm, "Emblem_Sun", [material("Sun", SUN)])


def build_moon():
    bm = new_bm()
    add_prism(bm, crescent(0.215, 0.19, (0.105, 0.07), n=32), EMBLEM_H, 0, bevel=0.012, segments=2, inset=0.008)
    return finish(bm, "Emblem_Moon", [material("Moon", MOON)])


def build_mark():
    bm = new_bm()
    add_prism(bm, diamond(0.07), MARK_H, 0, bevel=0.008, segments=2, inset=0.006)
    return finish(bm, "Empty_Mark", [material("Mark_flat", MARK)])


def rim_materials():
    return [material("Moss_flat", MOSS), material("Grass_flat", GRASS),
            material("Petal_flat", PETAL), material("Pollen_flat", POLLEN)]


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
        z = RIM_H + r * 0.5 - 0.035
        add_blob(bm, (x, y, z), r, 0.5, 1)
    fx, fy = flower_at
    add_flower(bm, (fx, fy, RIM_H + 0.045))


def build_rim_edge():
    # 1 along X, 0.5 along Y, outward side at +Y.
    bm = new_bm()
    add_prism(bm, [(-0.5, -0.25), (0.5, -0.25), (0.5, 0.25), (-0.5, 0.25)], RIM_H, 0, bevel=0.008, segments=2, inset=0.01)
    add_tufts(bm, random.Random(11), (-0.5, 0.5, -0.25, 0.25), 4, (0.22, 0.12))
    return finish(bm, "Rim_Edge", rim_materials())


def build_rim_corner():
    # 0.5 by 0.5, outward corner at +X +Y.
    bm = new_bm()
    add_prism(bm, square(0.25), RIM_H, 0, bevel=0.008, segments=2, inset=0.01)
    add_tufts(bm, random.Random(5), (-0.25, 0.25, -0.25, 0.25), 2, (0.1, 0.11))
    return finish(bm, "Rim_Corner", rim_materials())


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def main():
    clear_scene()
    objs = [build_tile(), build_sun(), build_moon(), build_mark(), build_rim_edge(), build_rim_corner()]
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
