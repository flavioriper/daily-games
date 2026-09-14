# Code Break on the island: the 3D board and the colour tray — design

Concept reference: `docs/art/concept-codebreak.png`. Parent specs:
`2026-09-13-3d-toon-pipeline-design.md` (stage, toon, model library, `PuzzleBase3D`),
`2026-09-13-binairo-polish-design.md` (motion, effects, ambience) and
`2026-09-14-binairo-hud-design.md` (HUD panels, puzzle capabilities). Binairo's
board, `puzzles/binairo3d.gd`, is the reference implementation this one follows.

## Goal

Code Break (id `mastermind`) is today a flat 2D `Control`: tap a slot to cycle
its colour-and-shape token, then press its own Check button. It becomes the
second puzzle on the island stage: a stone board of socket slabs on the shared
platform, glossy colour pegs with an embossed mark, a feedback slab of pips per
row, a shielded code row under stone lids, and a wooden colour tray in the HUD.
Everything reuses the Binairo stack: motion recipes, particles, model tinting
by material name, the platform and rim, the HUD panels and the capability hooks.

## Decisions taken with the user (2026-09-14)

- **Pegs are placed from the tray.** A tray colour drops into the first empty
  slot of the active row; tapping a placed peg pops it out. No per-slot cycling.
- **Eight guess rows at every difficulty.** Difficulty comes from colours and
  repeats: 4 pegs from 6 colours without repeats, then with repeats, then 5
  pegs from 7 colours.
- **Pegs carry a second channel.** One peg model with a tinted dome and an
  embossed pip mark per colour index (one to seven pips), so colour is never
  the only cue. The tray buttons draw the same marks.
- **Approach A:** per-cell pieces on the shared platform, the tray as a HUD
  row. The shielded code row with lids and the two-row action bar are in.
- The user then approved sections 1 and 2 as presented and asked for the rest
  to proceed without further review ("just do it"). Sections 3 to 8 below are
  the author's decisions in that spirit; anything the user dislikes is a
  one-line amendment.

## Non-goals

- POM or the fox on the board, the wooden sign, the house, cliffs, flowers:
  props and scenery belong to polish sub-project 3.
- Sound. Effects name their cue through `fx.cue`; nothing plays yet.
- New unit tests. Existing tests that name the model slots or drive Code Break
  are updated; no new test files (MVP rule).
- The menu, the solved card's redesign, the share sheet.
- Any change to Binairo.

## 1. The board and its pieces

**Layout.** `cols = length + 1`, `rows = max_guesses + 1 = 9`, laid on the
shared platform by `Platform.build(cols, rows)` with its moss rim. Row 0 at the
far edge is the **code row**; rows 1 to 8 are the guesses, first guess nearest
the code row, so the active row walks toward the player and the tray. Column
`length` (rightmost) is the **feedback column**; on the code row it stays bare.
Cell centres come from `BoardMath.cell_center(r, c, cols, rows, y)`.

**Four new model slots**, modelled by hand in the live Blender session into
`art/codebreak.blend` (tracked in git) as four collections and exported through
the contract in one run; each has a primitive placeholder carrying the same
layer and material names, so the game runs before the art lands and the
headless tests see the same contract.

| slot | footprint | height | layers (object → material) |
|---|---|---|---|
| `socket` | 0.94 x 0.94 | 0.12 | `Socket_Body` → `Stone` (tinted); `Socket_Well` → `Well_flat`, a disc of radius 0.3 laid 0.0015 proud on the top, the tile's slate-slab trick. The feedback slab is a socket with its well hidden |
| `peg` | 0.6 across | 0.44 | `Peg_Body` → `Shell` (tinted per colour), a dome; `Peg_Mark_1` … `Peg_Mark_7` → `Mark_flat`, one to seven pips laid out like die faces on the crown (7 is a ring of six plus one), each 0.07 across, 0.0015 proud. The game shows the one mark matching the colour index and tints it a darker shade of the peg's colour |
| `pip` | 0.2 across | 0.16 | `Pip_Well` → `Well_flat`, a disc of radius 0.1; `Pip_Ball` → `Pip` (tinted), a sphere of radius 0.08 resting in it, hidden until the row is scored |
| `lid` | 0.94 x 0.94 | 0.24 | `Lid_Body` → `Lid`, a 0.16 slab; `Lid_Knob` → `Knob`, a small wooden knob on top |

Outlined layers: `Socket_Body`, `Peg_Body`, `Pip_Ball`, `Lid_Body`, `Lid_Knob`.
Everything named `_flat` has none. Bevel 0.02 with 2 segments, smooth shading,
as the contract requires. Exporter budgets (added to `LIMITS`): `socket`
(1.0, 1.0, 0.15), `peg` (0.7, 0.7, 0.5), `pip` (0.3, 0.3, 0.2), `lid`
(1.0, 1.0, 0.3).

**Placement.** Per guess cell `(g, s)`: a `pivot` at the cell centre, y = 0
(dips and the Check wobble), under it a `breath` node (the active row's rise),
under that the socket model and, when placed, the peg at y = `SOCKET_H`. Per
guess row a feedback slab at its cell centre with `length` pips on it at
y = `SOCKET_H`, two across and `ceil(length / 2)` deep, 0.26 apart, centred,
hits first in reading order. On the code row, per slot: a hidden code peg at
y = 0 and a lid at y = 0 covering it.

**Tints carry the state.** The active row's sockets are `STONE`; every other
socket and every feedback slab is `STONE_GIVEN`. A row change fades between
the two in 0.3 s on an 8-step grid (`Motion.fade`, so the toon cache holds at
most nine colours per direction). Pegs never change colour once placed: `Shell`
takes `Pal.PEGS[i]`, `Mark_flat` takes the same colour darkened by 0.35. Pip
balls take `SLATE` for a right colour in the right place and `MOON` for a
right colour in the wrong place. Lids and knobs keep their modelled colours
(`STONE_GIVEN`, `WOOD`).

**The active row breathes.** Each socket's `breath` node pulses `position:y`
between 0 and 0.02 over 2.4 s (`Motion.pulse`); the tint alone reads under
reduce-motion, where `pulse` returns null.

**Camera.** `board_size()` is `(cols, rows)`, `board_height()` 0.6 (socket plus
peg, nothing sits higher at rest), `plane_height()` `SOCKET_H` (taps land on
the socket tops), margin `Platform.LIP`, depth `Placeholders.PLATFORM_H`. At
1080 x 1920 with the two-row action bar a cell lands around 110 to 130 px and a
peg around 70 px; the whole socket is the tap target.

Constants in `core/placeholders.gd`: `SOCKET_SIDE 0.94`, `SOCKET_H 0.12`,
`WELL_R 0.3`, `WELL_PROUD 0.0015`, `PEG_R 0.3`, `PEG_H 0.44`, `MARK_R 0.035`,
`MARK_SPREAD 0.11`, `PIP_WELL_R 0.1`, `PIP_R 0.08`, `LID_H 0.16`, `KNOB_R 0.09`,
`KNOB_H 0.08`. Board constants in the puzzle: `PIP_GAP 0.26`, `CODE_ROW 0`.

## 2. How it plays

| difficulty | pegs | colours | repeats | guesses |
|---|---|---|---|---|
| 0 | 4 | 6 | no | 8 |
| 1 | 4 | 6 | yes | 8 |
| 2 | 5 | 7 | yes | 8 |

State: `_code`, `_guesses`, `_marks` (as today, from `mastermind_gen.gd`, which
is unchanged), `_row: Array[int]` (the active row, -1 empty), `_locked:
Array[bool]` per slot (hinted), `_revealed`, `_history: Array[Dictionary]` of
`{"op": "place" | "pop", "slot": s, "colour": i}`. The active guess index is
`_guesses.size()`; its board row is that plus one.

- **Pick** (`pick(i)`): false when done or revealed or `i` is out of range.
  The first slot `s` with `_row[s] == -1` and not locked receives colour `i`;
  the history records the place; `moved.emit()`; true. With no free slot the
  row's pegs nudge (a 0.05 hop) and it returns false.
- **Pop** (a tap on a placed, unlocked peg in the active row): the peg
  vanishes, `_row[s] = -1`, the history records the pop, `moved.emit()`.
- **Other taps** dip the socket under them (a 0.02 dip on its pivot): an
  empty active socket, a locked peg, any other row, the feedback column. The
  code row does nothing.
- **Check submits** (`check()`): -1 when done or revealed. `checks += 1`. With
  a slot empty, every empty socket of the row wobbles, cue `check`, -1. Else
  the row is scored with `Gen.score`, appended to `_guesses` and `_marks`, its
  pips pop in, the row fades to the resting tint, the history is cleared and
  `note_move()` runs, so moves equal guesses. Then: if `exact == length` the
  base class ends the game (`solved`); else if `_guesses.size() ==
  max_guesses` the game is lost; else the next row activates: its sockets fade
  to `STONE`, its breath starts, and every locked slot receives its code peg
  (no history). Returns `length - exact`.
- **Win.** `_on_solved`: the lids slide off one by one, the winning row's pegs
  hop in a wave, cue `solved`. The host shows its solved card with the same
  share grid as today.
- **Loss.** `_revealed = true`, `_running = false` (the timer stops), the lids
  slide off and the code pegs pop in, cue `reveal`. `pick`, `check`, `undo`
  and `hint` all return false / -1 while revealed; Reset starts over on the
  same code.
- **Undo** (`undo()`): false when done, revealed or the history is empty. Pops
  the last entry: a `place` vanishes that peg and frees the slot; a `pop` puts
  the peg back. `moved.emit()`, no move counted, cue `undo`. Submitted guesses
  are never undone: their feedback is information already seen.
- **Hint** (`hint()`, `HINTS := 3`): false when done, revealed or none left.
  Takes the leftmost slot not yet locked (always exists: three hints, four or
  more slots). Locks it, slides its lid off (the code peg pops in under it),
  removes every history entry for that slot, vanishes any peg the active row
  holds there, places the code peg in the active row's slot with a sparkle,
  `hints_used += 1`, `moved.emit()`, cue `hint`. Hints count no move and are
  not refunded by Reset.
- **Reset** (`reset_board()`): every peg in a guess row vanishes in a wave from
  the far row to the near one, pip balls hide, missing lids drop back from
  above, code pegs hide, hinted slots unlock, the first row activates,
  `_row` clears, `_history` clears, `moves = 0`, `_revealed = false`,
  `_running = true`. `hints_used` stays. Cue `reset`.

`capabilities()` returns `["undo", "hint", "check", "palette"]`. `can_undo()`
is `not done and not revealed and history not empty`. `hints_left()` is
`HINTS - hints_used`. `puzzle_id()` stays `"mastermind"`, so daily seeds and
progress keys do not change; `title()` is `"Code Break"`. `share_glyphs()` is
unchanged. `rules()` is three sentences for the rules card: "Crack the hidden
row of four colours." (or five) "Fill a row from the tray and press Check." "A
slate pip is a right colour in the right place, a cream pip a right colour in
the wrong place."

## 3. The HUD: the palette capability and the tray

**Capability hooks** on `core/puzzle_base.gd`, defaults meaning unsupported:

```gdscript
## The tray's entries in order, [] when unsupported:
## {"colour": Color, "mark": int (1..7), "enabled": bool}.
func palette() -> Array[Dictionary]: return []
## The player chose tray entry `i`. True when a peg was placed.
func pick(_i: int) -> bool: return false
```

Code Break's `palette()` lists `Pal.PEGS[0 .. palette - 1]` with `mark = i + 1`
and `enabled = not (is_done() or _revealed)`.

**`ui/hud/peg_button.gd`** (`extends Button`, `flat`, 110 x 110): draws a disc
in the entry's colour at radius 0.42 of its side, a darker lower crescent in
the colour darkened by 0.25 (the toon shadow band), a 4 px `OUTLINE` ring, and
the pip mark in the colour darkened by 0.35 with the same die layouts as the
model (`MARK_SPREAD` scaled to the disc). Disabled draws at 45 percent alpha.
Sets `pivot_offset` to its centre on resize and runs `Motion.squash(self,
0.10, 0.18)` on `button_down`, like `IconButton`. `set_entry(colour, mark,
enabled)`.

**`ui/hud/palette_tray.gd`** (`extends PanelContainer`): the wooden tray,
`CozyTheme.wood_card()` (new: `card(WOOD, 28, WOOD_DEEP, 8, 16)`), holding an
`HBoxContainer` (separation 14, centred) of `PegButton`s; `buttons: Array`.
Signal `pick(i)`. `refresh(puzzle)`: rebuilds the buttons when
`palette().size()` changes, then updates every entry. Height about 150.

**`ui/hud/action_bar.gd`**: `_make_inner` becomes a `VBoxContainer`
(separation 20) holding the tray on top and the existing row (line card, Reset,
Check) below. New signal `pick(i)` forwarded from the tray. `refresh`: `tray
.visible = caps.has("palette")`, the rest as today. When the tray is hidden
the bar is exactly what it is now.

**Host** (`ui/puzzle_host.gd`): `action_bar.pick` → `_puzzle.pick(i)` then
`_refresh()`. `_on_check` shows `All good` only when `wrong == 0 and not
_puzzle.is_done()`, so a winning Check does not squash a button under the
solved card.

**Registry**: the `mastermind` entry's `script` becomes
`res://puzzles/codebreak3d.gd`, with `"motto": "Crack the hidden code"` and
`"footer": "Small puzzles · Brighter days"`.

**Palette additions** (`core/palette.gd`):

```gdscript
# Code Break pegs (docs/art/concept-codebreak.png): red, yellow, blue, green,
# purple, pink, orange. Index order is the difficulty's palette order.
const PEGS := [
	Color("e5484d"), Color("f7c948"), Color("3d8bfd"), Color("3fb950"),
	Color("9b6cf6"), Color("f472b6"), Color("fb8c3c"),
]
const WOOD_DEEP := Color("9c7350")   # the tray's bottom edge
```

## 4. Motion and effects

All decorative unless marked; every recipe already honours reduce-motion.
One new recipe in `core/motion.gd`:

```gdscript
## Lifts `node` by `lift` while scaling it to nothing, then hides it. Decorative:
## under reduce-motion the node is hidden at once and null returned.
static func vanish(node: Node3D, lift: float, time: float, delay := 0.0) -> Tween
```

| moment | motion | cue |
|---|---|---|
| entrance | platform rises from -0.5 in 0.5 s and rings the water (as Binairo); sockets and feedback slabs pop from scale 0.01 with `stagger(r + c, 0.02)` after the platform; lids drop from +0.6 with `settle` after a further 0.3 s, `stagger(s, 0.06)` | `enter` |
| place | the peg appears 0.5 above its socket and settles to `SOCKET_H` in 0.3 s; **essential** (it is the state change); a small puff at the socket on landing | `place` |
| pop / undo of a place | `vanish(peg, 0.25, 0.22)` | `pop` / `undo` |
| full row pick | every peg in the row hops 0.05 in 0.25 s | `full` |
| tap elsewhere | the socket's pivot dips 0.02 in 0.35 s | `focus` |
| incomplete Check | empty sockets wobble (`Motion.wobble(pivot, 0.1, 0.4)`) | `check` |
| score | the row's pivots dip 0.03 together, then each hit's ball pops from scale 0.01 in 0.25 s with `stagger(k, 0.06)`; a sparkle over the feedback slab when `exact > 0`; the row fades to `STONE_GIVEN` and the next row fades to `STONE` and starts breathing | `score` |
| lid off | slides 1.3 toward the far edge in 0.4 s (`slide`, sine), falls to `-WATER_DEPTH` in 0.5 s ease-in, hides, and rings the water at its last position (`stage.splash`); the code peg under it pops from scale 0.01 as the slide ends | `lid` |
| hint | lid off for that slot; the code peg drops into the active row with a sparkle | `hint` |
| win | lids off with `stagger(s, 0.12)`; the winning row's pegs hop 0.08 in 0.4 s with `stagger(s, 0.05)` | `solved` |
| loss | lids off with `stagger(s, 0.12)`, code pegs pop in | `reveal` |
| reset | pegs vanish with `stagger(g * length + s, 0.02)` from the far row; balls hide; missing lids drop from +0.6 with `stagger(s, 0.06)`; code pegs hide; tints fade | `reset` |

`_settle(g, s)` ends every tween on a cell (pivot y and rotation, breath y,
peg position and scale) at its target, as Binairo's does; a tap mid-motion
settles first. `_stop_all()` kills every tracked tween before a rebuild or a
reset. The board keeps arrays of tweens per cell (`_dips`, `_wobbles`,
`_peg_tw`, `_breath_tw`, `_fades`), per pip (`_pip_tw`), per lid (`_lid_tw`,
`_code_tw`) and the entrance list.

Particles use the pooled `Fx` node (four puffs, two sparkles): a place fires
one puff; a reset wave fires none.

## 5. The model library and the art pipeline

`core/models.gd`: `SLOTS` grows to `["tile", "rim_edge", "rim_corner",
"platform", "water", "socket", "peg", "pip", "lid"]` and gains

```gdscript
## Shows or hides the mesh named `node_name` under `root` (its outline shell
## is a child, so it follows). No-op when the name is absent.
static func set_layer_visible(root: Node, node_name: String, on: bool) -> void
```

The puzzle uses it for the peg marks (`Peg_Mark_k`), the feedback slab's well
(`Socket_Well`) and the pip balls (`Pip_Ball`).

`core/placeholders.gd` builds the four slots from primitives with the layer
names above: boxes and cylinders for the socket and lid, a `SphereMesh` of
radius 0.3 and height 0.44 for the dome, discs merged into one `ArrayMesh` per
mark layer, a disc and a sphere for the pip.

`art/codebreak.blend`: collections `Socket`, `Peg`, `Pip`, `Lid`, modelled in
the live Blender session through the MCP as a remote control (as the tile
was), never by a generator script. Base colours: `Stone` = `STONE`,
`Well_flat` = `MARK`, `Lid` = `STONE_GIVEN`, `Knob` = `WOOD`, the tinted
layers any plain colour, all converted to linear. Export and import:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/codebreak.blend \
  --python tools/blender_export.py -- Socket Peg Pip Lid
godot --headless --path . --import
godot --path . --resolution 720x720 --script res://tests/_shot_model.gd -- peg
```

`tools/build_models.sh` gains that export line; `.gitignore` un-ignores
`art/codebreak.blend`; `docs/art/blender-contract.md` and
`assets/models/README.md` gain the four rows.

## 6. Code structure

`puzzles/codebreak3d.gd` (`extends "res://core/puzzle_base_3d.gd"`), sections
in this order, mirroring Binairo: constants; state; `puzzle_id / title / rules
/ board_*`; `build`, `reset_board`, `is_solved`, `share_glyphs`; capabilities
(`capabilities`, `can_undo`, `undo`, `hints_left`, `hint`, `check`, `palette`,
`pick`); scene building (`_build_scene`, `_make_cell`, `_make_feedback`,
`_make_code_slot`); pieces (`_place`, `_vanish_peg`, `_show_mark`,
`_score_row`, `_activate_row`, `_lid_away`, `_lid_back`); tints (`_tint_row`);
motion helpers (`_dip`, `_settle`, `_stop_all`, `_enter`, `_stop_entrance`,
`_splash`, `_on_solved`, `_lose`); input (`on_board_press`, `cell_to_local`,
`slot_to_local`). `puzzles/mastermind.gd` is deleted; `mastermind_gen.gd`
stays as is.

## 7. Verification

No new test files. Updated:

- `tests/test_models.gd`: the `SLOTS` expectation, `HEIGHT_BUDGET` rows for the
  four slots (0.15, 0.5, 0.2, 0.3) and the outlined-layer table
  (`socket: [Stone]`, `peg: [Shell]`, `pip: [Pip]`, `lid: [Lid, Knob]`).
- `tests/_win.gd`: `_solve_mastermind` drives the 3D board through the HUD:
  for each slot it presses the tray button of the code's colour
  (`_host.action_bar.tray.buttons[i]`), then presses Check; the camera-fit
  check (every socket centre inside the board slot via `cell_to_local`) as
  Binairo's; `_note` reports the guesses.
- The suite (`godot --headless --path . --script res://tests/run_tests.gd`),
  the win harness (10/10), `_shot.gd` for `/tmp/shot_mastermind.png`, and
  `_shot_anim.gd` for idle frame time and draw calls, all run before the
  branch is called done. The screenshot is compared with the concept by eye.

## 8. Performance

Budget as the HUD spec's ruling: idle frame time at or under 8 ms at
1080 x 1920 on the Mac, draw calls at most 855. Estimate at rest with a full
board: 32 to 40 sockets and 8 feedback slabs with outlines, up to 40 pegs with
one visible mark each, 40 pips, 5 lids, the platform and rim, the stage and
the HUD: about 600. Measured numbers are recorded here when the branch is
merged.

## Files

New: `puzzles/codebreak3d.gd`, `ui/hud/palette_tray.gd`, `ui/hud/peg_button.gd`,
`art/codebreak.blend`, `assets/models/{socket,peg,pip,lid}.glb`,
`docs/art/concept-codebreak.png`, this spec, its plan.

Deleted: `puzzles/mastermind.gd` (and its `.uid`).

Modified: `core/puzzle_base.gd`, `core/models.gd`, `core/placeholders.gd`,
`core/palette.gd`, `core/motion.gd`, `ui/theme.gd`, `ui/hud/action_bar.gd`,
`ui/puzzle_host.gd`, `ui/registry.gd`, `tools/blender_export.py`,
`tools/build_models.sh`, `.gitignore`, `docs/art/blender-contract.md`,
`assets/models/README.md`, `tests/test_models.gd`, `tests/_win.gd`.
