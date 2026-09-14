# Pipes on the island: the 3D board and its water — design

Concept reference: `docs/art/concept-pipes.png`. Parent specs:
`2026-09-13-3d-toon-pipeline-design.md` (stage, toon, model library,
`PuzzleBase3D`), `2026-09-13-binairo-polish-design.md` (motion, effects,
ambience), `2026-09-14-binairo-hud-design.md` (HUD panels, puzzle
capabilities) and `2026-09-14-codebreak-3d-design.md` (the second 3D board,
whose shape this one follows). `puzzles/binairo3d.gd` and
`puzzles/codebreak3d.gd` are the reference implementations.

## Goal

Pipes (id `pipes`) is today a flat 2D `Control` drawing lines with
`draw_line`. It becomes the third puzzle on the island stage: a grid of cream
stone pads carrying chrome pipe pieces, a blue source valve at the far-left
corner and a drain valve at the near-right one, and water that visibly runs
through the pipes — seen through a sight gap in every length of pipe — as the
network is connected. Tap a piece to turn it; the HUD gains undo and three
hints.

## Decisions taken with the user (2026-09-14)

- **The rule does not change.** `pipes_gen.gd` is untouched: a random spanning
  tree, solved when no opening anywhere faces a wall or a closed side. Because
  a spanning tree reaches every cell, solving it necessarily feeds the whole
  board, so the concept's "make the water flow" is the same rule in different
  words. Cell (0, 0) — the flood origin the generator already assumes — is
  dressed as the source; cell (w-1, h-1) is dressed as the drain.
- **Board and HUD only.** The mascots, the wooden signs, the carved logo and
  the cliff scenery in the concept are deferred to the scenery sub-project, as
  Code Break deferred them.
- **Five whole pieces, not modular arms.** Each of the five shapes (cap,
  straight, elbow, tee, cross) is its own slot with its shell joined into one
  mesh, so every cell gets one clean outline hull. A modular arm-and-hub
  build would have put an outline seam ring at every joint and cost about 600
  draw calls at 6 x 9 against roughly 430 this way.
- **Pipes get their own pad slot** rather than reusing Code Break's `socket`,
  so the two boards' art stays independent.
- **The water is visible inside the pipes, and there are plenty of
  animations** (the user's words). Section 4 is the answer.

## Non-goals

- Mascots, signs, the carved logo, the cottage, cliffs, flowers.
- Sound. Effects name their cue through `fx.cue`; nothing plays yet.
- New unit tests. Existing tests that name the model slots or drive Pipes are
  updated; no new test files (MVP rule).
- The menu, the solved card's redesign, the share sheet.
- Any change to Binairo or Code Break, beyond the shared helpers in
  `core/models.gd` and `core/palette.gd` that this spec adds.
- Changing `pipes_gen.gd`.

## 1. The board and its pieces

**Layout.** `cols = w`, `rows = h`, laid on the shared platform by
`Platform.build(w, h)` with its moss rim. Difficulty sizes are unchanged: 4 x 5,
5 x 7, 6 x 9. Row 0 is the far edge, so the flood origin (0, 0) lands
top-left and the drain (w-1, h-1) bottom-right, exactly as the concept shows.
Cell centres come from `BoardMath.cell_center(r, c, cols, rows, y)` with
`r = y`, `c = x` — the puzzle keeps the generator's `(x, y)` indexing in its
state and converts at the boundary.

**Seven new model slots**, modelled by hand in the live Blender session into
`art/pipes.blend` (tracked in git) as seven collections and exported through
the contract in one run; each has a primitive placeholder carrying the same
layer and material names, so the game runs before the art lands and the
headless tests see the same contract.

Every arm runs from the cell centre out to the cell edge (0.5), so two
neighbours' mouths meet flush across the 0.06 gap between pads and a
connected run reads as one continuous pipe.

| slot | footprint | height | layers (object → material) |
|---|---|---|---|
| `pipe_pad` | 0.94 x 0.94 | 0.12 | `Pad_Body` → `Stone` (tinted) |
| `pipe_cap` | 1.0 x 1.0 | 0.35 | the three pipe layers below, one arm |
| `pipe_straight` | 1.0 x 1.0 | 0.35 | two opposite arms |
| `pipe_elbow` | 1.0 x 1.0 | 0.35 | two adjacent arms |
| `pipe_tee` | 1.0 x 1.0 | 0.35 | three arms |
| `pipe_cross` | 1.0 x 1.0 | 0.35 | four arms |
| `valve` | 0.6 x 0.6 | 0.10 | `Valve_Ring` → `Metal` (tinted), a torus of inner radius 0.20 and outer 0.30, so it stands 0.10 with its lowest point on the pad top; `Valve_Bolts` → `Bolt_flat`, four discs of radius 0.035 inlaid 0.0015 proud on the pad diagonals at radius 0.36, clear of the ring |

The three layers every pipe piece carries:

| object | material | outline | what it is |
|---|---|---|---|
| `Pipe_Shell` | `Steel` (tinted) | yes | the closed hub ball (radius `TUBE_R`) plus, per arm, two tube segments of radius `TUBE_R`: an inner one from 0.0 to 0.20 and an outer one from 0.32 to 0.50. All lobes joined into one mesh, so the outline is a single hull |
| `Pipe_Collar` | `Collar` (tinted) | yes | raised rings of radius `COLLAR_R` and width `COLLAR_W`, one at 0.20 and one at 0.32 framing the gap, one at 0.47 at the mouth. Joined into one mesh |
| `Pipe_Water` | `Flow_flat` | no | the inner tube, radius `CORE_R`, running the full 0.0 to 0.50 of every arm, plus a hub sphere. Its own `pipe_flow` material per cell (section 4) |

**The sight gap is a real hole, not glass.** The 0.12 stretch between the two
collars on each arm has no shell over it, so the `Pipe_Water` tube is directly
visible there and at every open mouth. This is what shows the water moving
without any transparent surface: alpha-blended geometry on
`gl_compatibility` sorts per object, and 54 transparent sleeves would have
been both a sorting hazard and a second toon shader to maintain. A recessed
band between two collars is also what the concept's chrome pipes already
show, so the opaque build is the faithful one as well as the cheap one.

**Placement.** Per cell a `pivot` at the cell centre with y = 0 — this is the
node that dips under a tap — carrying the pad at y = 0 and a `spin` node at
y = `PAD_H`, which is the node that turns and holds the piece. Splitting the
two means only the pipe rotates: the pad and the valve stay put however they
are later modelled, instead of relying on both staying four-fold symmetric.
The source and drain cells add a `valve` at y = `PAD_H`, whose
ring (inner radius 0.20) clears the hub (radius 0.15), so nothing collides and
the cell reads as the concept's bolted blue fixture. Piece choice comes from
the popcount of the cell's mask and, for two arms, whether they are opposite
(`pipe_straight`) or adjacent (`pipe_elbow`). A piece is modelled in its
`rot = 0` orientation with its first arm pointing at -Z (the `UP` bit), and
the pivot's `rotation.y` is `-rot * PI / 2`: about +Y, (0, 0, -1) maps to
(1, 0, 0) at -PI/2, so a tap turns the piece clockwise on screen, which is the
direction `Gen.rotate_mask` already means by one step.

**Tints carry the state.**

| surface | dry | fed |
|---|---|---|
| `Steel` | `STEEL` | `PIPE_WET` |
| `Collar` | `STEEL_HI` | `PIPE_WET_HI` |
| `Flow_flat` | `FLOW_DRY`, flow stilled | `WATER` with `WATER_HI` bands and `MOON` bubbles, flowing |

Pads are `STONE`; a hint-locked pad is `STONE_GIVEN` (Binairo's "given"
colour, reused); the source and drain pads are `WATER`, their rings `STEEL_HI`.
The water blue wins over the given colour, so a hint spent on the source or
the drain leaves that pad blue — the valve already says the cell is fixed.
Shell and collar tints change through `Motion.fade` on an 8-step grid, so the
toon material cache holds at most nine colours per material name per
direction. The water tube's wetness is one `wet` uniform on that cell's own
material, so it costs the cache nothing.

**Camera.** `board_size()` is `(w, h)`, `board_height()` 0.5 (a piece stands 0.35
over a 0.12 pad, so the collar top is 0.47 and nothing is higher at rest), `plane_height()` `PAD_H` (taps land on
the pad tops), `board_margin()` `Platform.LIP`, `board_depth()`
`Placeholders.PLATFORM_H`. At 1080 x 1920 the hard 6 x 9 board gives cells of
roughly 120 px; the whole pad is the tap target.

New constants in `core/placeholders.gd`:

```gdscript
const PAD_SIDE := 0.94
const PAD_H := 0.12
const TUBE_R := 0.15          # outer radius of the pipe
const ARM_LEN := 0.5          # centre to cell edge
## The tube's axis, in the piece's own space. It sits at the collar radius,
## not the tube radius, so the flange rings rest exactly on y = 0 and the pipe
## is carried 0.025 clear of the pad on them. At TUBE_R every collar would
## sink 0.025 into the pad and break the contract's base-at-y=0 rule.
const TUBE_Y := 0.175
const HUB_R := TUBE_R   # a clean rounded corner, no lower than the tube
const GAP_IN := 0.20          # sight gap starts here along the arm
const GAP_OUT := 0.32         # and ends here
const COLLAR_R := 0.175
const COLLAR_W := 0.06
const MOUTH_AT := 0.47        # the mouth collar's centre along the arm
const CORE_R := 0.115         # the water tube
const VALVE_IN := 0.20
const VALVE_OUT := 0.30
const VALVE_H := VALVE_OUT - VALVE_IN   # a torus is that tall
const BOLT_R := 0.035
const BOLT_AT := 0.36         # bolt centres, on the pad diagonals, outside the ring
```

Board constants in the puzzle: `SOURCE := Vector2i(0, 0)`, `HINTS := 3`,
`TURN_TIME := 0.22`, `FLOW_STEP := 0.045` (the per-cell delay of the flood
wave), `WIN_FLOW := 2.4` (the flow speed multiplier while the win plays).

## 2. How it plays

`puzzles/pipes3d.gd` replaces `puzzles/pipes.gd`. `puzzle_id()` stays
`"pipes"`, so daily seeds and progress keys do not change; `title()` stays
`"Pipes"`. State:

- `w`, `h`, `_mask`, `_rot` — as today, straight from `Gen.generate`.
- `_rot0: Array` — a copy of the scrambled rotations taken at build, so Reset
  restores the puzzle the player was given. (Today's `reset_board()` only
  zeroes the move count and leaves the board turned; that is a bug this spec
  fixes.)
- `_live: Dictionary` — `Vector2i` → BFS depth from the source. The flood
  becomes a breadth-first walk instead of the current depth-first one purely
  so the depth is available; the set of live cells is identical. Depth drives
  the flow wave's stagger.
- `_locked: Array` — per cell, true once a hint has fixed it.
- `_history: Array[Vector2i]` — cells the player has turned, most recent last.
- Node and material handles per cell: `_pivots`, `_pieces`, `_pads`,
  `_flow_mats`, and the tween arrays `_turn_tw`, `_dip_tw`, `_fade_tw`,
  `_flow_tw`.

- **Tap a cell** (`on_board_press`): `BoardMath.world_to_cell` gives the cell.
  Outside the board, or the puzzle done: nothing. Locked: the pivot dips 0.02,
  cue `focus`. Otherwise `_settle(x, y)` finishes any motion on that cell,
  `_rot[y][x] = (_rot[y][x] + 1) % 4`, the pivot turns (section 4), the cell is
  pushed onto `_history`, the flood is recomputed and the wave runs,
  `note_move()`.
- **Solved** is `Gen.is_solved(_mask, _rot, w, h)`, unchanged, checked by the
  base class after each move.
- **Undo** (`undo()`): false when done or `_history` is empty. Pops the last
  cell, sets `_rot` back by one step (`+ 3) % 4`), turns the piece the other
  way, recomputes the flood, `moved.emit()`, no move counted, cue `undo`.
- **Hint** (`hint()`, `HINTS := 3`): false when done or none left. Takes the
  first cell in reading order whose rotated mask differs from its modelled
  mask (`Gen.rotate_mask(_mask[y][x], _rot[y][x]) != _mask[y][x]`), which
  skips cells that are already right — including the rotationally symmetric
  ones a naive `rot != 0` test would waste a hint on. Such a cell always
  exists while the board is unsolved, since rot 0 everywhere is a solution.
  Sets its rotation to 0, turns the piece there, locks it, fades its pad to
  `STONE_GIVEN`, drops every `_history` entry for that cell, sparkles,
  `hints_used += 1`, `moved.emit()`, cue `hint`. Hints count no move and are
  not refunded by Reset.
- **Reset** (`reset_board()`): `_rot` is restored from `_rot0`, every piece
  turns back with a stagger, `_locked` clears, hinted pads fade back to
  `STONE`, `_history` clears, `moves = 0`, the flood is recomputed and the
  water drains. `hints_used` stays. Cue `reset`.
- `share_glyphs()` is unchanged: `"🔧 %dx%d · %d turns"`.
- `rules()`: "Tap a piece to turn it. The water starts at the blue valve —
  fill every pipe and leave no loose ends."

`capabilities()` returns `["undo", "hint"]`. `can_undo()` is
`not is_done() and not _history.is_empty()`. `hints_left()` is
`HINTS - hints_used`. There is no Check button: the board is solved the
instant the last piece lines up, and the base class notices.

**Registry**: the `pipes` entry's `script` becomes
`res://puzzles/pipes3d.gd`, with `"motto": "Make the water flow"` and
`"footer": "Think · Connect · Flow"` — the two mottos carved on the concept's
signs.

## 3. The HUD

Nothing new is built. Pipes declares `undo` and `hint`, and the existing
`ui/hud/top_bar.gd` shows the undo and hint buttons with the hint count, which
is exactly the top-right pair in the concept. The action bar shows its line
card and Reset; its Check button and colour tray both stay hidden, since
`capabilities()` names neither. The rules card takes the new `rules()` text
and the day card is untouched.

## 4. Water, motion and effects

### The flow shader

`shaders/pipe_flow.gdshader`, opaque, toon-lit the same two-band way as
`water.gdshader`, applied to the `Flow_flat` surfaces of every pipe piece. One
material instance per cell, built by `Models._dress` and handed to the puzzle,
so each cell's water has its own wetness and speed.

```
global uniform float motion_scale;        // reduce-motion stills the flow
uniform vec4 dry_color   : source_color;  // FLOW_DRY
uniform vec4 base_color  : source_color;  // WATER
uniform vec4 band_color  : source_color;  // WATER_HI
uniform vec4 bubble_color: source_color;  // MOON
uniform vec4 shadow_tint : source_color;
uniform float wet = 0.0;                  // 0 dry, 1 running
uniform float flow_speed = 1.0;           // the win bumps this to WIN_FLOW
```

The fragment shader runs a phase `p = UV.y * 6.0 - TIME * flow_speed *
motion_scale`, steps `sin(p)` into hard bands, scatters bubble dots by
warping a second sine pair the way `water.gdshader` scatters its sparkles, and
mixes the result from `dry_color` toward that water colour by `wet`. Bands and
bubbles fade in with `wet`, so a dry tube is a flat grey hole and a fed one is
water with visible current and bubbles travelling along it. Nothing reads
depth or screen, so it runs on `gl_compatibility`.

This is where "water particles inside the pipes" lives. Real
`CPUParticles3D` inside an opaque pipe would be invisible except through the
sight gaps and would cost an emitter per cell; drawing the bubbles in the
tube's own shader costs nothing per cell and is visible in every gap and at
every open mouth. Real particles are used where water is genuinely exposed —
the source, the leaks and the drain, below.

### The source jet and the leaks

`world/fx.gd` gains a second kind of emitter: a **continuous** pool, alongside
the existing one-shot puffs and sparkles.

```gdscript
const JET_POOL := 5
## A steady fall of water droplets from `at`, until stop_jet(handle) is called.
## Returns a pool index, or -1 when the pool is exhausted or reduce-motion is on.
func jet(at: Vector3, colour: Color = Pal.WATER_HI) -> int
func stop_jet(handle: int) -> void
```

The emitters are `CPUParticles3D` with `one_shot = false`, amount 10, lifetime
0.5, gravity (0, -4, 0), a narrow spread and the speck mesh, tinted `WATER_HI`.
Five is enough for the source plus up to four leaks.

- **The source jet** runs for the whole puzzle at the source valve's ring: the
  water arriving that the player is asked to route.
- **A leak** is a live cell with an opening that faces a wall or an unmatched
  neighbour. Each gets a jet at that mouth, which is the feedback that makes
  the mechanic work — a fed pipe pouring water onto the stone is visibly wrong
  and shows exactly where. Leaks are recomputed with the flood; the four
  nearest the source (lowest depth, then reading order) get jets, the rest
  none, so the pool never overflows. On solve every leak is gone by
  definition.
- **The drain** takes a jet of its own the moment its cell first goes live,
  pouring down into the ring, plus one sparkle and cue `drain`.

### The motion table

All decorative unless marked; every recipe already honours reduce-motion,
under which the tints and the `wet` uniform still change so the board stays
readable with nothing moving.

| moment | motion | cue |
|---|---|---|
| entrance | the platform rises from -0.5 in 0.5 s and rings the water (as Binairo); pads pop from scale 0.01 with `stagger(r + c, 0.02)`; pieces drop from +0.6 with `settle` after 0.25 s, same stagger; the two valves pop last; then the flood wave runs and the source jet starts | `enter` |
| turn | the pivot's `rotation.y` settles to `-rot * PI / 2` in `TURN_TIME`, **essential** (it is the state change); the piece squashes 0.08 over 0.18 s; a puff at the hub; the collars glint (a 0.12 s scale pulse to 1.06 and back) | `turn` |
| flood in | every newly-live cell fades `Steel` → `PIPE_WET` and `Collar` → `PIPE_WET_HI` over 0.25 s and its `wet` uniform 0 → 1, each with `stagger(depth, FLOW_STEP)` by BFS depth from the source, so the water visibly races outward from the valve; a bubble sparkle at the first four newly-wet hubs | `flow` |
| flood out | newly-dry cells fade the other way with `stagger(depth_before, 0.02)`, a shorter wave; their jets stop | `drain_out` |
| leak starts | a jet at that mouth and one puff where it lands | `leak` |
| drain fed | a jet into the drain ring, a sparkle, the ring pulses its scale once | `drain` |
| tap on a locked cell | the pivot dips 0.02 over 0.35 s | `focus` |
| undo | the turn runs backwards, same recipe | `undo` |
| hint | the chosen piece turns to its solved angle, a sparkle over it, its pad fades to `STONE_GIVEN` over 0.3 s | `hint` |
| win | every piece hops 0.08 in 0.4 s in a wave from the source, `stagger(depth, 0.05)`; every cell's `flow_speed` goes to `WIN_FLOW` for 1.2 s and eases back; the drain jets hard; the water rings under the board | `solved` |
| reset | pieces turn back to `_rot0` with `stagger(r + c, 0.02)`; the water drains from the far cells inward; hinted pads fade back to `STONE` | `reset` |
| idle | the flow bands and bubbles scroll in every fed pipe, and the source jet falls. The only always-on motion; both stop under reduce-motion, since both are scaled by the `motion_scale` global | — |

`_settle(x, y)` ends every tween on a cell (pivot rotation and y, piece
scale, the fades and the flow tween) at its target, as Binairo's does; a tap
mid-motion settles first. `_stop_all()` kills every tracked tween and stops
every jet before a rebuild or a reset. Particles come from the pooled `Fx`
node the board owns.

## 5. The model library and the art pipeline

`core/models.gd`:

- `SLOTS` grows to `["tile", "rim_edge", "rim_corner", "platform", "water",
  "socket", "peg", "pip", "lid", "pipe_pad", "pipe_cap", "pipe_straight",
  "pipe_elbow", "pipe_tee", "pipe_cross", "valve"]`.
- Two new helpers, and `tint_named` is rewritten to call the first of them so
  there is one place that walks surfaces by material name:

```gdscript
## Overrides every surface under `root` whose imported material is `name`.
static func set_material_named(root: Node, name: String, mat: Material) -> void
## The override applied to the first surface named `name`, or null.
static func material_named(root: Node, name: String) -> Material
```

- `_dress` gains a branch for the five pipe slots that gives each instance its
  own `pipe_flow` material on `Flow_flat` (`Toon.pipe_flow()` returns a fresh
  one per call, unlike the shared `Toon.water()`), so the puzzle can drive
  `wet` and `flow_speed` per cell. It reads the material back with
  `material_named(piece, "Flow_flat")`.

`core/toon.gd` gains `PIPE_SHADER` and

```gdscript
## A fresh pipe-flow material, one per pipe instance: each cell drives its own
## `wet` and `flow_speed`, so unlike water() this is deliberately not shared.
static func pipe_flow() -> ShaderMaterial
```

`core/placeholders.gd` builds the seven slots from primitives with the layer
names above, through the existing `_layer` helper (which names the material
and lets `Toon.apply_to` add the outline shells). Because a layer is several lobes (a hub and up to eight tube
segments), each layer is merged into one `ArrayMesh` with `SurfaceTool
.append_from(mesh, 0, xform)` per lobe followed by `generate_normals()` and
`commit()` — one mesh per layer, as the contract requires. A new helper:

```gdscript
## One mesh from several primitives, each placed by its own transform.
static func _merge(parts: Array) -> ArrayMesh
```

`core/palette.gd` gains:

```gdscript
# Pipes (docs/art/concept-pipes.png). Chrome when dry, lit blue when fed;
# the water tube is WATER / WATER_HI, already defined above.
const STEEL       := Color("aebecb")   # dry pipe shell
const STEEL_HI    := Color("cfdce6")   # dry collar, and the valve rings
const PIPE_WET    := Color("4fa8ef")   # fed pipe shell
const PIPE_WET_HI := Color("9ad3ff")   # fed collar
const FLOW_DRY    := Color("6b7a88")   # the water tube with nothing in it
```

`art/pipes.blend`: collections `Pipe_Pad`, `Pipe_Cap`, `Pipe_Straight`,
`Pipe_Elbow`, `Pipe_Tee`, `Pipe_Cross`, `Valve`, modelled in the live Blender
session through the MCP as a remote control, never by a generator script.
Bevel 0.02 with 2 segments, smooth shading. Base colours are the dry ones
above, converted to linear. Exporter budgets added to `LIMITS`:
`pipe_pad` (1.0, 1.0, 0.15), the five pipe shapes (1.0, 1.0, 0.38), `valve`
(0.65, 0.65, 0.12).

Export and import:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/pipes.blend \
  --python tools/blender_export.py -- Pipe_Pad Pipe_Cap Pipe_Straight \
  Pipe_Elbow Pipe_Tee Pipe_Cross Valve
godot --headless --path . --import
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- pipe_tee
```

`tools/build_models.sh` gains that export line; `.gitignore` un-ignores
`art/pipes.blend`; `docs/art/blender-contract.md` and
`assets/models/README.md` gain the seven rows.

## 6. Code structure

`puzzles/pipes3d.gd` (`extends "res://core/puzzle_base_3d.gd"`), sections in
this order, mirroring Binairo and Code Break: constants; state;
`puzzle_id / title / rules / board_*`; `build`, `reset_board`, `is_solved`,
`share_glyphs`; capabilities (`capabilities`, `can_undo`, `undo`,
`hints_left`, `hint`); flood (`_recompute_live`, `_leaks`, `_open_mouths`);
scene (`_stop_all`, `_build_scene`, `_slot_for`, `_cell`); pieces (`_turn`,
`_paint`, `_set_wet`, `_run_jets`); motion helpers (`_dip`, `_settle`,
`_enter`, `_splash`, `_on_solved`); input (`on_board_press`,
`cell_to_local`). The scene is built in one function, as the other two boards
are. `puzzles/pipes.gd` and its `.uid` are deleted; `pipes_gen.gd` is
unchanged.

## 7. Verification

No new test files. Updated:

- `tests/test_models.gd`: the `SLOTS` expectation, `HEIGHT_BUDGET` rows
  (`pipe_pad` 0.15, the five shapes 0.38, `valve` 0.12) and the outlined-layer
  table (`pipe_pad: [Stone]`, each pipe shape `[Steel, Collar]`,
  `valve: [Metal]`).
- `tests/_win.gd`: `_solve_pipes` taps through `cell_to_local(r, c)` instead
  of the deleted `_origin` / `_cell` fields, keeping the same strategy (turn
  every cell to rot 0); it adds the camera-fit check every 3D board has (each
  cell centre must project inside the board slot) and a HUD check that one
  hint and one undo behave, reported through `_fit_ok` / `_hud_ok`.
- The suite (`godot --headless --path . --script res://tests/run_tests.gd`),
  the win harness (10/10), `_shot.gd` for `/tmp/shot_pipes.png` and a
  throwaway `_shot_anim.gd` for idle frame time and draw calls all run before
  the branch is called done. The screenshot is compared with the concept by
  eye on the real stage, per the project's Blender rules.

## 8. Performance

Budget as the HUD spec's ruling: idle frame time at or under 8 ms at
1080 x 1920 on the Mac, draw calls at most 855. Estimate on the hard 6 x 9
board: pads 54 x 2 = 108; pieces 54 x 5 (shell and collar with outlines, water
tube without) = 270; valves 2 x 2 = 4; platform 1 plus 34 rim pieces = 35;
water, pollen and the Fx pools about 12 — roughly 430, plus the HUD. The flow
shader runs on 54 small tubes and the jets are at most five emitters of ten
particles. Measured numbers are recorded here when the branch is merged.

## Files

New: `puzzles/pipes3d.gd`, `shaders/pipe_flow.gdshader`, `art/pipes.blend`,
`assets/models/{pipe_pad,pipe_cap,pipe_straight,pipe_elbow,pipe_tee,pipe_cross,valve}.glb`,
`docs/art/concept-pipes.png`, this spec, its plan.

Deleted: `puzzles/pipes.gd` (and its `.uid`).

Modified: `core/models.gd`, `core/placeholders.gd`, `core/palette.gd`,
`core/toon.gd`, `world/fx.gd`, `ui/registry.gd`, `tools/blender_export.py`,
`tools/build_models.sh`, `.gitignore`, `docs/art/blender-contract.md`,
`assets/models/README.md`, `tests/test_models.gd`, `tests/_win.gd`.
