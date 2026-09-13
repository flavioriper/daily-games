# Blender contract

The whole agreement between a model made in Blender and the game. If a model
follows these rules, exporting it to `assets/models/<slot>.glb` is the entire
integration: the game finds it by name, converts its materials to the toon
shader, adds the outline, and places it. Nothing else to configure.

## Slots

| slot | footprint (X by Y in Blender) | max height (Z) | notes |
|---|---|---|---|
| `tile` | 1.0 x 1.0, use 0.94 along X by 0.84 across Y | 0.75 | a trilon: an equilateral three-sided prism lying along X, flat face up, lowest edge at Z = 0. Four materials the game colours by name: `Face_Empty` (up at rest), `Face_Sun` (sloping toward -Y, the player), `Face_Moon` (toward +Y), `Cap` (both ends). Emblems are placed on the faces by the game |
| `emblem_sun` | inside 0.6 x 0.6 | 0.08 | orange sun with rays, lies flat on a tile |
| `emblem_moon` | inside 0.6 x 0.6 | 0.08 | ivory crescent, lies flat on a tile |
| `empty_mark` | inside 0.2 x 0.2 | 0.04 | small diamond on an empty tile |
| `rim_edge` | exactly 1.0 x 0.5 | 0.12 | moss strip on one cell of the platform lip; runs along X, outward side (toward the water) at **-Y** in Blender, which is +Z in Godot |
| `rim_corner` | exactly 0.5 x 0.5 | 0.12 | moss square on a platform corner; outward corner at **+X -Y** in Blender, +X +Z in Godot |
| `platform` | exactly 1.0 x 1.0 (enforced) | 0.6, a guide |  a unit stone slab; the board stretches it to (cols + 1, rows + 1), so keep the material a plain colour |
| `water` | any, about 60 x 60 | flat | the water plane far below the platform |
| `mascot_<name>` | up to 1.4 x 1.4 | 1.4 | a character, e.g. `mascot_pom`; an **assembly**, see below |

Concept reference: `docs/art/concept-binairo-island.png`. The rim pieces are
the moss trim; `core/platform.gd` lays one `rim_edge` per cell along each side
and a `rim_corner` at each corner, so the lip is exactly one rim piece deep
(`Platform.LIP`, 0.5). Cliffs and the rest of the island come later.

Mascots are a family rather than a row: any slot starting with `mascot_` gets
the same generous budget, so a new character needs no change to the exporter.

The list lives in code as `SLOTS` in `core/models.gd`. New puzzles add rows.
The export script enforces each slot's footprint and height budget from this
table (an unlisted slot falls back to 1.0 x 1.0 x 0.6). Slots the board tiles
edge to edge are checked for an *exact* footprint, not a maximum: `platform`
(1 x 1, height free, because the board scales it by (cols + 1, rows + 1)),
`rim_edge` (1 x 0.5) and `rim_corner` (0.5 x 0.5), since a short rim piece
leaves a gap in the ring. `water` is unbounded.

## Rules

1. **Units.** Metric, unit scale 1.0. One Blender unit is one board cell.
2. **Origin at the centre of the base.** The lowest vertex is at Z = 0 and
   the footprint is centred on X = Y = 0. Blender is Z-up; the glTF exporter
   converts to Godot's Y-up for you, so model with Z as up and do nothing else.
   For directional pieces remember the mapping: Blender (x, y, z) becomes
   Godot (x, z, -y), so Blender -Y is Godot +Z (toward the player).
3. **Apply transforms.** Rotation (0, 0, 0), scale (1, 1, 1) before export.
4. **Shade smooth with shared vertices, everywhere.** No split edges, no
   flat shading. For a hard-edged look, add a small Bevel modifier (width
   about 0.02, 2 segments) and stay smooth. Never use Auto Smooth / Smooth by
   Angle, Weighted Normal, Edge Split, or custom split normals — all of them
   split vertices at export. Reason: the outline draws a second copy of the
   mesh pushed out along the vertex normals; split vertices leave visible
   gaps at every corner. The exporter rejects meshes with custom split
   normals or an Edge Split / Weighted Normal / Smooth by Angle modifier,
   and a Bevel with **Harden Normals** on, which writes split normals the
   moment the modifier is applied. It measures the modifier result, not the
   cage, so a Solidify or Displace that grows the mesh past its budget is
   caught too.
5. **Materials are colours.** One Principled BSDF per material, Base Color set,
   nothing else needed. The game replaces every material with the toon shader
   using that base colour. Textures export fine but are ignored by the toon
   shader for now.
6. **Named materials on slots the game recolours.** The game recolours by
   material *name*, one colour per name, so a recoloured slot must carry
   exactly the names the game expects: `tile` has `Face_Empty`, `Face_Sun`,
   `Face_Moon` and `Cap`, and nothing else (an extra material would never be
   coloured and would keep its Blender colour). Do not split one face over
   two materials. Slots that are never tinted (`emblem_sun`, `emblem_moon`,
   `empty_mark`, `rim_edge`, `rim_corner`, `platform`, `water`) may use as
   many materials as they like.
7. **`_flat` suffix.** A material named like `Wood_flat` gets toon shading but
   no outline. Use it for any surface that should not read as a piece. The
   `platform`, `water`, `empty_mark`, `rim_edge` and `rim_corner` materials
   **must** carry the suffix (for example `Rock_flat`, `Moss_flat`); without
   it they get an outline shell the design does not want on them. A mesh
   keeps its outline unless *every* one of its material names ends in `_flat`.
8. **No parent.** Export objects with no parent. The exporter measures world
   space but moves the object in parent space, so a parented object exports
   somewhere other than where it was checked; clear the parent (Alt+P, Clear
   Parent and Keep Transform) first. The exporter rejects parented objects.
9. **No `.001` suffixes.** Blender's automatic duplicate suffix on an *object*
   name breaks the slot lookup (`Tile.001` exports as `tile.001.glb`, which
   the game never loads — the exporter prints a `WARN` for it), and on a
   *material* name it breaks the `_flat` check (`Rock_flat.001` does not end
   in `_flat`, so it gets an unwanted outline). Rename before exporting.
10. **Export settings.** glTF Binary (`.glb`), +Y Up, Apply Modifiers,
    Selected Objects, Materials: Export, no cameras, no lights, no animation.
    File name is the slot name. The script below does all of this.

## Assemblies

A piece made of several objects — today the mascots — exports as a *collection*
instead of an object. The collection name is the slot name (`Mascot_Pom`
writes `mascot_pom.glb`), and every mesh inside it goes into that one file.

Why not one mesh: each coloured region is its own object with its own
material, so a layer can be recoloured, retextured, hidden or animated without
touching the rest. Parts overlap as closed solids rather than sharing an edge,
which keeps every part a clean closed smooth surface — the shape the
inverted-hull outline wants.

This is a rule, not a preference: **one mesh per layer**. Never merge two
layers into one mesh and never give one mesh two materials. A layer that is
its own object can be UV-unwrapped and textured on its own later; a merged one
cannot. Two lobes of the *same* layer (one material, like the muzzle) may share
a mesh. Add a detail as a new object with a new material, not as new faces on
an existing part.

The rules change in two places:

* **Rule 2 applies to the assembly, not to each part.** The union of the parts
  has its lowest vertex at Z = 0 and its footprint centred on X = Y = 0. Parts
  sit wherever they belong and all share the assembly's origin; the exporter
  measures the union.
* **Rule 6 does not apply.** An assembly is never tinted by state, so it may
  carry as many materials as it has layers. Rule 7 still does: give a face
  detail that should not read as its own piece a `_flat` material, as
  `Pom_Mouth_flat`, `Pom_Tongue_flat`, `Pom_Eye_flat` and `Pom_Cheek_flat`
  do.

Everything else holds per part: transforms applied, smooth with shared
vertices, no parent, no `.001` names, plain-colour Principled materials.

## Mascots

Mascots are **modelled by hand in Blender**, not generated. The `.blend` is the
source and is tracked in git (`art/mascot_<name>.blend`, un-ignored in
`.gitignore`); open it, move the parts, and re-export. Never write a script
that rebuilds a mascot from scratch — it would overwrite the hand edits.

`art/mascot_pom.blend` holds POM as 15 layers: `Pom_Body` (the cream egg),
`Pom_Cap` (the orange coat: a copy of the body mesh pushed out 0.012 by a
Displace modifier and cut by a Boolean with the `Pom_Cap_Cutter` ellipsoid, so
the cream face-and-belly oval is a shape the cutter moves and scales; copy the
body mesh into it again after reshaping the body), `Pom_Ear_L/R`,
`Pom_Eye_L/R` (closed happy arcs), `Pom_Muzzle` (two lobes, one layer),
`Pom_Nose`, `Pom_Mouth`, `Pom_Tongue`, `Pom_Cheek_L/R`, `Pom_Foot_L/R`,
`Pom_Tail`. The cutter lives in a `Pom_Helpers` collection so it never
exports. Concept reference: the mascot
sheet in `~/Downloads/chars.png`.

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/mascot_pom.blend \
  --python tools/blender_export.py -- Mascot_Pom
godot --headless --path . --import
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- mascot_pom
open /tmp/shot_model_mascot_pom.png
```

`tests/_shot_model.gd` previews any slot on the real stage — toon materials,
outlines, island light — with the camera at eye level instead of the board's
top-down pitch.

## Building the pieces

The Binairo pieces are not hand-modelled: `tools/build_pieces.py` builds all
six with bmesh (the trilon tile, both emblems, empty mark, both rim pieces), following
every rule above, and saves `art/pieces.blend` as a by-product for looking at
them (the `.blend` is git-ignored; the script is the source). Each piece is a
flat outline extruded to height, bevelled on every edge, then each flat face
inset by a hair: with shared smooth vertices the bevel tilts the normals along
a face's rim, and the inset keeps that tilt in a thin band so the face reads
as one toon tone. Rebuild, export and re-import in one go:

```bash
tools/build_models.sh
```

To change a shape, edit the script and rerun; hand edits in the `.blend` are
overwritten.

## Export script

`tools/blender_export.py` checks the rules and exports. Inside Blender, open
the Scripting tab, load the file and run it with the objects selected, or
from a shell (`art/pieces.blend` exists once `tools/build_models.sh` has run;
it is not in git):

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/pieces.blend \
  --python tools/blender_export.py -- Tile Emblem_Sun Emblem_Moon
```

The names are Blender *object* names, or a *collection* name for an assembly;
each is lowercased to form the slot name (`Emblem_Sun` writes `emblem_sun.glb`,
the `Mascot_Pom` collection writes `mascot_pom.glb`). With no names it exports the selected
objects; with nothing selected, every top-level mesh. Each object prints one
line, `OK` with the output path or `SKIP` with the rule it broke, preceded by
a `WARN` line when the slot name is not one the game loads, and the process
exits non-zero if anything was skipped.

## Seeing it in the game

```bash
godot --headless --path . --import          # register the new .glb
godot --path . --resolution 540x960 --script res://tests/_shot.gd
open /tmp/shot_binairo.png
```
