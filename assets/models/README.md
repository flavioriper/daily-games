# Models

Drop Blender exports here as `<slot>.glb`. The game looks for these names
(see `core/models.gd` SLOTS) and falls back to a primitive placeholder for
any that are missing:

| slot | what it is |
|---|---|
| `tile` | one board cell: a cube of side 0.84 standing on the platform, an assembly of three layers -- the `Stone` body plus the `Sun` and `Moon` inlaid in opposite pairs of its walls, like the pips of a die. Top and bottom are bare, which is the empty state |
| `rim_edge` | moss strip, 1 x 0.5, on one cell of the platform lip (outward side at +Z in Godot) |
| `rim_corner` | moss square, 0.5 x 0.5, on a platform corner (outward corner at +X +Z) |
| `platform` | 1 x 1 stone slab the board stretches to its size, top at y = 0 |
| `water` | flat water plane far below the platform |
| `focus_ring` | flat translucent frame the board slides onto the last tapped cell; unshaded, no outline, never tinted |
| `mascot_pom` | POM the puppy, an assembly of 15 layered parts, one mesh per layer (not yet placed by any board) |

`tile` is recoloured **by material name**: only its `Stone` body takes the
colour of the state that is up, and the inlaid `Sun` and `Moon` keep the
colours they were modelled with. The other slots are never tinted and may use
several materials.

The `platform`, `water`, `rim_edge` and `rim_corner` materials
must be named with the `_flat` suffix (for example `Rock_flat`), or they get
an outline shell the design does not want on them. The rim's grass, petals
and pollen also carry `_sway` so they wave in the wind; the moss does not.

The rim pieces here are generated: `tools/build_models.sh` rebuilds them from
`tools/build_pieces.py`, exports through the contract checks and re-imports.
The tile and the mascots are not: they are modelled by hand in `art/tile.blend`
and `art/mascot_<name>.blend` (both tracked in git) and exported from there as
a collection, one `.glb` holding every layer. The same script exports the tile
in the same run.

Full rules: `docs/art/blender-contract.md`.
Concept reference: `docs/art/concept-binairo-island.png`.
