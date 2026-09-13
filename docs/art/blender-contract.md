# Blender contract

The whole agreement between a model made in Blender and the game. If a model
follows these rules, exporting it to `assets/models/<slot>.glb` is the entire
integration: the game finds it by name, converts its materials to the toon
shader, adds the outline, and places it. Nothing else to configure.

## Slots

| slot | footprint (X by Y in Blender) | max height (Z) | notes |
|---|---|---|---|
| `tile` | 1.0 x 1.0, use about 0.94 | 0.14 | emblems sit on its top face |
| `emblem_sun` | inside 0.6 x 0.6 | 0.08 | orange sun with rays, lies flat on a tile |
| `emblem_moon` | inside 0.6 x 0.6 | 0.08 | ivory crescent, lies flat on a tile |
| `empty_mark` | inside 0.2 x 0.2 | 0.04 | small diamond on an empty tile |
| `platform` | exactly 1.0 x 1.0 | 0.6 | a unit stone slab; the board stretches it to (cols + 1, rows + 1), so keep the material a plain colour |
| `water` | any, about 60 x 60 | flat | the water plane far below the platform |

Concept reference: `docs/art/concept-binairo-island.png`. Moss trim and
cliffs around the platform come later as separate models once the platform
shape is settled.

The list lives in code as `SLOTS` in `core/models.gd`. New puzzles add rows.

## Rules

1. **Units.** Metric, unit scale 1.0. One Blender unit is one board cell.
2. **Origin at the centre of the base.** The lowest vertex is at Z = 0 and
   the footprint is centred on X = Y = 0. Blender is Z-up; the glTF exporter
   converts to Godot's Y-up for you, so model with Z as up and do nothing else.
3. **Apply transforms.** Rotation (0, 0, 0), scale (1, 1, 1) before export.
4. **Shade smooth with shared vertices.** No split edges, no flat shading,
   no Edge Split modifier. Hard-edge looks come from Shade Auto Smooth
   (Smooth by Angle) or Weighted Normal instead. Reason: the outline draws a
   second copy of the mesh pushed out along the vertex normals; split
   vertices leave visible gaps at every corner.
5. **Materials are colours.** One Principled BSDF per material, Base Color set,
   nothing else needed. The game replaces every material with the toon shader
   using that base colour. Textures export fine but are ignored by the toon
   shader for now.
6. **`_flat` suffix.** A material named like `Wood_flat` gets toon shading but
   no outline. Use it for the table and any surface that should not read as a
   piece.
7. **Export settings.** glTF Binary (`.glb`), +Y Up, Apply Modifiers,
   Selected Objects, Materials: Export, no cameras, no lights, no animation.
   File name is the slot name. The script below does all of this.

## Export script

`tools/blender_export.py` checks the rules and exports. Inside Blender, open
the Scripting tab, load the file and run it with the objects selected, or
from a shell:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/pieces.blend \
  --python tools/blender_export.py -- tile token_circle token_square
```

With no names it exports the selected objects; with nothing selected, every
top-level mesh. Object names are lowercased to form the slot name. Each
object prints one line, `OK` with the output path or `SKIP` with the rule it
broke, and the process exits non-zero if anything was skipped.

## Seeing it in the game

```bash
godot --headless --path . --import          # register the new .glb
godot --path . --resolution 540x960 --script res://tests/_shot.gd
open /tmp/shot_binairo.png
```
