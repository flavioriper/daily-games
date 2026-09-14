# daily-games

Prototypes for a mobile-only daily puzzle game, built in Godot 4.7.

Ten puzzle mechanics are playable end to end. Nothing here is a shipping
decision yet -- the point is to judge each mechanic by thumb on a real phone
before committing to a lineup.

## Running

```bash
godot --path .          # portrait, 1080x1920, touch emulated from mouse
```

Every prototype is reachable from the menu. Boards sit on a 3D toon-shaded stage. Binairo's pieces are Blender exports
in `assets/models/`, rebuilt with `tools/build_models.sh`; any slot without an export falls back to a primitive
placeholder (see `docs/art/blender-contract.md`).

The HUD around every board is the concept chrome: wordmark, back / undo / hint / settings, day card, rules card,
working-line card, Reset and Check; Binairo has real undo, hint (three) and check.

## Tests

```bash
# Generator correctness -- uniqueness proofs, determinism, minimality
godot --headless --path . --script res://tests/run_tests.gd

# End-to-end: drive every puzzle to its solved state through real touch events
# (also presses Binairo's Hint and Check buttons through the HUD)
godot --path . --resolution 540x960 --script res://tests/_win.gd

# Screenshot every prototype to /tmp/shot_<id>.png
godot --path . --resolution 540x960 --script res://tests/_shot.gd

# Animation strip for Binairo (entrance, tap, roll, idle) plus draw calls and frame time
godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd
```

Reduce-motion is read from `user://settings.cfg`, section `[motion]`, key
`reduce`; a missing file defaults to full motion. The settings sheet (gear button) toggles it in the game.

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
core/       shared: puzzle interface, daily seeding, palette, shape helpers,
            motion.gd (tween recipes, reduce-motion)
puzzles/    <id>_gen.gd is pure logic and headless-testable
            <id>.gd is the board and its touch handling
ui/         menu, puzzle host shell, registry, theme (fonts, cards, buttons), icons; ui/hud/ the HUD panels
tests/      unit suites plus the win and screenshot harnesses
docs/       the 75-candidate catalog and build notes
world/      3D stage: camera rig, sun, sky, water; main scene; ambient.gd
            (grass sway, pollen, water splash, camera breath) and fx.gd
            (one-shot particles: dust, sparkle)
shaders/    toon and outline spatial shaders, plus the wind (toon_wind) and
            water shaders and the shared toon_lit include
assets/     models/<slot>.glb from Blender, placeholders otherwise; fonts/ Fredoka and Nunito (OFL)
tools/      blender_export.py, run inside Blender
```

## Docs

- `docs/brainstorm/specs/` — small spec for each of 75 candidate mechanics
- `docs/brainstorm/prototypes.md` — what building these ten actually taught
- `docs/art/blender-contract.md` — modelling rules and export for 3D pieces
