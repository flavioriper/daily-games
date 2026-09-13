# daily-games

Prototypes for a mobile-only daily puzzle game, built in Godot 4.7.

Ten puzzle mechanics are playable end to end. Nothing here is a shipping
decision yet -- the point is to judge each mechanic by thumb on a real phone
before committing to a lineup.

## Running

```bash
godot --path .          # portrait, 1080x1920, touch emulated from mouse
```

Every prototype is reachable from the menu. Boards sit on a 3D toon-shaded stage. Models are primitive placeholders until
Blender exports land in `assets/models/` (see `docs/art/blender-contract.md`).

## Tests

```bash
# Generator correctness -- uniqueness proofs, determinism, minimality
godot --headless --path . --script res://tests/run_tests.gd

# End-to-end: drive every puzzle to its solved state through real touch events
godot --path . --resolution 540x960 --script res://tests/_win.gd

# Screenshot every prototype to /tmp/shot_<id>.png
godot --path . --resolution 540x960 --script res://tests/_shot.gd
```

## The puzzles

| Puzzle | Gesture | Uniqueness proof |
|---|---|---|
| Binairo | tap-cycle | backtracking count to 2 |
| Code Break | tap-cycle | — calibration, not uniqueness |
| Balance | tap-cycle | brute force over the domain |
| Pipes | tap-rotate | free by construction |
| Untangle | drag | — any planar embedding wins |
| Shikaku | drag rect | exact cover count to 2 |
| Tents | tap-cycle | matching search count to 2 |
| Light Up | tap-cycle | backtracking count to 2 |
| One Line | drag path | degree parity, no search at all |
| Nonogram | tap-cycle | line-solvable implies unique |

A daily puzzle that turns out to have two answers is the worst bug this product
can ship, so every generator proves its instance is uniquely solvable before
handing it over. That is what the bulk of the test suite covers.

## Layout

```
core/       shared: puzzle interface, daily seeding, palette, shape helpers
puzzles/    <id>_gen.gd is pure logic and headless-testable
            <id>.gd is the board and its touch handling
ui/         menu, puzzle host shell, registry
tests/      unit suites plus the win and screenshot harnesses
docs/       the 75-candidate catalog and build notes
world/      3D stage: camera rig, sun, sky, table; main scene
shaders/    toon and outline spatial shaders
assets/     models/<slot>.glb from Blender, placeholders otherwise
tools/      blender_export.py, run inside Blender
```

## Docs

- `docs/brainstorm/specs/` — small spec for each of 75 candidate mechanics
- `docs/brainstorm/prototypes.md` — what building these ten actually taught
- `docs/art/blender-contract.md` — modelling rules and export for 3D pieces
