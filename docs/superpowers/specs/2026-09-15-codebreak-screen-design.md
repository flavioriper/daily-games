# Code Break's screen: the dock, the scenery, POM and the wooden chrome — design

Concept reference: `docs/art/concept-codebreak-screen.png` (the user's image,
2026-09-15). Parent specs: `2026-09-14-codebreak-3d-design.md` (the board,
the pieces, the tray), `2026-09-14-binairo-hud-design.md` (the HUD panels
and theme), `2026-09-13-binairo-polish-design.md` (motion recipes, effects,
ambience) and `2026-09-13-3d-toon-pipeline-design.md` (stage, toon, model
library). `docs/art/blender-contract.md` binds every model here.

## Goal

Code Break's board already has the concept's structure: the code row under
lids, eight guess rows, the feedback column, the tray, Reset and Check. What
it lacks is the dressing. Today the board is a stone slab on a flat blue sea
(`/tmp/shot_mastermind.png` on 2026-09-15). After this pass it is a plank dock
laid on a turf bank over a river, with boulders, bushes, daisies, grass, pier
posts, a lantern and a hanging sign around it, POM sitting on a rock beside
the top rows, glossy pegs, a carved tray, and the wordmark and day card on
wooden plaques. The play, the HUD layout and every other board are unchanged.

## Decisions taken with the user (2026-09-15)

- All four layers are in: the board on a wooden dock, scenery around it, POM
  on the rocks, and the wooden HUD chrome. The user chose all four when
  offered them one at a time, knowing the HUD change reaches every screen.
- The design below was presented in chat in three sections and approved as
  one ("yes build it"). Anything the user dislikes is a one-line amendment.
- Scenery is **board-owned**: a node Code Break builds from library models,
  not a stage-wide island and not a painted backdrop. A backdrop cannot match
  the toon outlines or follow the camera breath; a stage-wide island would put
  every board on the same terrain today. A board-owned node leaves the camera
  fit alone, since the fit frames only the board's box, and other boards can
  adopt the same helpers later.
- The tray stays 2D. Six sub-viewports for six pegs were not worth the passes.

## Non-goals

- Other boards' scenery. Horse Pen's ring (concepts page) reuses the helpers
  later; nothing here changes another board.
- Sound, the solved card, the share sheet, the rules text.
- Depth of field or any post effect; the Compatibility renderer has none.
- Textures. The toon shader ignores them; grain and moss are geometry and
  colour.
- New unit tests. Existing model and platform tests learn the new slots.
- A rope-hung day card, a notebook prop, drifting leaves: cut for now.

## 0. Coordinates

Board space. One cell is one unit. Code Break's board is `length + 1` columns
by 9 rows; at `length = 4` the tiles span x from -2.5 to 2.5 and z from -4.5
to 4.5, the moss rim (`Platform.LIP` 0.5) reaches ±3 and ±5, the platform top
is y = 0 and its underside y = -0.6 (`PLATFORM_H`). Row 0, the code row, is
centred at z = -4 (far edge, top of the screen); row 8 at z = +4. At
`length = 5` add half a unit on each side in x. +Z is toward the player.

Measured with a throwaway probe on 2026-09-15 at the phone aspect: the
screen shows, on the y = -1.5 plane, x from about -6.7 to 6.7 at the far edge
and ±5.4 at the near edge, z from -11.3 (top of screen) to 9.0 (bottom). The
board slot spans z from -6.2 to 5.7. Everything the scenery places must fill
that window; anything beyond it is never seen.

## 1. The dock and the board pieces

**Deck.** New slot `deck`: one plank strip, footprint **exactly 1.0 x 1.0**
(stretched along X by the board, tiled edge to edge along Z), height 0.6 to
match `PLATFORM_H`, so `board_depth()` is unchanged. Two plank lobes in one
mesh (`Deck_Planks`, material `Deck`), each 0.47 wide, with a 0.06 gap between
them and 0.03 at each edge: the outline shells meet in the gaps and draw the
seams, which is the only way a seam survives the toon shader. Bevel 0.02, 2
segments, smooth. Base colour `DECK` (linear). Its shadow casting is off in
`Models._dress` (a strip laid on the bank casts into a 0.1 gap nobody sees).

`Platform.build(cols, rows, slab := "platform")` gains the third argument;
`""` lays the rim alone. Code Break calls it with `""` and builds a `Dock`
node holding that rim and the deck: `Scenery.deck(x0, x1, z0, z1)` lays one
strip per unit of z from `z0` to `z1`, each at `scale.x = x1 - x0`, top at
y = 0. Code Break's deck spans x from -(cols/2 + 1.5) to +(cols/2 + 1.5) (one
cell past the rim each side), z from -6 (one cell past the far rim, where the
pier posts stand) to +7 (two cells past the near rim, under the tray).
`tests/test_platform.gd` keeps passing unchanged, since the default is the
old behaviour.

**Pier posts.** New slot `pier_post`: a round log, footprint 0.4 x 0.4,
height 2.1, rounded top, one layer `Pier_Body` (`Bark`). Four stand at the
far edge at x = ±2.7 and ±3.8, z = -5.7, base at y = -1.6 (in the river, below
its surface), so the tops reach y = 0.5 above the deck. The x positions keep
clear of every lid's slide path at both board widths (lids at x = ±0.5, ±1.5
or 0, ±1, ±2; a lid is 0.94 wide, a post 0.4).

**Socket.** In `art/codebreak.blend`, `Socket_Well` becomes the floor of a
real recess: `Socket_Body` gets a cylindrical hole of radius `WELL_R` (0.3),
`WELL_DEPTH` 0.03 deep, and the well disc lies at Z = 0.09 inside it. Applied
boolean, smooth shading kept, bevel intact; the recess wall shades as a
dimple under the ramp. Pegs seat at `PEG_SEAT := SOCKET_H - WELL_DEPTH`
(0.09) instead of `SOCKET_H`: every `Placeholders.SOCKET_H` used as a peg
height in `codebreak3d.gd` becomes `Placeholders.PEG_SEAT`. The placeholder
socket keeps its solid body and moves its well disc to 0.09 (the tests read
layers and bounds, not holes). `board_height()` shrinks by 0.03 to match.

**Lid.** The knob is tinted `BARK` in `Models._dress("lid")`, so from above
it reads as a dark hole, as in the concept. Model unchanged.

**Peg.** A new layer `Peg_Shine` (`Shine_flat`, base colour `MOON`): a small
squashed ellipsoid patch, about 0.1 x 0.06, lying on the dome's surface at
the upper-left as the player sees it (Blender -X, +Y, about 45 degrees up the
dome), half buried like the marks. `_flat`, so no outline and no shadow. Every
peg shows it; nothing in code changes except the placeholder, which adds the
layer (a flattened sphere) so headless tests see the same contract. Exporter
budget for `peg` stays (0.7, 0.7, 0.5).

**Tray.** `ui/hud/palette_tray.gd`: the outer `wood_card()` holds a new inner
`PanelContainer` styled `CozyTheme.wood_channel()` (`card(WOOD_DEEP, 20,
WOOD_DEEP.darkened(0.25), 4, 10)`) which holds the button row: the carved
trough. `ui/hud/peg_button.gd` `_draw`: `SHADE` rises to 0.3, and after the lit
disc two highlights are drawn in `Color(MOON, 0.9 * alpha)`: a disc of radius
`0.2 r` at `centre + (-0.38 r, -0.42 r)` and a disc of radius `0.09 r` at
`centre + (-0.12 r, -0.6 r)`. The pips draw last, as today.

## 2. Scenery

All of it lives under one `Scenery` node the board adds beside the `Dock`.
Built by `puzzles/codebreak_scenery.gd` from helpers in `world/scenery.gd`
(section 7). Positions below are a fixed table in code, not runtime random:
the screen must look the same every day.

**Banks and river.** `Scenery.ground(size, at, colour)` returns a
`MeshInstance3D` with a `BoxMesh` in `Toon.material(colour)`, shadows off.
Two banks in `BANK`: the near bank, 40 wide, from y = -1.8 to -0.7, z from
-5.8 to 16 (its far face is the riverbank, 0.2 short of the deck's far edge,
so the deck overhangs the water); the far bank, same section, z from -10 to
-30. `Scenery.water(size, at)` returns a `PlaneMesh` carrying `Toon.water()`,
40 x 40 at y = -1.4 centred on the board; it shows between the banks as the
river, z from -5.8 to -10, and rings when a lid falls in because the material
is the shared one. The bank top sits 0.1 below the deck's underside: the
dock is a boardwalk laid on the grass, and the gap is hidden by tufts and
boulders where it faces the camera.

**Props.** `Scenery.prop(slot, at, yaw, scale)` instances a library model.
The table Code Break lays:

| slot | count | where | notes |
|---|---|---|---|
| `boulder` (new) | 10 | both sides of the deck, x = ±4.3 to ±5.6, z from -5 to 5, scale 0.8 to 1.6, varied yaw | `Rock_Body` (`Rock`, `BOULDER`) a rounded stone, `Rock_Moss` (`Moss_flat`, `MOSS`) a cap on top; footprint 1.0 x 1.0, height 0.6. One of them, flat and at scale 1.4, at x = 4.6, z = -3.2 is POM's seat; one at x = -4.6, z = 0.5 is the lantern's |
| `bush` (new) | 8 | the far corners behind the posts, the deck's sides between boulders, the near corners under the HUD | `Bush_Leaves` (`Leaf`, `LEAF`), four or five overlapping blobs in one mesh; footprint 1.0 x 1.0, height 0.7 |
| `daisy` (new) | 10 | on the bank beside the deck, between boulders | `Daisy_Petals` (`Petal_flat`, `MOON`) eight petals in one mesh, `Daisy_Centre` (`Centre_flat`, `SUN`); footprint 0.3 x 0.3, height 0.25 |
| `tuft` (new) | ~200 | scattered over both banks, never under the deck | `Tuft_Blades` (`Grass_sway_flat`, `TURF_TREE`): three blades in one mesh, footprint 0.3 x 0.3, height 0.25. Laid by `Scenery.scatter(slot, points)` as **one `MultiMeshInstance3D`** from the model's mesh and material, so the whole meadow is one draw call; the wind shader sways each instance since it works in mesh space. Points come from a seeded `RandomNumberGenerator` (fixed seed) rejecting the deck's rectangle |
| `signpost` (new) | 1 | x = -4.7, z = -2.5, turned about 25 degrees toward the board | `Sign_Post` (`Bark`), `Sign_Board` (`Timber`) a plank hanging from the post's arm, `Sign_Paper` (`Paper_flat`, `PARCHMENT`) on its face, `Sign_Words` (`Ink_flat`, `TEXT`): "THINK / TEST / ADJUST / SOLVE!" as four lines of Blender text in the display face (Fredoka), converted to mesh, 0.01 thick, half proud of the paper. Footprint 1.4 x 0.4, height 1.8; face on Blender -Y (Godot +Z). **Legibility check:** the letters land around 24 px in the stage shot. If the shot proves them unreadable, the fallback is a carved leaf on the paper (`Sign_Leaf`, `Ink_flat`) and no words; record the outcome as an amendment |
| `lantern` (existing) | 1 | on its boulder at x = -4.6, z = 0.5, scale 1.5 | glass tinted `SUN` by the scenery builder so it glows warm; iron unchanged. No light node: the toon shader takes one sun |
| `tree` (existing) | 5 | the far bank, x = -5.5, -2.5, 0.5, 3, 6, z from -10.6 to -11.4, scale 1.0 to 1.3 | closes the horizon at the top of the screen |
| `mascot_pom` (existing, dressed in section 3) | 1 | on its boulder, base at the boulder's top, x = 4.6, z = -3.2, scale 1.2, turned about 30 degrees toward the board | |

Base colours are set in Blender in linear (`docs/art/blender-contract.md`,
rule 5; the palette values are sRGB). Placeholders for the seven new slots
carry the same layer and material names, built from bars, cylinders and
spheres in `core/placeholders.gd`, so the board runs before the art lands and
the headless tests see the contract.

**BlenderKit.** Free rocks exist (Low Poly Coastal Rocks, ~10k faces) and are
worth one download attempt with the search-download-cleanup steps used for the horse, decimated
to a few hundred faces and cut to two layers; no usable free bushes, tufts,
daisies or signs turned up in the search on 2026-09-15, so those are modelled
from primitives in the live session. Either way the source is
`art/scenery.blend`, tracked, collections `Deck`, `Pier_Post`, `Boulder`,
`Bush`, `Daisy`, `Tuft`, `Signpost`, exported in one run.

## 3. POM

`art/mascot_pom.blend`, edited in the live session. The model already sits:
a round body with feet forward. It gains three layers, each its own mesh and
material per the contract:

- `Pom_Arms` (`Arm`, the body's base colour): two short arms as two lobes of
  one mesh, from the body's sides to the front, paws meeting in front of the
  muzzle at about a third of the body's height.
- `Pom_Pack` (`Pack`, `MOSS`): a rounded backpack on the back, about 0.5 of
  the body's width, with a flap lobe in the same mesh.
- `Pom_Map` (`Map_flat`, `PARCHMENT`): a folded sheet, 0.35 x 0.25, 0.01
  thick, held between the paws and tilted 30 degrees toward the camera. `_flat`
  so no outline swallows it.

Height stays under the mascot budget (1.4). Exported with the existing
mascot command, imported, previewed with `tests/_shot_model.gd -- mascot_pom`.

In the game the scenery builder places it as in the table. Motion: a
`Motion.pulse(pom, "scale:y", 1.0, 1.03, 3.0)` breath while the game runs,
kept in `_pom_tw` and killed in `_stop_all`; on `solved` a `Motion.hop(pom,
0.15, 0.4)`; nothing on loss. Under reduce-motion `pulse` returns null and POM
sits still.

## 4. Motion

Everything through the recipes in `core/motion.gd`; all decorative except the
place drop, as before.

| moment | change |
|---|---|
| entrance | the `Dock` (deck plus rim) rises from -0.5 as the platform did; then boulders, bushes, daisies, posts, the lantern and the sign pop from scale 0.01 with `stagger(i, 0.03)` starting 0.3 s after the dock lands, trees with them, POM last at +0.9 with `settle`. Banks, river and tufts stand from the first frame. All tracked in `_entrance`; `_stop_entrance` sets every prop's scale to one |
| entrance splash | `_splash()` rings the river, not the board's origin: at board-space (0, 0, -7) |
| lid off | `LID_SLIDE` 1.3 becomes **2.7** (a lid centred at z = -4 stops at -6.7, its near edge 0.23 past the deck's far edge at -6.0, over water); `LID_FALL` becomes **`RIVER_DROP` 1.4** (deck top to the river), replacing `Stage.WATER_DEPTH`. The splash rings at the lid's position as today |
| reset | unchanged; lids drop back from +0.6 |
| POM | breath and win hop, section 3 |

## 5. HUD: wooden chrome

Palette: `PLAQUE := Color("9c6b45")`, `PLAQUE_DEEP := Color("6e4a2f")`.
Theme: `CozyTheme.plank_card()` = `card(PLAQUE, 18, PLAQUE_DEEP, 10, 20)`,
`CozyTheme.wood_channel()` as in section 1.

**Top bar** (`ui/hud/top_bar.gd`): the `words` column moves inside a
`PanelContainer` styled `plank_card()`, itself inside a `CenterContainer`
that takes the expanding slot, so the plaque hugs the title and motto and
stays centred between the buttons. The panel's `draw` signal paints two nail
heads (`OUTLINE`, radius 6, at 18 px in from the top corners) and a second
leaf (`Icons.leaf`, `MOSS`, 36 px) at the bottom-left corner, mirrored; the
existing leaf stays at the title's top-right. `Wordmark` and `Motto` keep their
cream fill and dark outline, which read on the wood. The menu shares
`TopBar`, so "DAILY" sits on the same plaque.

**Day card** (`ui/hud/day_card.gd`): `slate_card()` becomes `plank_card()`;
the `OnSlateTitle` and `OnSlateBody` labels and the `MOSS` island icon stay
(cream and moss on wood). The menu's day card follows.

Buttons, the help card, the sheets, the line and status cards stay as they
are.

## 6. Model library, contract and tooling

`core/models.gd`: `SLOTS` gains `"deck", "pier_post", "boulder", "bush",
"daisy", "tuft", "signpost"` at the end. `_dress`: `"deck"` shadow off on
`Deck`; `"lid"` tints `Knob` `BARK`; `"boulder"` shadow off on `Moss_flat`;
`"daisy"` shadow off on both layers; `"signpost"` shadow off on `Paper_flat`
and `Ink_flat`.

`tools/blender_export.py` `LIMITS`: `deck` (1.0, 1.0, 0.62), `pier_post`
(0.4, 0.4, 2.1), `boulder` (1.0, 1.0, 0.6), `bush` (1.0, 1.0, 0.7), `daisy`
(0.3, 0.3, 0.25), `tuft` (0.3, 0.3, 0.25), `signpost` (1.4, 0.4, 1.8);
`EXACT["deck"] = (1.0, 1.0)`. `tools/build_models.sh` gains the
`art/scenery.blend` export line with the seven collections; `.gitignore`
un-ignores `art/scenery.blend`. `docs/art/blender-contract.md` and
`assets/models/README.md` gain the seven rows and note the peg's `Shine_flat`
and POM's three new layers.

Export and import, as always through the contract:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b art/scenery.blend \
  --python tools/blender_export.py -- Deck Pier_Post Boulder Bush Daisy Tuft Signpost
/Applications/Blender.app/Contents/MacOS/Blender -b art/codebreak.blend \
  --python tools/blender_export.py -- Socket Peg Pip Lid
/Applications/Blender.app/Contents/MacOS/Blender -b art/mascot_pom.blend \
  --python tools/blender_export.py -- Mascot_Pom
godot --headless --path . --import
```

Every model is built in the live Blender session through the MCP, saved to
its tracked `.blend`; no generator script.

## 7. Code structure

- `world/scenery.gd` (new, `RefCounted`, static, headless-safe): `ground`,
  `water`, `deck`, `prop`, `scatter` as described. No board knowledge.
- `puzzles/codebreak_scenery.gd` (new, `RefCounted`, static):
  `build(cols: int) -> Dictionary` returning `{"root": Node3D, "props":
  Array[Node3D], "pom": Node3D}`. Holds the prop table (positions scale with
  `cols` only in x), the tuft seed, and the lantern tint. Pure node building.
- `puzzles/codebreak3d.gd`: `_build_scene` builds `Dock` (rim from
  `Platform.build(size.x, size.y, "")` plus `Scenery.deck(...)`) and adds the
  scenery root; `_enter` and `_stop_entrance` rise the dock and pop the props;
  new constants `RIVER_DROP`, `ENTER_PROPS` 0.3, `PROP_STAGGER` 0.03,
  `ENTER_POM` 0.9, `POM_BREATH` 0.03, `POM_PERIOD` 3.0, `POM_HOP` 0.15;
  `LID_SLIDE` 2.7; `_splash` at the river; `_pom_tw`; peg heights on
  `PEG_SEAT`; `_on_solved` hops POM. The file's sections keep their order.
- `core/platform.gd`: the `slab` argument.
- `core/placeholders.gd`: `PEG_SEAT`, `WELL_DEPTH`, seven new builders, the
  peg's shine layer, the socket's well at 0.09.
- `core/palette.gd`: `DECK`, `BANK`, `BOULDER`, `PLAQUE`, `PLAQUE_DEEP`.
- `ui/theme.gd`, `ui/hud/top_bar.gd`, `ui/hud/day_card.gd`,
  `ui/hud/palette_tray.gd`, `ui/hud/peg_button.gd` as in sections 1 and 5.
- `tests/_shot_anim.gd`: takes an optional puzzle id after `--` (default the
  first entry) and only taps when the puzzle has `_given`, so the same probe
  measures Code Break.

## 8. Verification

No new test files (MVP rule). Updated: `tests/test_models.gd` (the `SLOTS`
expectation, `HEIGHT_BUDGET`, `FOOTPRINT`, `LAYERS` and the outlined table for
the seven slots; `peg` gains `Shine_flat` in `LAYERS`). Before the branch is
called done, all windowed where noted:

- the suite: `godot --headless --path . --script res://tests/run_tests.gd`,
  zero failures;
- the win harness, windowed: `godot --path . --resolution 1080x1920 --script
  res://tests/_win.gd`, every board winnable and Code Break's camera fit
  intact (`winnable=0/0` is a failed run);
- the screenshot walk, windowed: `/tmp/shot_mastermind.png` and
  `/tmp/shot_menu.png` compared with the concept by eye, and one other board's
  shot to confirm nothing else moved;
- the animation probe on Code Break, windowed, for the numbers in section 9;
- `tests/_shot_model.gd` for every new or changed model on the real stage.

## 9. Performance

Budget as the HUD spec's ruling: idle mean at or under 8 ms at 1080 x 1920 on
the Mac, draw calls at most 855. Baseline on 2026-09-14: 393 calls with four
pegs placed, 489 with the fullest board, 4.36 ms idle. Estimate for this pass:
deck 13 strips (26, no shadow), banks and river (3), tufts (1), boulders
(40), bushes (16), daisies (20), trees (25), posts (8), lantern (4), sign
(6), POM (about 40), peg shine (up to 40): about 270 more, landing near 760
at the fullest board. Measured numbers are recorded here as an amendment
when the branch merges; if the idle mean passes 7 ms the first cuts are the
daisy count and the tree count.

## Files

New: `world/scenery.gd`, `puzzles/codebreak_scenery.gd`, `art/scenery.blend`,
`assets/models/{deck,pier_post,boulder,bush,daisy,tuft,signpost}.glb`,
`docs/art/concept-codebreak-screen.png`, this spec, its plan.

Modified: `puzzles/codebreak3d.gd`, `core/platform.gd`, `core/placeholders.gd`,
`core/models.gd`, `core/palette.gd`, `ui/theme.gd`, `ui/hud/top_bar.gd`,
`ui/hud/day_card.gd`, `ui/hud/palette_tray.gd`, `ui/hud/peg_button.gd`,
`art/codebreak.blend`, `art/mascot_pom.blend`, `assets/models/{socket,peg,
mascot_pom}.glb`, `tools/blender_export.py`, `tools/build_models.sh`,
`.gitignore`, `docs/art/blender-contract.md`, `assets/models/README.md`,
`tests/test_models.gd`, `tests/_shot_anim.gd`.

## Amendments (implementation, 2026-09-15)

- The `daisy` has three layers, not two: `Daisy_Stem` (`Stem_flat`) reaches
  the ground, since the contract puts every base at Z = 0.
- The placeholder socket keeps its well disc on top; only the export carries
  the recess. The tests read layers and bounds, not holes.
- The `deck` slot is exact along X only (`EXACT["deck"] = (1.0, None)`); its
  depth is 0.94, the planks plus half a gap at each edge, so adjacent strips
  leave the same seam the two planks do.
- Sign words: modelled at Fredoka size 0.11, legible in the model render,
  not legible in the 1080 x 1920 board shot (about 45 x 35 px). Ruling: the
  words stay; on the board they read as writing on a notice, which is what
  the concept's sign is, and a carved leaf would say nothing. One Blender
  edit to the `Signpost` collection flips it if wanted.
- Signpost: the plank hangs 0.06 under the arm and the paper is inset (the
  first pass left the plank floating 0.47 below the arm); union bounds
  unchanged.
- Boulder: reworked once after review, from an 80-face sphere with a flat
  pentagon of moss to a finer rock (ico sphere at subdivisions 3, one
  applied subdivision level, jitter) with a smooth lobed moss cap; layers,
  names and budgets unchanged; `boulder.glb` is 61 KB.
- BlenderKit: the free rock tried arrived as one welded 9997-face formation
  that could not be separated into layers; the boulder is hand-built.
- POM: the map is held in the right paw beside the muzzle, face up at 60
  degrees, in MOON rather than PARCHMENT, because under the muzzle it was
  hidden at the board's 68-degree pitch and parchment vanished into the
  body's cream; arms are radius 0.12 from the shoulders; the assembly's
  footprint extremes are unchanged (nose -0.5885, tail 0.5885, ears
  ±0.6289). The far arm stays hidden by the body at the board's pitch.
  POM's seat boulder moved from x 4.6 to 4.9 so it and POM stand clear of
  the deck's edge.
- `puzzles/codebreak3d.gd` no longer preloads `world/stage.gd`: nothing read
  `Stage.WATER_DEPTH` once the lids fell to the river.
- Measured on the Mac at 1080 x 1920 with `tests/_shot_anim.gd -- mastermind`:
  first pass `idle mean_ms=5.54 max_draw_calls=890`, over the 855-call
  budget though well under the 8 ms mean. `DAISIES` cut from ten entries to
  six and `TREES` from five to three in `puzzles/codebreak_scenery.gd`
  (balanced left/right rather than a plain truncation); re-measured
  `idle mean_ms=5.40 max_draw_calls=862`, seven calls over the 855 budget
  still, flagged here rather than cut further without a review. Binairo
  unchanged at `idle mean_ms=4.58 max_draw_calls=723`. Suite
  `passed=1553 failed=0`, win harness `12/12`.
