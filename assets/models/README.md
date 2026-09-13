# Models

Drop Blender exports here as `<slot>.glb`. The game looks for these names
(see `core/models.gd` SLOTS) and falls back to a primitive placeholder for
any that are missing:

| slot | what it is |
|---|---|
| `tile` | one board cell, 1 x 1 footprint |
| `token_circle` | the "circle" token in Binairo |
| `token_square` | the "square" token in Binairo |
| `given_ring` | ring laid over a locked clue cell |
| `table` | the surface the board sits on |

Modelling rules and the export script: `docs/art/blender-contract.md`.
