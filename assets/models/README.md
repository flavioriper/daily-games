# Models

Drop Blender exports here as `<slot>.glb`. The game looks for these names
(see `core/models.gd` SLOTS) and falls back to a primitive placeholder for
any that are missing:

| slot | what it is |
|---|---|
| `tile` | one board cell, 1 x 1 footprint, about 0.14 tall |
| `emblem_sun` | sun emblem laid on a tile top (Binairo "sun") |
| `emblem_moon` | crescent emblem laid on a tile top (Binairo "moon") |
| `empty_mark` | small diamond laid on an empty tile |
| `platform` | 1 x 1 stone slab the board stretches to its size, top at y = 0 |
| `water` | flat water plane far below the platform |

Concept reference: `docs/art/concept-binairo-island.png`.
