# Binairo polish: motion, effects and the concept HUD — design

Date: 2026-09-13. Status: approved for planning (sub-project 1).

Concept references: `docs/art/concept-binairo-island.png` (the Binairo screen)
and the "Peeplet Daily" main-list concept the user shared on 2026-09-13
(paper cards, stone-wall list, blue play buttons, wooden signs, a motto
footer). The second image is a style reference for the shared theme; the
menu itself is not rebuilt in this pass.

## Goal

Take the Binairo screen from "renders correctly" to cozy: everything the
player touches answers with motion, the world breathes on its own, and the
HUD becomes the concept's HUD with real behaviour behind every button. This
document records every decision taken with the user, splits the work into
three sub-projects, and specifies the first one in full. Sub-projects 2 and
3 get their own short brainstorm and spec when their turn comes.

## Decisions taken with the user

| Question | Decision |
|---|---|
| Scope | Full concept HUD plus motion. Undo, hint, check and the two info cards get real behaviour. Split into three sub-projects. |
| Check button | Solving stays automatic (the puzzle completes on the last correct cell). Check is a helper: cells that differ from the solution wobble and blush for a moment. Unlimited, but counted in the end stats. |
| Info cards | Top card: `Day N · <island name>`, N counting puzzles played, the island name from a themed list seeded by the date. Bottom card: the row or column of the last tapped cell with dots filling sun-orange or moon-slate, e.g. `Row 3 · 4/6`. |
| 3D props | Lantern and wooden sign are modelled now (they carry flicker and sway). Cliffs, waterfalls, houses, trees, bridges stay deferred (Amendment C of the pipeline spec). Water gets its ripple shader now. |
| Mascot | Deferred. POM is modelled but is **not** placed or animated in this pass (user, 2026-09-13: "don't worry about the mascots for now"). |
| Fonts and icons | OFL fonts from Google Fonts into `assets/fonts` with licence files (a rounded display face for titles, a clean body face). Icons drawn as vector polygons in GDScript so they take the palette and animate. |
| Sound | None yet. Every effect names an audio cue through a no-op hook so sounds attach later without touching animation code. |
| Order | 1) board and world motion, 2) HUD rebuild, 3) props and celebration. |
| Architecture | A static motion library of tween recipes plus shader-driven ambience. No editor-authored animations, no per-node self-animating scripts. |

## Non-goals for the whole pass

- Converting any other board. Only Binairo.
- Scenery beyond the platform other than the lantern and the sign.
- Placing or animating POM.
- Audio assets.
- Saving progress beyond what the day counter needs.

## The three sub-projects

**1. Board and world motion** (this document, below). The motion library,
the reduce-motion switch, every board effect (roll settle, neighbour bob,
dust, focus glow, blush pulse, entrance, reset wave, solved wave), the
ambience (grass sway, water ripple, pollen, camera breath), and the two
primitives sub-project 2 needs (sparkle, wobble).

**2. HUD rebuild.** The concept's chrome on top of the stage: wordmark with
leaf, back / undo / hint / settings buttons with press squish and a bouncing
hint badge, the day card, the rules parchment, the working-line card, Reset
and Check, the motto footer, entrance choreography for every panel, and the
logic behind undo (a move history; undo rolls the prism one third *away*
from the player, the only unwinding roll), hint (fills one safe cell from
the solution with a sparkle, three per puzzle, hinted cells lock and take
the given tint), check (wobble plus blush beat on cells that differ from the
solution, counted), and a settings sheet holding at least the reduce-motion
toggle. The shared theme (fonts, card styles, button styles) is built here
and should carry over to the menu with no further design work; the menu's
own layout rebuild is out of scope until asked for.

**3. Props and celebration.** Lantern and sign modelled in the live Blender
session and exported through the contract (one mesh per layer), an
`OmniLight3D` with a warm flicker in the lantern, a slow sway on the sign,
and the solve celebration built on sub-project 1's solved wave: a petal or
confetti burst, the panels reacting, and the solved card sliding up with
stats and share glyphs.

## Sub-project 1: board and world motion

### 1. Motion foundation: `core/motion.gd`

A static library (`RefCounted`, static functions and one static flag). Every
recipe creates its tween on the target node with `node.create_tween()` and
returns it, so callers can chain `finished` and headless tests can drive it
with `custom_step`, exactly as `tests/test_binairo3d.gd` drives the roll.

```gdscript
static var reduce: bool          # read from user://settings.cfg, [motion] reduce
static func load_settings() -> void
static func save_settings() -> void

# Recipes. `essential` marks motion that *is* the state change (the roll);
# decorative motion is skipped under reduce.
static func settle(node: Node3D, property: String, target, time: float,
                   delay := 0.0, essential := false) -> Tween
static func hop(node: Node3D, height: float, time: float, delay := 0.0, base := NAN) -> Tween
static func squash(node: Node3D, amount := 0.12, time := 0.18, delay := 0.0) -> Tween
static func wobble(node: Node3D, angle := 0.12, time := 0.45) -> Tween
static func fade(node: Node, setter: Callable, from: float, to: float, time: float,
                 steps := 16, delay := 0.0) -> Tween
static func stagger(index: int, per: float, cap := 0.6) -> float
```

Amendment (Task 11): `fade` gained a leading `node: Node` parameter, since the
tween needs a node to live on. `hop` gained a trailing `base := NAN`, the
resting height, for nodes that may already be mid-hop.

- `settle` tweens `property` to `target` with `TRANS_BACK`, `EASE_OUT`: it
  overshoots by roughly a tenth of the distance and springs back.
- `hop` moves `position:y` up by `height` and back (two `SINE` halves).
  A negative height is a dip.
- `squash` scales y down by `amount` and x, z up by half of it, then back
  with `TRANS_BACK`.
- `wobble` drives `rotation:z` through `tween_method` with
  `angle * sin(6π t) * (1 - t)²`, landing exactly on the starting angle.
- `fade` calls `setter(value)` with `value` quantised to `steps` equal
  levels between `from` and `to`, so a colour fade produces a bounded set of
  colours (the toon material cache is keyed by colour).
- `stagger(i, per, cap)` returns `min(i * per, cap)`, the delay for the
  i-th element of a wave.

Reduce-motion behaviour, applied inside every recipe:

- Decorative recipes (everything with `essential == false`, plus `hop`,
  `squash`, `wobble`, `fade`) set the final state at once and return `null`.
  Callers guard with `if tw != null`.
- Essential recipes keep a short linear motion: `time` becomes 0.15 s, no
  overshoot.
- The flag is persisted in `user://settings.cfg` under `[motion]` as
  `reduce`. Sub-project 2 adds the toggle; sub-project 1 only reads and
  writes it and defaults to `false`.

Amendment (final review): `Stage._ready()` calls `Motion.load_settings()`, so
any headless suite that builds a `Stage` reads (and can be overwritten by)
the developer's real `user://settings.cfg`. `tests/test_ambient.gd` and
`tests/test_binairo3d.gd` now point `Motion.settings_path` at a throwaway
`user://_test_settings.cfg` before creating the stage and restore
`user://settings.cfg` after teardown, the same pattern `tests/test_motion.gd`
already used for its own settings round-trip test.

### 2. Board effects: `puzzles/binairo3d.gd`

The grid still changes at once on tap; every effect below is only how the
change is shown. Per-cell bookkeeping grows from `_rolls` to a small
dictionary of running tweens per cell (`roll`, `hop`, `bob`, `fade`), and
`_settle(r, c)` kills all of them and snaps rotation, `position.y` and the
face colour home.

| Effect | Behaviour | Numbers | Audio cue |
|---|---|---|---|
| Roll settle | `Motion.settle(pivot, "rotation:x", target, ROLL_TIME, 0, true)`. The prism overshoots the landing face by about 8 percent of a third-turn and springs back. In parallel a `hop` on the pivot lifts it so the roll reads as a hop, not a grind. All three emblems stay visible until the tween finishes, then the two buried faces hide as today. | `ROLL_TIME` 0.34 s, lift 0.04 | `roll` |
| Neighbour bob | On a tap, the four side neighbours dip and return; the four diagonals dip half as much, a beat later. A cell that is rolling is skipped; starting a roll on a bobbing cell kills the bob first, so no cell ever runs two `position:y` tweens. Given cells bob too; stone is stone. | dip 0.02, 0.35 s, side lag 0.04 s, diagonal lag 0.07 s | none |
| Dust puff | When a roll lands, `Fx.puff` at the cell's near edge (the arriving face's leading edge touches down on the player's side): stone-coloured specks rise, arc and shrink to nothing. | 6 to 8 specks, 0.4 s, at `(x, TILE_RISE, z + TILE_SIDE / 2)` | `land` |
| Focus glow | One `focus_ring` model, child of `board`, sitting flat at `TILE_RISE + 0.005` around the last tapped cell. First tap: pops in (scale 0.8 to 1, alpha 0 to 0.9). Later taps: slides to the new cell. While shown it pulses. After a pause with no tap it fades and hides. Reset, new puzzle and solve all fade it. It never parents to a pivot, so it never rolls. A tap on a given cell moves the ring too and dips that cell 0.02 (it is solid), but rolls nothing and bobs no neighbours; this is the "look at this line" gesture the working-line card in sub-project 2 reads. | pop 0.15 s, slide 0.15 s, pulse scale 1.00 to 1.04 and alpha 0.9 to 0.6 over 1.2 s looping, fade after 2.5 s over 0.5 s | `focus` |
| Blush pulse | `_recolour()` computes a target blend per cell (0 or `BAD_BLEND`). Cells whose blend changed run `Motion.fade` toward it, calling `_paint(r, c, blend)` which tints the four named faces at that blend. A newly broken line, after the fade in, gives two heartbeats to `BAD_BLEND + 0.15` and back. A fixed line fades back. A new recolour kills a running fade. `_blend_target` tracks the blend each cell is heading for, so a still-broken line's beats are not restarted by an unrelated recolour elsewhere on the board. | `BAD_BLEND` 0.375 (6/16), heartbeat adds 0.125 (2/16) so every level sits on the 16-step grid; in 0.25 s, beats 0.8 s total, out 0.4 s, 16 quantisation steps | `blush_in`, `blush_out` |
| Board entrance | After `_build_scene`, the `Platform` node starts 0.5 below and settles to y 0 (`TRANS_BACK`). As it breaks the surface, `Ambient.splash(centre)` rings the water; the board reaches `Ambient` through the stage it is mounted on (`_stage.ambient`), and skips the call when there is no stage. Every pivot starts at scale 0.01 and pops to 1 with `TRANS_BACK`, delayed by `stagger(r + c, 0.03)` after the platform lands: a diagonal wave from the far-left corner (row 0, column 0). Taps are accepted throughout; scale, rotation and position are separate properties and never fight. Reset during the entrance kills the entrance tweens and snaps scales to 1. | platform 0.5 s, pop 0.25 s, 8 x 8 board fully in at about 1.2 s | `enter` |
| Reset wave | `reset_board()` rolls every free, non-empty cell *forward* to empty (sun takes two thirds, moon one) with a diagonal stagger from the near-left corner (row n-1, column 0). These rolls are essential motion, so reduce-motion shortens rather than skips them. Given cells hop a little at their stagger time to say they stay. The grid, `moves` and the blush update at once, as today; only the prisms take their time. Replaces the instant snap. | one third 0.30 s, two thirds 0.42 s, stagger 0.02 s per diagonal, given hop 0.03 | `reset` |
| Solved wave | On `solved`, every pivot hops once, row by row from the top (row 0). The focus ring fades. This is the base sub-project 3 builds the celebration on. | hop 0.08 over 0.4 s, `stagger(r, 0.04)` | `solved` |
| Sparkle (primitive) | `Fx.sparkle(at, colour)`: small four-point stars rise and shrink. Built now, used by the hint in sub-project 2. | 10 stars, 0.6 s, default colour `SUN` | `hint` |
| Wobble (primitive) | `Motion.wobble(pivot)`: a damped side-to-side shake. Built now, used by the mistake check in sub-project 2. | angle 0.12 rad, 0.45 s | `check` |

Roll direction is unchanged: always toward the player, the turn count only
grows. The only unwinding roll is undo, which belongs to sub-project 2.

Face visibility during the overshoot is safe: rotating a further 8 percent
past the landing face tilts the *next* buried face up by about 10 degrees,
still well inside the platform.

Amendment (final review): `_settle` kills the roll, the lift and the bob and
snaps rotation and height home; it does not touch the blush. The blush's
blend and its fade belong to the board-wide `_blend_target` bookkeeping in
`_recolour` / `_fade_blend`, not to per-cell settle, so tapping a cell mid-fade
leaves the fade running.

Amendment (final review): the solved wave's hops are delayed by
`ROLL_TIME + stagger(r, SOLVE_STAGGER)`, not `stagger(r, 0.04)` alone, so the
last roll's own lift has landed before its row's solve hop starts.

Amendment (final review): blush fades are created on the cell's tile node
(`_tiles[r][c]`), not on `board`. A fade built on `board` outlives
`_build_scene`, which frees the board's children but not `board` itself, so a
second `build()` on the same instance left stale fades running and
repainting the new board's tiles. `_build_scene` now also calls `_stop_all()`
as its first line, killing every tween the previous board still tracks
(entrance, rolls, hops, bobs, fades and the focus ring) before the arrays
that back them are reset.

### 3. One-shot particles: `world/fx.gd`

`Fx` is a `Node3D` the board creates as its own child in `_build_scene`, so
positions are board-local. It pools `CPUParticles3D` emitters, which the Compatibility renderer
supports, and picks the next one round-robin per call:

- `puff(at: Vector3, colour := Pal.STONE)`: pool of 4. `amount` 8,
  `lifetime` 0.4, `one_shot`, `explosiveness` 1, direction up with 60
  degree spread, initial velocity 0.5 to 0.9, gravity -1.5 for the arc,
  scale 0.05 falling to 0 on a curve. Mesh: a `QuadMesh` billboard with an
  unshaded `StandardMaterial3D` in `colour`. Materials cached per colour.
- `sparkle(at: Vector3, colour := Pal.SUN)`: pool of 2. `amount` 10,
  `lifetime` 0.6, upward with 40 degree spread, velocity 0.3 to 0.6, no
  gravity, scale 0.04 to 0. Mesh: a billboard quad textured with a code-drawn
  32 x 32 four-point star (`Image` to `ImageTexture` at load), alpha on.
- `cue(name: String)`: the audio hook. A no-op today; every effect in the
  table above calls it with its cue name.

Under reduce-motion `puff` and `sparkle` do nothing.

### 4. Ambience: `world/ambient.gd` and shaders

`Ambient` is a `Node3D` the stage creates in `_ready` as `Ambient`. It owns
the continuous motion and the one switch that stills it.

**One global shader parameter.** `motion_scale` (float, 1 or 0) declared in
`project.godot` under `[shader_globals]` and set by `Ambient.refresh()` from
`Motion.reduce` via `RenderingServer.global_shader_parameter_set`. Every
ambient shader multiplies its amplitude or its time by it, so reduce-motion
freezes the water, flattens the grass and stops the pollen and the camera
breath in one place. `refresh()` runs on ready and whenever the flag changes.

**Grass and flower sway.** `shaders/toon_wind.gdshader` is the toon shader
with a vertex stage. To avoid two copies of the lighting, the fragment and
light code moves into `shaders/toon_lit.gdshaderinc` and both `toon` and
`toon_wind` `#include` it. Vertex stage:

```glsl
global uniform float motion_scale;
uniform float sway_base = 0.03;    // local y where the moss top is
uniform float sway_height = 0.07;  // local y span over which sway reaches full
uniform float sway_amount = 0.02;  // world units at the tip
uniform float sway_speed = 1.6;

void vertex() {
    float h = clamp((VERTEX.y - sway_base) / sway_height, 0.0, 1.0);
    h *= h;                                          // roots stay planted
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float ph = TIME * sway_speed + wp.x * 0.9 + wp.z * 0.7;
    VERTEX.x += sin(ph) * sway_amount * h * motion_scale;
    VERTEX.z += cos(ph * 0.8) * sway_amount * 0.6 * h * motion_scale;
}
```

Which surfaces sway is a material-name convention, the same way `_flat`
already skips the outline: a material whose name **contains `_sway`** gets
the wind material from `Toon.wind_material(albedo)` (its own cache) instead
of `Toon.material(albedo)`. `Toon.apply_to` makes the choice. The rim pieces
are regenerated by `tools/build_pieces.py` with `Grass_sway_flat`,
`Petal_sway_flat` and `Pollen_sway_flat` (`Moss_flat` stays still) and
re-exported with `tools/build_models.sh`. Limit, recorded in the contract:
the outline shell shares the mesh but not the wind, so a `_sway` material
must also be `_flat` for now.

**Water.** `shaders/water.gdshader`, lit with the same two-band step as the
toon shader, so the platform's shadow still falls on it, on the `water` slot
(the `Models.instance("water")` path applies it whether the slot is the
placeholder plane or a future `.glb`):

- Base `WATER`. Two slow sine fields over world xz, summed and cut with
  `step`, give hard drifting highlight stripes in `WATER_HI`.
- A product of two faster sines cut at a high threshold gives small cream
  sparkle dots in `MOON`.
- `uniform float splash_age` (negative means none) and
  `uniform vec3 splash_origin` draw one expanding ring in `WATER_HI`:
  radius `splash_age * 3`, width 0.15, fading out over 2 s. `Ambient.splash(
  origin)` sets the origin and drives `splash_age` from its own `_process`
  clock so the ring is deterministic and skippable under reduce-motion.
- All time terms are `TIME * motion_scale`.

**Pollen.** One `CPUParticles3D` named `Pollen` under `Ambient`: `amount`
24, `lifetime` 6, `preprocess` 6 so the air is already populated on the
first frame, a box emission volume that `Ambient.fit_to(aabb)` sizes to the
board plus a one-cell margin, one cell above the tiles and 0.4 tall.
Direction `(1, -0.15, 0.2)`, spread 20 degrees, velocity 0.08 to 0.16, no
gravity, scale 0.025 to 0.04, billboard quad in `MOON` at 0.85 alpha with a
colour ramp that fades each speck in and out. `Stage.fit_camera` forwards
the AABB to `fit_to`. Reduce-motion stops emission and clears the particles.

**Camera breath.** `CameraRig` gains a small additive offset recomputed in
`_process` and applied in `_place()` on top of the fitted position: the
camera and its look-at target move together by
`(sin(t · 2π / 8), 0.6 · sin(t · 2π / 11), 0)` in camera right and up,
scaled to 0.2 percent of the fitted distance (a couple of pixels). Off under
reduce-motion. Flagged try-and-keep: if the animation shot strip reads as
wobble instead of calm, the offset is removed and the spec amended.
`fit()` is unaffected, since the offset is applied after fitting and is
tiny compared with the 6 percent margin.

Amendment (Task 11): decision kept. Judged from the `_shot_anim.gd` idle
frames (2026-09-13) — the board sits in the same place against the fixed
HUD between the two idle frames a second apart, the only visible changes
are grass lean, water pattern and pollen position, and 0.2 percent of the
camera distance is imperceptible as motion at 1080 x 1920. `breathing`
stays `true`. The interactive 20-second live check the plan's Step 3
describes was not run on 2026-09-13; this decision rests on the strip
frames alone, so a live look on a phone is still owed.

Amendment (final review): the splash ring is 0.3 world units wide
(`step(abs(d - splash_age * 3.0), 0.15)`, a band 0.15 either side of the
ring's radius). The dashes and sparkles are tuned to read at cell scale
rather than as snowfall over cloud smears: dashes at
`dot(p, vec2(0.80, 0.45)) * 4.0` and `dot(p, vec2(-0.35, 0.90)) * 1.2` (were
1.6 and 0.5), threshold 1.25 unchanged; sparkles at `p.x * 2.4 + wx` and
`p.y * 2.0 + wz` (were 7.3 and 6.1), threshold 0.998 (was 0.995).

### 5. Palette additions (`core/palette.gd`)

| name | hex | use |
|---|---|---|
| `FOCUS` | `7fd1ff` | focus ring |
| `WATER_HI` | `5fb0e8` | water stripes and splash ring |

Dust uses `STONE`, sparkle uses `SUN`, pollen uses `MOON`.

### 6. Model slots, contract and tooling

- New slot `focus_ring`: a flat square frame, outer half-size 0.46, inner
  0.40, thickness 0.01, base at y 0, unshaded transparent material in
  `FOCUS`, no outline, never tinted. `Placeholders.make("focus_ring")`
  builds it from four thin boxes; a Blender export may replace it later.
  Added to `Models.SLOTS` and to the contract and README tables.
- `Models.instance("water")` always applies the water material, placeholder
  or export.
- Contract rule 11: `_sway`. "A material whose name contains `_sway` bends
  in the wind: vertices above the sway base lean by height, so keep the
  planted part of a tuft below local z 0.03. Use it for grass, petals and
  leaves. Until the outline follows the wind, a `_sway` material must also
  end in `_flat`." The rim rows in the slot table name the three sway
  materials.
- `tools/build_pieces.py` renames the three rim materials; the exporter
  needs no change, since `_flat` is still the suffix.
- `project.godot` gains the `[shader_globals]` entry for `motion_scale`.

Amendment (final review): the focus ring's inner half-size is 0.38
(`Placeholders.FOCUS_INNER`), not 0.40 — widened in Task 11 so the ring's
bars read at 540 px. The placeholder is four flat quads at y = 0
(`Placeholders._ring_mesh`), not four thin boxes 0.01 thick.

### 7. Performance budget

Measured with `tests/_shot_anim.gd` (below), which prints
`RENDER_TOTAL_DRAW_CALLS_IN_FRAME` and the mean frame time over its idle
window, on the 8 x 8 board at 1080 x 1920 on the Mac:

- Idle frame time at or under 8 ms, so a phone at half the speed still
  makes 60 fps. Checked again on the iOS simulator before the sub-project is
  called done.
- Draw calls at most 10 above today's count at rest: the focus ring, the
  pollen and idle particle pools are the only new instances.
- Live particles never exceed 64 across the scene (24 pollen plus at most
  four puffs and two sparkles in flight).
- Tween count peaks during the entrance at one per cell plus one; that is
  fine, tweens are cheap.

Measured (2026-09-13) with `tests/_shot_anim.gd` at 1080 x 1920, vsync off,
on the daily's first Binairo puzzle: `idle frames=398 mean_ms=5.03
max_draw_calls=755`. Comfortably under the 8 ms budget; the draw-call
baseline comparison against Task 7 was not run (recorded as optional), so
755 is the number to compare future changes against.

Amendment (final review): live particles peak at 76, not 64: 24 pollen plus
the puff pool (4 emitters at `amount` 8, 32 live particles if every emitter
fires at once) and the sparkle pool (2 emitters at `amount` 10, 20 live
particles), not one particle per emitter.

### 8. Testing

Headless suites (`godot --headless --path . --script res://tests/run_tests.gd`):

- **New `tests/test_motion.gd`.** Each recipe returns a running tween;
  stepping it by its full time lands exactly on the final value (rotation,
  position, scale, and the fade's last quantised level equals `to`). With
  `Motion.reduce = true` a decorative recipe returns `null` and the final
  state is already set; an essential `settle` returns a tween of 0.15 s.
  `stagger` is monotonic and capped. `wobble` ends on its starting angle.
  Runs in `run_in_tree` (node-bound tweens).
- **`tests/test_binairo3d.gd` extended.** The roll still lands exactly on
  the face (the halfway check steps a quarter of `ROLL_TIME`, since the
  back ease is already overshooting at the half). After the entrance tweens
  are stepped to their end, every pivot has scale one and the platform is
  at y 0. After `reset_board()` and stepping every running tween, every
  prism is home and nothing runs. The focus ring's position equals the
  last tapped cell's centre. A blush fade, stepped to its end, leaves the
  face at exactly `STONE.lerp(BAD, BAD_BLEND)`. A neighbour bob, stepped to
  its end, leaves the neighbour's pivot on the axis height.
- **`tests/test_toon.gd` extended.** A `StandardMaterial3D` named
  `Grass_sway_flat` becomes a wind material; one named `Moss_flat` stays a
  plain toon material; a wind mesh gets no outline. Sixteen quantised blend
  levels between two colours add at most 17 entries to the material cache.
- **`tests/test_models.gd` extended.** The slot list includes `focus_ring`;
  its placeholder fits a 1 x 1 footprint, sits at y 0, has no outline; the
  `water` slot's surface material is the water shader.
- **`tests/test_platform.gd`.** Unchanged in intent; the rim material names
  it may assert on follow the rename.
- **`tests/test_ambient.gd`.** `Ambient` and camera breath: `refresh()` sets
  `motion_scale` from `Motion.reduce`, `fit_to` sizes the pollen emitter to
  the board AABB, `splash()` drives `splash_age` deterministically, and
  `CameraRig`'s breath offset is off under reduce-motion.
- **`tests/test_fx.gd`.** The `Fx` pools: `puff` and `sparkle` round-robin
  their emitters, materials are cached per colour, and both are no-ops
  under reduce-motion.

Visual and end-to-end harnesses:

- **New `tests/_shot_anim.gd`.** Opens Binairo, saves six frames to
  `/tmp/anim_binairo_<n>.png` (two during the entrance, one at the tap, one
  mid-roll, two during idle a second apart), and prints draw calls and mean
  frame time over the idle window. This is how the ambience is judged by eye
  (the frames are read back with the image reader) and how the budget is
  measured.
- **`tests/_win.gd`** keeps passing unchanged. It taps cell centres during
  the entrance and mid-animation; taps land on the plane whatever the pivot
  scale, and a tap on a rolling cell settles it first, as today.
- **`tests/_shot.gd`** lengthens its per-puzzle slot so the screenshot lands
  after the entrance has finished (about 1.5 s after opening), otherwise it
  would capture half-popped tiles.

### 9. Files

New: `core/motion.gd`, `world/fx.gd`, `world/ambient.gd`,
`shaders/toon_lit.gdshaderinc`, `shaders/toon_wind.gdshader`,
`shaders/water.gdshader`, `tests/test_motion.gd`, `tests/_shot_anim.gd`,
`tests/test_ambient.gd`, `tests/test_fx.gd`.

Modified: `puzzles/binairo3d.gd`, `core/toon.gd`, `core/models.gd`,
`core/placeholders.gd`, `core/palette.gd`, `world/stage.gd`,
`world/camera_rig.gd`, `shaders/toon.gdshader` (moves its bodies into the
include), `tools/build_pieces.py`, `assets/models/rim_edge.glb`,
`assets/models/rim_corner.glb` (regenerated), `docs/art/blender-contract.md`,
`assets/models/README.md`, `project.godot`, `tests/run_tests.gd` (registers
the new suite), `tests/_shot.gd` (longer slot), `tests/test_binairo3d.gd`, `tests/test_toon.gd`,
`tests/test_models.gd`, `README.md` (the new harness).

Amendment (final review): `tests/test_palette.gd` is also modified (the
focus-ring and water palette additions). Blush fades are created on the tile
node, not on `board` (see the amendment under section 2).

### 10. What sub-project 2 relies on from here

`Motion` (all recipes and the `reduce` flag with its persistence),
`Fx.sparkle`, `Fx.cue`, `Motion.wobble`, the focus ring's notion of "last
tapped cell" (the working-line card reads the same cell), and
`Ambient.refresh()` for the settings toggle.

## Amendment C: the cell is a cube, not a trilon (2026-09-14)

The trilon is withdrawn. On screen a cell read as a flat card, and the cause
is geometric rather than a bug: at the board camera's 68-degree pitch the
prism's two sloped faces are back-facing (normal dot view = -0.14) and its
caps are edge-on, so at rest a cell rendered **only its horizontal top face**.
Every horizontal face lands in the same top band of the three-step toon ramp
(N dot L = 0.77, past the 0.70 offset), so an entire cell measured one flat
`(251, 224, 184)` with no gradient anywhere; the only depth cue left was a
5-pixel shadow sliver in the gap between tiles. Burying the prism deeper could
not help, because a deeper prism shows the same single face.

The cell is now a cube of side `TILE_SIDE` standing **on** the platform rather
than hanging inside it, so its walls face the camera and fall in a lower ramp
band than its top.

* **Two faces per state.** Six faces, three states: the empty mark on the top
  and bottom faces, the sun on the near and far ones, the moon on the left and
  right. The duplication is load-bearing, not decoration. A cube has only four
  faces around any one axis and the state cycle is three long, so a single-axis
  roll cannot work; the axis has to alternate. With each state on an opposite
  pair, the next state is always exactly one quarter turn away, whichever
  alternating axis comes next.
* **The roll.** Quarter turn per tap, axis alternating with the step count:
  an even step turns about X (the cube rolls toward the player), an odd step
  about Z (it rolls to the left). Composed from the identity this gives
  `face up = steps % FACES` and `state up = steps % 3`, and six taps compose
  back to the identity exactly. `_orient(steps)` rebuilds the orientation from
  that table every time rather than multiplying onto the live basis, so no
  number of rolls accumulates drift, and negative steps (undo) wrap the same
  way.
* **Pivot on the edge, not a spin in place.** A cube turning about its centre
  would cut its lower corners through the platform, so `Motion.roll` lifts the
  centre to `half * sqrt(2) * cos(45 degrees - turned)`, which is exactly
  `half` at the start and end of every quarter turn and peaks 0.17 up at
  45 degrees. This replaces the trilon's fixed `ROLL_LIFT` hop. A multi-step
  roll (reset's two) plays as one tween of consecutive tumbles, so it sits
  flat on the intermediate face on the way past.
* **Colour belongs to the cube, not a face.** The named per-face materials are
  gone; the tile carries one `Stone` material and the game tints the whole
  cube by the state that is up, slate for a moon and stone otherwise. Per-face
  colours cannot be consistent on a cube that rotates: at steps 3 and 4 a moon
  face lands on the front wall while an empty or sun face is up, so identical
  cells would show different coloured walls. The colour changes when the roll
  lands, under cover of the dust puff.
* **Node split.** The roll moved off the cell pivot onto a new `spin` child.
  The pivot keeps the hop, the dip and the Check wobble (which drives
  `rotation.z`); a wobble on the same node would clobber the orientation the
  roll left behind.
* **Emblem visibility.** At rest only the emblem on the face that is up shows.
  With the cube standing proud of the platform its walls are in view, so a
  visible side emblem would read as a second answer; while a roll is in flight
  only the faces it passes over the top show, never the pair on the roll axis.
* **The model.** `tile.glb` is now hand-modelled in the tracked
  `art/tile.blend` (contract, "Building the pieces"), and
  `tools/build_pieces.py` no longer writes a `Tile`.
* **Cost.** One surface per cube instead of four and one visible emblem
  instead of three: idle at 1080x1920 went from 4.95 ms to 3.96 ms, 512 draw
  calls at the peak of a roll.

Still open: the wall-to-top contrast is gentle. A flat wall normal measures
`(228, 197, 169)` against a `(251, 224, 184)` top, about 10 percent, because
the ramp's shadow band is a hue shift toward `SHADOW_TINT` rather than a
darkening. Sharpening it means either a darker `shadow_tint` for the tile's
material alone or a change to the shared ramp, which would move the look of
every piece in the game; it is the user's call, not a fix to slip in here.

## Amendment D: the symbols are modelled into the cube (2026-09-14)

The sun and the moon are no longer separate models the board places on a
cube's faces at build time. They are inlaid in `art/tile.blend` itself, the way
a die carries its pips, and `tile.glb` exports as an assembly of three layers:
`Tile_Body` (`Stone`), `Sun` and `Moon`. This is the user's call, taken in
full knowledge of what Amendment C decided about emblem visibility.

* **All six faces, always.** Amendment C's emblem-visibility rule is
  withdrawn. Every face carries its symbol at all times, so a cell showing
  empty on top also shows a sun on its near and far walls. That is the point:
  a die reads as a die, and the quarter turn shows the next symbol swinging up
  into view. `_show_faces`, the `_faces` array and the `EMBLEM` slot table are
  gone from `puzzles/binairo3d.gd`; nothing is placed or hidden at run time.
* **No empty mark.** The old diamond is dropped. The empty state is a bare
  stone face on the cube's top and bottom pair, which is why the assembly is
  exactly `TILE_SIDE` tall and no code needed to re-seat the cube.
* **Inlaid, not proud.** Each symbol is a closed solid 0.05 thick sunk into
  the wall so 0.015 stands out. Cells are a unit apart and the cube is 0.84
  wide, so two facing inlays spend 0.03 of the 0.16 gap. The assembly's
  footprint grows to 0.87 x 0.87, still inside the slot's 1.0 budget.
* **Orientation is the model's job, not the code's.** Face `f` is up after `f`
  quarter turns, so its symbol is baked wearing `_orient(f)` inverted; rolling
  the cube to `_orient(f)` brings that symbol out flat on top. Two lobes of one
  layer share one mesh, which the contract allows.
* **Tinting by name.** `_paint` now calls `Models.tint_named(tile, "Stone", …)`
  rather than `Models.tint`. Painting every surface turned a moon cell's own
  crescent slate and showed nothing; the state colour, the blush and the Check
  flash all belong to the body alone.
* **Cost.** Six draw calls per cell instead of four, since both symbols and
  their outline shells are always drawn. Measured on the same 6 x 6 board at
  1080x1920: 512 draw calls and 3.76 ms idle before, 646 and 4.36 ms after,
  against the section 7 budget of 8 ms. The lever if an 8 x 8 board bites is
  renaming the materials `Sun_flat`/`Moon_flat` to drop the outline shells.
* **Slots removed.** `emblem_sun`, `emblem_moon` and `empty_mark` had one
  consumer and are gone from `Models.SLOTS`, the exporter table,
  `tools/build_pieces.py`, `tools/build_models.sh`, the contract and
  `assets/models/README.md`. `Placeholders.make("tile")` builds the same
  three-layer assembly with plain discs so the no-`.glb` fallback still reads.

Still open: at the board's 68-degree pitch the cube in front hides most of a
near wall, so the sun inlaid there shows only the top arc of its rays, reading
as a row of orange beads along the bottom of each visible wall strip rather
than as a sun. It is correct and it is what "all faces on" means at this
camera; whether it is wanted is a look question, not a bug.

## Amendment E: slate on the face, and no focus ring (2026-09-14)

Two calls from the user, looking at the die from Amendment D on the real
board.

**The moon faces are already black.** Amendment C had the game tint the whole
cube by the state that is up, so a cell turned slate when its roll landed.
`art/tile.blend` now carries a fourth layer, `Moon_Face` (`Slate_flat`): a slab
on each of the two moon walls, covering the flat part of the face inside the
body's 0.024 bevel and standing 0.0015 proud. A cube is therefore already black
on the side it is about to bring up, and **no colour changes when a roll
lands**. What `_paint` still says is only whether the cell is locked --
`Stone`/`STONE_GIVEN` on the body, `SLATE`/`SLATE_GIVEN` on the slabs -- plus
the blush and the Check flash, which take both layers together.

Amendment C's reason for tinting the whole cube stands and is now moot: colours
could not be consistent on a rotating cube *because they were applied per
state*. Fixed to the model, they rotate with it, which is the same trick that
made the symbols work. The cost is that a cell's walls no longer say what it
holds -- the slate shows on a wall of an empty cell, the same way its sun does.
That is what a die looks like.

The slab is `_flat`, so it carries no outline shell: the body already draws the
cell's silhouette and a second shell inside it would read as a seam.

**The focus ring is gone.** The translucent blue frame that popped onto the
last tapped cell, slid between cells and pulsed is removed outright, along with
the `focus_ring` slot, its placeholder, `Placeholders.focus_material`,
`_ring_mesh` and `Pal.FOCUS`. Sections 2 and 6 of this spec are withdrawn to
that extent. What survives is `focus_cell` and the `focus_changed` signal,
which the HUD's working-line card reads; `_focus` now only records the cell,
cues the tap sound and emits. Given cells still take the focus.

**Cost.** 646 draw calls and 4.36 ms idle at 1080x1920 before this amendment,
717 and 4.89 ms after, against the section 7 budget of 8 ms. The slab adds two
per cell, its own pass and its shadow; the ring gave back one.
