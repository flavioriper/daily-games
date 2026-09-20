# Agent guidelines

## Art: Blender models

Full rules: `docs/art/blender-contract.md`. The short version every agent must
follow when touching a model:

- **One mesh per layer.** Every visual layer (each colour region or detail:
  body, colour cap, each ear, each eye, muzzle, nose, mouth, tongue, each
  cheek, each foot, tail) is its own mesh object with its own material. Never
  merge layers into one mesh, never put two materials on one mesh. This is
  what makes a layer textureable on its own later. Two lobes of the *same*
  layer (one material) may share a mesh.
- **The `.blend` is the source.** Mascots are modelled in the live Blender
  session and saved to `art/mascot_<name>.blend` (tracked in git). Never write
  a script that rebuilds a mascot from scratch; the Blender MCP is a remote
  control for edits, not a generator.
- **Export through the contract check**, never by hand:
  `Blender -b art/mascot_pom.blend --python tools/blender_export.py -- Mascot_Pom`
  then `godot --headless --path . --import`.
- **Preview on the real stage** with `tests/_shot_model.gd` (toon shader,
  outlines) before calling a model done; Blender's viewport colours are not
  what the game shows.

## Art: never bake a model down to an image

**A model ships as a model.** Never render a `.blend` to a PNG, an atlas or a
sprite sheet and put that on screen in place of the geometry -- not for HUD
chrome, not for menu cards, not for a title, not for anything. Export the
`.glb` through `tools/blender_export.py` and put the real thing in the scene.

**Why:** a baked image throws away everything the model was modelled for. It
cannot be lit by the scene, cannot take the toon shader or the outline pass,
cannot be recoloured or textured per layer (which is the entire point of the
one-mesh-per-layer rule above), cannot animate or be turned, and goes soft as
soon as it is drawn larger than the resolution it was baked at. It also freezes
the art at one camera and one light, so it stops matching the game the moment
either of those changes -- and it will, this game has already re-pitched its
camera once.

If draw calls are the reason to hesitate, say so out loud and measure it
against the budget in `docs/art/blender-contract.md`. Do not quietly trade the
model away for a picture of it.

## What the harnesses actually measure

**Run a render harness at `--resolution 810x1440`, never `1080x1920`**
(measured 2026-09-19). This Mac's display cannot show 1920 rows, so the
window clamps to 1080x1676, and `stretch/aspect="expand"` then keeps the
height and *widens* the canvas: `get_visible_rect()` comes back
**1237x1920**, 15% wider than the phone the game is drawn for. `810x1440`
and `720x1280` both come back exactly **1080x1920**, which is the design
space every layout in this file is written against.

Be precise about what that spoils and what it does not, because most of the
figures here were taken with the old flag:

- **Width-sensitive layout is wrong at the old flag, and measurably so.**
  The first screen's card measures **320** wide at 810x1440 and **372** at
  1080x1920 -- and 320 is the number the card-art budget, the 320 by 118
  picture box and the "about seventeen characters a line" of `short` are all
  written against. A frame shot at the old flag showed cards 16% wider than
  the phone will, with the air between them wrong to match.
- **Height-bound cells are the same either way.** Hidden Word's tile is 149
  at both, because six rows of five in a 9:16 slot are bound by the height;
  so is its 801 by 964 block. What differs is the card *around* it: 1000
  wide against 1157.
- **Draw calls did not move.** The first screen reads 311 at both flags on
  the same build (2026-09-19), so the counts recorded in this file are not
  invalidated by the width -- and the 855 budget is unaffected. Frame times
  were not compared across the two and no claim is made about them.

What has *not* been rechecked is every older recorded layout number taken
from a frame at the old flag. Treat a pixel measurement in this file that
predates 2026-09-19 as taken on a 1237-wide canvas until it is re-shot; a
draw-call count, a budget figure or a design-space constant is fine.

## The first screen

**The first screen is a page of cards** (`ui/menu.gd`, 2026-09-18): the
wordmark in ink with its golden sun-dot and the sun and moon beside it, a day
row, twelve
puzzle cards three across and four down, and a bottom bar. There is no
stage on it, no `World3D`, and no model anywhere -- `world/main.tscn` does
not even carry a Stage node any more. It replaced the campsite, which is
still reachable; see "legacy/" below.
Spec: `docs/superpowers/specs/2026-09-18-flat-menu-design.md`.
Mock: `docs/art/concept-menu-flat.png`, playable at
`docs/brainstorm/concepts.html#menu`.

- **The heights are a budget, not a taste.** At 1080x1920: 80 of margin, 60
  of gaps, a 380 header, a 180 day row and a 150 bar leave 1070 for four
  rows, so a card is 252 and spends it on a 92 picture, a 34 name, two 23
  blurb lines and a 16 inset. The card carries its own paper stylebox
  rather than `CozyTheme.paper_card()` for that inset: the HUD's usual 24
  and the mock's 118 picture came to 277 a card and pushed the bar off the
  screen. Anything added to the header, the day row or the bar comes out of
  the pictures.
- **The sun-dot is the i's dot, not a sticker over it** (`ui/sun_dot.gd`,
  2026-09-19). It sets the label's lowercase i in Fredoka's dotless `ı`
  and seats a small sun where the font's dot was, measured off the
  rendered face: a circle 0.64 em above the baseline, 0.09 em in radius,
  centred on the glyph's advance box, at 140, 84 and 32 alike. The seat
  comes from `Label.get_character_bounds`, so alignment and margins need
  no arithmetic. A rayed sun (84 and up) floats 0.03 em higher so its
  bottom rays clear the stem; the 32 px card names get a plain disc,
  because a ray a pixel wide is a smudge. The wordmark's sprig does **not**
  grow out of the sun: the user moved it off the i on 2026-09-19, and it
  stands on the a instead, the letter before the sun, where the Binairo
  lockup roots its own sprout (the A of BINAiRO). It is drawn from that
  letter's character bounds, at Fredoka 700's x-height (0.507 em) with its
  foot sunk three pixels into the ink. A rayed sun idles like the header's
  sun: rays turning once in 40 s, and a glint every few seconds (rays flare,
  a shine mesh rises and fades on the boards' flash timings); a plain disc
  never moves. It costs the header one draw call over a still sun.
- **The menu paints its own page.** The campsite used to fill the frame, so
  the old menu never drew a background and the viewport's clear colour --
  the stage's sky -- showed through. With nothing behind this screen,
  `_build_list` lays a `Pal.PAPER` rect under everything.
- **A card's picture is the board's own cast** (`ui/menu/card_art.gd`):
  `ui/faces/` characters seated in a 320 by 118 box and scaled to the card,
  plus whatever furniture they stand on drawn under them. Ten of the twelve
  are almost entirely reuse. It is never an image and never a `SubViewport`.
  A new card costs one branch of `_build` and, if it needs furniture, one of
  `_draw`.
- **Twelve cards, all twelve live, and no `soon` card left.** Three left the
  grid in a week, each being redesigned outright and each keeping its island
  board under More: Snake Apple's on 2026-09-19 to make room for Queens
  (`seed_as` still `snake`), Horse Pen's the same day for Hidden Word
  (`seed_as` still `horse`), and Pipes' on 2026-09-20 for Word Trail, the
  twelfth live card (`seed_as` still `pipes`). **The dimmed-card machinery
  is now unexercised**: the registry's `soon` flag, the 55% ink, the pale
  `SOON` pill and `ui/menu.gd`'s `blocked` signal (which answered with a
  line saying the island version is under More) are all still in the code
  and nothing on the screen reaches them. They stay there for the next board
  that is named before it is drawn -- and with them the two rules they were
  built with, learned the hard way and not to be re-derived: a dimmed card
  holds the last slot of the last row, because dimmed cards scattered
  through the grid read as a bug rather than as a plan; and the pill hangs
  off the card, **not** off `_inner`, which is a PanelContainer where a
  second child is stretched over everything.
- **The hearts, the calendar badge and the day chevron are decoration**, by
  the user's decision on 2026-09-18. `Day N` and the day's name are real
  (`core/progress.gd`); nothing else on that row counts anything. There is
  no three-a-day goal, no streak health and no lives, and nobody should read
  a progression system into a drawing of one. Stats and Streak in the bar
  are drawn and inert for the same reason, and say so when pressed.
- **The registry is two lists.** `Registry.PUZZLES` is the grid (twelve flat
  boards, no `soon`); `Registry.LEGACY` is the old game. A grid entry
  carries `short`, the card's own two-line blurb -- at 320 wide a card fits
  about seventeen characters a line, which `blurb` does not.
- **Measured on this Mac** (`tests/_shot_menu.gd` at `--resolution 810x1440`,
  which is the true 1080x1920 of design space -- see "What the harnesses
  actually measure" above): **322** draw calls against the campsite's 338
  and the 855 budget, twice in a row on 2026-09-20, and a mean idle of
  8.32-8.33 ms -- which is exactly the 120 Hz vsync cap, and this harness
  never disables vsync, so it is a ceiling and not a measurement. What can
  be said honestly is that the campsite sat at ~13 ms, above the cap, and
  this screen is inside it. **It read 311 on 2026-09-19**, and the +11 is
  one card swapped, not one added: Pipes' dimmed `soon` card left the
  twelfth slot and Word Trail's live card -- the sprout and a 4x3 field of
  letter tiles with a trail bending through it -- took it. The count read
  311 at the old `1080x1920` flag too (2026-09-19), so what the wider canvas
  moved was the layout and not the calls. Before that it was 291 before
  Queens and 319 with Queens beside Horse Pen's `soon` card; swapping that
  card for Hidden Word's live one took it to 311, and Hidden Word's own
  picture is 7 of that 311 -- checked on the same build with its `_draw`
  branch stubbed out, at 304, twice. Of the older rise, the Queens card
  alone cost 12 and the rest predates it: the header's turning, glinting sun
  and later changes since 291 was first measured.

## legacy/: the old 3D game

Everything built on the 3D stage moved to `legacy/` on 2026-09-18 and still
runs: the thirteen island boards, How Big?, the campsite menu, the stage,
the toon and model pipeline and the island HUD. Reached from the first
screen's **More** tab (`ui/menu/legacy_sheet.gd`), whose last row is the
campsite menu itself. Nothing new belongs in there, and the notes below are
kept because they are hard-won, not because they describe the game now.

- **Nothing live loads a line of it, and it has to stay that way.** Two
  knots were cut to make that true, and neither may be retied.
  `core/puzzle_base.gd` used to extend `StageView`, so every flat board
  inherited stage mounting, camera fitting and ray picking it never called;
  it is a plain `Control` now, and the island boards extend
  `legacy/core/stage_board.gd`, which carries the stage machinery **and a
  frozen copy of the contract** (GDScript is single-inheritance, and a
  frozen copy also means a change to the live contract cannot break thirteen
  retired boards). `class_name StageView` is gone so nothing can reach the
  stage by a global name. And `ui/flat/flat_host.gd` used to extend the
  island host, whose chrome pulls the carved sign, the model views and the
  whole toon pipeline behind it; `ui/puzzle_host.gd` is shell-neutral now,
  with `_build_chrome` and `_enter` the two methods a shell fills, and
  `legacy/ui/island_host.gd` is the island's. `ui/fx2d.gd` owns its own star
  texture for the same reason.
- **The stage is mounted on demand.** `ui/menu.gd`'s `_raise_stage`
  instantiates `legacy/world/stage.tscn` beside the UI canvas when something
  from More opens, and frees it when that host closes.

### The title signs, and the campsite that was the first screen

Every puzzle's HUD row carries a carved wood sign as its title. It is a real
model on screen, not a picture of one: `assets/models/title_sign.glb`,
instanced through `Models.instance("title_sign")` so it takes the toon shader,
the grain on its plank, its own cast shadow and the outline pass.

- **The board is modelled; the words are data.** `art/sign.blend` holds three
  layers (plank, leaf sprigs, screws) exported as the `Title_Sign` collection
  by `tools/build_models.sh`. The title and motto are **not** in the .blend:
  `legacy/ui/hud/sign_view.gd` extrudes them with `TextMesh` through
  `legacy/core/lettering.gd`, so a new puzzle costs a registry line and no export.
- **Every model in the HUD stands in a `legacy/ui/hud/model_view.gd`**: a SubViewport
  with its own `World3D`, the stage's calibrated light (0.46 sun over 0.115
  ambient, *measured* against a rendered frame because gl_compatibility
  renders brighter than the shader maths predicts) and an orthographic camera
  framed on a box. It draws **on demand**, not per frame: over a dozen live at
  once on the menu, and on UPDATE_WHEN_VISIBLE they cost 18.6 ms against a
  ~5 ms idle baseline. Call `redraw()` after anything that changes what one
  shows. The sign, the menu's title letters (`title_view.gd`) and the cards'
  dioramas (`card_scene.gd`) are its three users.
- **Outline shells get their own thin materials here** (`Lettering.outline`,
  0.005 rather than Toon's 0.014): a sign is drawn far larger than a stage
  piece, so the world-space shells read several times too thick. Never set a
  width on `Toon.line()`'s materials; those are shared with the stage.
- **TextMesh cannot extrude every glyph.** The display face's digits 8 and 9
  and the question marks `?` `¿` cross themselves at weight 700 and vanish,
  and even at 550 their caps come and go with the font size under TextMesh's
  default curve step; `legacy/core/lettering.gd` drops a line that carries a digit
  or a question mark to weight 550 *and* a curve step of three hundredths of
  its font size, the pair measured to extrude them whole at every size tried.
  Upper-case everything that goes on a board.

**The campsite was the first screen until 2026-09-18**, and is now the last
row of the More sheet (`legacy/ui/camp_menu.gd`, which draws a back button
and emits `closed` when it is opened that way, and whose cards are
`Registry.LEGACY`). `legacy/world/camp.gd`
is mounted on the stage in place of a board, staged the way the concept
banner (`docs/art/concept-menu-banner.png`) frames it: the scout
(`mascot_scout`, alive through `legacy/world/mascot.gd`) reading his map on the
dock with the river behind him, the day sign lettered live at his left, the
lantern between them on the path, the tent and the tree line behind, and
the "A puzzle a brighter you" board at the dock's corner. The fence diorama
(`camp_sign`) that used to close the frame at the bottom with a motto plank
was dropped on 2026-09-17 at the user's request; the lawn runs to the
bottom and the page buttons stand on it. `tests/preview_tree.tscn` mounts
the same `Camp` under a fixed camera, so the editor shows the real thing.
The menu frames `camp.hero_box()` in the screen above the cards after
every layout change.

- **The menu camera is a shift lens** (`CameraRig.shift_fov_deg`, passed as
  `fit_camera`'s `shift_fov`), posed the way the camp asks (`Camp.VIEW_PITCH`,
  `VIEW_YAW`, `VIEW_FOV`): from a step to the left of the camp, 13.7 degrees
  down, 90 degrees across the hero strip, with the frustum slid so the strip
  lands at the top of the screen. Standing close and off to the left through
  a wide field is what shows the scout's left side and lays the dock and the
  day sign at an angle; the head-on 54-degree view it replaced read flat. The
  ordinary perspective had to aim under the camp through a narrow field to
  hold it up there, which flattened and shrank it. `tests/preview_tree.gd`
  takes the same pose off the camp, so the editor shows the menu's view.
  It is Godot's frustum projection with an offset, and in 4.7
  `project_position` and `project_ray_normal` mis-scale that offset while
  `unproject_position` is right: anything that needs a ray or a pixel size
  on the menu asks the rig (`ray_origin`, `ray_normal`,
  `pixels_per_unit_at`), never `Camera3D` directly.
- **The campsite has its own light, palette and soft focus; boards do
  not.** Its light and colour aim at the painted frame
  `docs/art/concept-menu-painted.png` (2026-09-17), not the banner; the
  section "The first screen's light" in `docs/art/shading-direction.md`
  holds the calibration. `Stage.show_setting(true)` applies `grade_camp` (a
  low golden sun from the right over a dark cool bounce, contrast up and
  saturation left alone, a soft bloom, a deep sky over a warm horizon, the
  shared water in deep teal) and shows `legacy/world/soft_focus.gd`, a full-screen
  quad that blurs by view distance past the framed thing by reading the
  screen texture's mip levels, since Compatibility has no depth of field;
  it also blurs and darkens what stands nearer than the framed thing, in
  the top of the frame only (`near_gate`; the lawn under the cards is as
  near and already takes the vignette), and lays a soft vignette over the 3D
  world. `show_setting(false)` restores the boards' measured pair, the
  sun's direction, the sky and the water colours and hides the pass, so a
  piece is lit exactly as calibrated. The camp's own greens are
  `Pal.CAMP_*`; a board's TURF and LEAF never changed. On Compatibility the
  screen and depth textures only exist during the transparent pass, so the
  quad is `blend_mix` with a low `render_priority`; anything that must stay
  in front of the blur has to draw in the opaque pass (the clouds went to
  alpha scissor for this). `SCREEN_UV.y` runs top-down in a spatial shader
  here. Measured on this Mac at phone resolution: the whole menu idles at
  about 13 ms against 10 before the painted pass, the soft focus itself is
  2.8 ms, the grade 1.2 ms and the lawn under the cards 2.3 ms; if a phone
  drops frames on the menu, `Camp.NEAR_GRASS` and the soft focus's
  visibility are the two levers, in that order.
- **The camp has weather, and boards do not.** `wind_gust` is the second
  global shader parameter beside `motion_scale` (`legacy/world/ambient.gd`,
  `shaders/wind.gdshaderinc`): 0 everywhere, and 1 only while the campsite
  is on the stage, so a board's rim grass keeps exactly the flutter it was
  calibrated with. `Stage.show_setting` sets it with the pollen and the
  grade, and reduce-motion stills it along with everything else (measured:
  two frames 1.5 s apart come out pixel-identical). Over the old flutter it
  lays a gust -- a band travelling across the world along `wind_dir`, one
  crest every 13 units, cubed so the lull is long and the crest arrives
  quickly. `toon_wind`, `outline` and `card_wind` all `#include` the same
  file, because a gust each shader reads differently is a shimmer rather
  than a wind; the gust's direction is taken back through the model's own
  basis so every prop leans the same way in the world however it is turned,
  which the flutter never had to bother with.
  What blows: the grass, the blossom and foliage cards, the bushes and every
  tree crown. A layer's lean is shaped by four `sway_*` parameters
  (`Toon.SWAY_BLADE`, `SWAY_CROWN`, `SWAY_BUSH`, `SWAY_CARD`), read in the
  model's own units so the prop's scale carries them, and `Toon.line_for`
  copies them onto the outline shell -- a line left on the shader's defaults
  peels off the layer it rings. Aim `wind_dir` much further toward the camera
  and the field leans down the view, which reads as growing, not bending.
- **The lawn is sown to what the camera actually sees, which is far less
  than it looks.** The near lawn under the cards is the wedge from
  (x -2.9..3.4, z 7.9) to (x -0.9..0.9, z 10.5) in the camp's space -- about
  eleven square units -- because at the bottom of the screen the shift lens
  is looking almost straight down from (0, 2.7, 10.8). Cast the rig's rays
  at the screen's own pixels before sowing anything: a MultiMesh is culled as
  one thing and never per instance, so a tuft off screen costs its vertices
  every frame and shows nothing. Two grasses carry the ground:
  `grass_patch` (480 triangles) where the camera is close and `grass_clump`
  (98) for the wide fill. Three new fields cost three draw calls (326 to 329
  on the menu, against the 855 budget) -- the bill is triangles and fill,
  never calls.
- **Instance shader parameters are unusable here; nothing may reintroduce
  one.** Any canvas item or mesh whose material's shader *declares* an
  `instance uniform` reserves a 16-item block of the global shader buffer,
  set or not, and the gl_compatibility shaders declare that buffer as 256
  items -- **sixteen instances in the whole frame**. Past that, index is out
  of the array's range: a desktop driver reads on into the real 4096-item
  buffer and looks perfectly right, which is why this Mac never showed it,
  and a mobile driver hands back garbage. Measured on Android 2026-09-17:
  twenty-five wood meshes stood on the How Big? screen (the deck, the day
  card, and the menu's card dioramas still in the tree behind the host); the
  deck's grain came back as chopped dashes, because a garbage `grain_seed`
  throws the figure's noise coordinates where `floor`/`fract` lose precision,
  and the day card's carved edge chewed the card into a lattice of blocks,
  because a garbage `plank_size` turns the silhouette's alpha cut into a
  staircase. `--rendering-driver opengl3_angle` reproduces the class on this
  Mac (it reads zero rather than garbage, so the cut simply vanishes) and is
  the cheapest way to check anything suspected of being mobile-only.
  The two that used it now use plain uniforms: the wood's log seed with one
  material cached per log (`legacy/core/toon.gd`, `GRAIN_LOGS`), and the day card's
  `plank_size` on the panel's own material (`CozyTheme.plank`). Neither costs
  a draw call (338 on the menu either way); the wood cache went 6 to 22.
- **The camp stands at y 2** (`Camp.LIFT`): the backdrop's hills ring is a flat
  plateau at about y 1.4, and the menu camera stands out over that ring where
  a board's never does. At y 0 the camp's feet are buried in it.
- **The campsite's cards came in pages of nine**, turned with the buttons
  under the grid, not a scroll. The flat screen has no pager: twelve fit. Each card's picture is a live diorama of that puzzle's own pieces
  (`legacy/ui/hud/card_scene.gd`), never an image; a new puzzle costs one builder. A
  full page of nine measures 318 draw calls against the 855 budget, on this
  Mac at phone resolution -- the cards are what a page costs, so a page, not
  the whole registry, is the unit to measure against the budget.

## The flat screens

Twelve cards open a flat 2D board under flat chrome: **Binairo**
(`puzzles/binairo2d.gd`), **Code Break** (`puzzles/codebreak2d.gd`),
**Balance** (`puzzles/balance2d.gd`), **Shikaku**
(`puzzles/shikaku2d.gd`), **Untangle** (`puzzles/untangle2d.gd`), **Tents**
(`puzzles/tents2d.gd`), **Light Up** (`puzzles/lightup2d.gd`), **One Line**
(`puzzles/oneline2d.gd`), **Nonogram** (`puzzles/nonogram2d.gd`) and, since
2026-09-19, **Queens** (`puzzles/queens2d.gd`) and **Hidden Word**
(`puzzles/hidden_word2d.gd`), and since 2026-09-20 **Word Trail**
(`puzzles/word_trail2d.gd`).

Each was built on trial beside its island, as a second card seeded from the
same day, so the two could be judged on the phone. **The trial is over**:
on 2026-09-18 the game went 2D, the first screen was redrawn flat and every
island moved to `legacy/`. The islands keep `seed_as` pointing at their flat
twin, so a board opened from More still hands out the same day's puzzle.
Specs:
`docs/superpowers/specs/2026-09-18-binairo-flat-design.md` and its
`...-codebreak-`, `...-balance-`, `...-shikaku-`, `...-untangle-`,
`...-tents-`, `...-lightup-`, `...-oneline-` and
`...-nonogram-flat-design.md` siblings, and
`docs/superpowers/specs/2026-09-19-queens-flat-design.md`,
`...-hidden-word-flat-design.md` and
`docs/superpowers/specs/2026-09-20-word-trail-flat-design.md`; mocks:
`docs/brainstorm/concepts.html#binairo`, `#codebreak`, `#balance`, `#shikaku`,
`#untangle`, `#tents`, `#lightup`, `#oneline`, `#nonogram`, `#queens`,
`#hiddenword` and `#wordtrail`.

- **Every flat board moves with one hand.** `docs/art/flat-motion.md` is the
  table: the press, the pop in and out, the hop, the nudge, the drop, the
  ring, the entrance and the solve wave are recipes and constants in
  `core/motion.gd` ("the flat boards' vocabulary"), lifted from Binairo on
  2026-09-18 when Code Break was put on them. A new or a ported board calls
  those and keeps only its own signature (Binairo's blush, Code Break's
  flight and lids) as constants of its own; a number that has to differ goes
  through a recipe's parameter, never a copied constant. Rings, puffs and
  sparkles come from `ui/fx2d.gd` alone. Balance joined them the same day
  (its spec's section 10), and brought `ui/flat/scenery.gd`: one mesh of
  clouds and grass tufts under a board card, and the radial disc every
  ground shadow is drawn with. Untangle joined on 2026-09-19 (its spec's
  section 11), and it is the precedent for a board whose motion is
  integrated rather than tweened: the point's motion (the drag, the two
  springs, the scripted walks) stays on the board's clock, and every lantern
  stands in a slot the board owns so the paper can take the recipes;
  `Motion.lift` is the press for a dragged thing, and a board that already
  rebuilds a mesh builds its shadows into it with `Scenery.soft_disc`.
  Shikaku joined on 2026-09-19 too (its spec's section 11), and it is the
  precedent for a board whose pieces are drawn rather than nodes: it reads
  the recipes as curves off `Motion` (`back_out`, `pop_in_scale`,
  `wide_pop_scale`, `pop_out_scale`, `drop_in_lift`, `bump_scale`,
  `flash_level`), handed the seconds since the moment began, so a drawn bed
  and a tweened tile move as one hand and no board copies a number. Tents
  joined the same morning (its spec's section 10), and it is the precedent
  for a board with both media: trees, tents and chips are nodes in slots
  taking the recipes, the cairns and the shade under the sweep are drawn off
  the readers, and a piece with no blushing skin (a tree) blushes through
  its cell (the doc's rule 9). Light Up joined on 2026-09-19 as well (its
  spec's section 11), and it completed the curve readers: every recipe a
  node takes now has its reader on `Motion` (`press_scale`, `hop_lift`,
  `nudge_offset`, `shiver_offset`, `wobble_angle` beside the pops and the
  flash), so a drawn board needs nothing new from `core/motion.gd`; its
  lamps stand in slots and its blocks, chips and stones are drawn off the
  readers, the stone itself sinking under the finger. One Line and Nonogram
  joined that afternoon (each spec's section 11), which put all nine flat
  boards on the vocabulary; neither needed anything new from it. One Line
  is the precedent for a board whose one character rides a clock: the
  walker's seat takes the ride, the facing and the rock every frame, and the
  snail inside takes the recipes (pop, drop, press, hop), while the far post
  keeps its old cap until the snail lands and takes the new one with the
  Count bump. Nonogram is the precedent for drawn text on the vocabulary:
  its clue numbers go through one `draw_set_transform` per line, so they
  pop in, bump and hop off the same readers as the mesh, and
  `ui/faces/mosaic_tile.gd` takes a Vector2 scale, a turn and a blush so a
  drawn tile can squash, wobble, turn out and flash.
- **Queens is the precedent for a board that answers a move** (2026-09-19,
  `puzzles/queens2d.gd`, spec `2026-09-19-queens-flat-design.md`). A seated
  queen crosses out every cell she sees; those crosses are **derived** by the
  state (`seen`, a count per cell rebuilt after every change) and never
  stored, so lifting her takes them with her and undo keeps no book for
  them. A crown on a seen cell is **refused**, so two queens can never
  conflict and the n-th queen is the win. The wave is its signature: every
  move goes through one `_settle` that diffs a snapshot of the court against
  the state and hands each changed cell its moment, with a Callable saying
  when -- a queen's king-move distance times `WAVE_STEP` (reversed for a
  lift, far cells first), a sweep's path, Reset's far corner -- and the
  cells the queen sees flash gold (`QUEEN_WASH` at `WAVE_FLASH`) as it
  reaches them. The queen bee (`ui/faces/bee_face.gd`) is the cast's one new
  species since the snail: a chibi bee in a small crown, who replaced a
  plain crown with a face on the evening of 2026-09-19 from the user's
  second mock (`docs/art/concept-queens-bee.png`). Her wings are a second
  layer that beats through `Face._layer_transform`, a squash about her
  shoulder line, so a beat rebuilds no mesh and costs one draw call a bee
  (71 on the strip with a queen seated and the chip alive, against 69). The
  tile tray takes a **chip set** now (`TileTray.MOSAIC`, `TileTray.QUEENS`;
  `"tray": "queens"`), so Nonogram's tray and Queens' are one class.
- **Hidden Word is the first board that can end without a solve** (2026-09-19,
  `puzzles/hidden_word2d.gd`, spec `2026-09-19-hidden-word-flat-design.md`).
  Five letters, six rows: type a guess, commit it, and the row turns over a
  tile at a time -- green in the right place, amber in the word elsewhere,
  grey not in it. **The commit is the one irreversible move on any flat
  board**: there is no Undo and no Check, an Enter spends a row, and when the
  sixth is spent the board calls `PuzzleBase.finish_unsolved()`, which sets
  `_done` and emits **`ended`** rather than `solved`. The host connects that
  behind `has_signal`, because `legacy/core/stage_board.gd` carries a frozen
  copy of the contract that predates it and must stay frozen. The keyboard is
  its tray (`ui/flat/key_board.gd`, `"tray": "keys"`), and it is the first
  board with **no tip card** (`"tip": false`) and no actions row. Its
  `rules()` string is real and the rules sheet is built and refreshed for it
  like any other board, but **there is currently no way to open it**: every
  other board's tip card is the sheet's only door
  (`tip_card.open` to `_open_rules` in `ui/flat/flat_host.gd`), and Hidden
  Word has no tip card. This is an open question for whenever the tip card
  is retired across the other ten boards, tracked in the spec's amendments;
  it is not a claim that the keyboard explains the rule, which it does not.
  **The flip is its signature** and its
  numbers are its own three (`FLIP_STEP`, `FLIP_TIME`, `TOAST_HOLD`), with
  six more for the ending -- the keyboard's exit, two dim levels, the dim's
  time and the sprout's rise -- which stand in the board because nothing else
  in the game can run out, so `core/motion.gd` would never read them. A
  refusal is a toast over the card and never a silence. It ships words:
  `content/hidden_word.json` (968 answers in three bands) and
  `content/hidden_word_accept.txt` (15,921 a guess may be), and `content/*`
  had to join the export preset's `include_filter` to reach the APK at all --
  which was also quietly true of How Big?'s table. **Never call it Wordle**,
  in code, in a comment or on screen; the New York Times owns that, and this
  repo already ships Mastermind as Code Break for the same reason.
  Measured on this Mac with `tests/_shot_anim.gd -- hiddenword` at
  `--resolution 810x1440`: **110** draw calls with the first row committed and
  the keys repainted (109 bare, 109 to 111 over fourteen runs), and **56** in
  the losing reveal, where the keyboard has gone and the grid is dimmed --
  all well inside the 855 budget. Its idle reads about **5.0 ms**, and that
  figure deserves a caveat: fourteen runs spread 3.06 to 7.30 (median 5.00).
  Queens, run as a control in the same session, swung as widely -- 4.40,
  4.62, 4.45, 2.84, 4.55 and 4.52, a factor of 1.6 against the 3.83 recorded
  in its own spec -- which is what shows the spread is this machine's and not
  this board's, and why **a single reading off this harness is worth
  nothing**. Compare a board only against another board measured the same
  hour, and quote every reading, including the flattering one. The reveal,
  which draws half as much, read 1.88 and 1.92. Checked on the phone's driver
  (`--rendering-driver opengl3_angle`): same 110 and 56, and the settled
  frames match the default driver to 21/255 on edge antialiasing alone, so
  nothing has reintroduced an `instance uniform`.
- **Word Trail is the twelfth board, and the first whose signature is a
  drawn path** (2026-09-20, `puzzles/word_trail2d.gd`, spec
  `2026-09-20-word-trail-flat-design.md`, mock
  `docs/brainstorm/concepts.html#wordtrail`). Drag orthogonally through a
  field of letters; every open tile belongs to exactly one hidden word and
  the lengths under the field are the only clue. Only a **right** word
  locks, so nothing wrong can sit on the board and there is no Check --
  which, with no tray, leaves the tip card alone in its bottom slot at 140
  and Reset up in the top bar. **It is called Word Trail and nothing else**,
  in code, in a comment or on screen: LinkedIn ships this game under its own
  name, which the design docs record once each, in order to forbid it, and
  which nothing else may repeat. This is
  the third time the repo has renamed a game it did not invent (Code Break,
  Hidden Word). The wave is its
  motion, and it needed nothing new from `core/motion.gd`: the ribbon takes
  the word's colour from its first tile to its last at `WAVE_STEP` a tile,
  `_front(i, t)` is the one truth four things read (which tile wears the
  colour, how far the ribbon is drawn, which slot box is lit, which letter
  has arrived), and Undo and Reset run the same wave backwards. Its only two
  motion constants are `WAVE_STEP` and `BEAM_TIME`. Its band is Hidden
  Word's, appended to the board's own builder rather than mounted as a
  `Scenery` node, so it is one draw call. Measured on this Mac with
  `tests/_shot_anim.gd -- wordtrail` at `--resolution 810x1440`, 2026-09-20:
  **65, 62, 65** draw calls over three runs with one word locked (the 62 is
  the outlier of the three; the likely cause, inferred from the timings and
  not measured, is the lock's ring and sparkles dying just as the idle
  window opens), **60/61** bare, **61/61** under reduce motion, and idles of
  2.51/2.49/2.51, 2.40/2.39 and 2.40/2.37 ms. Queens (71, 71) and Hidden
  Word (110, 110) were run as controls in the same session and came back
  exactly as recorded above, which is what makes those figures worth
  quoting. On the phone's driver (`--rendering-driver opengl3_angle`): the
  same **65** twice, and the settled frame matches the default driver to
  5/255 on four pixels -- edge antialiasing, no `instance uniform`. The
  reduce-motion pair 1.5 s apart is pixel-identical again.
- **Bridges is the first board whose field is not paper** (2026-09-20,
  `puzzles/bridges2d.gd`, spec `2026-09-20-bridges-flat-design.md`, mock
  `docs/brainstorm/concepts.html#bridges`). Islets with numbers, 0 to 3
  planks between facing pairs, no two runs crossing, and **every islet in one
  single network** at the end. **It is called Bridges and nothing else**, in
  code, in a comment or on screen: it is Hashiwokakero, and the reference it
  was designed from ships it under a third name; the spec records both once
  in order to forbid them. That is the fourth rename after Code Break, Hidden
  Word and Word Trail.
  **The sea taught the set something.** It was first drawn in `Pal.WATER` and
  was the loudest surface in the game; it is now
  `mix(WATER_HI, PAPER, 0.46)`, and letting the blue down into *paper* rather
  than into a sky colour is what keeps it warm. Two things invert on a pale
  ground -- the ripples are darker than the water and the shallow band is
  paler than the open water -- and the beach had to move from `STONE` (value
  237 against a 230 sea, so the islets stopped reading at all) to `ACORN`.
  **A warm-ink alpha tuned against a dark ground is not portable to a light
  one, in either direction**: three of five re-tunes were reversals, and the
  pale sea *deleted* the special case where `BAD` over deep water came back
  mauve and had to be drawn opaque.
  **The generator grows the answer and then proves it.** Range propagation
  plus a group rule with **two** halves, and the second is load-bearing: a
  group with no still-open lane out is a contradiction, and a group with
  exactly one **must take it**. Drop the forcing half and the guess-free
  rates collapse. The GDScript solver and the mock's JavaScript one agree to
  within two points on attempts, second-answer rejection and guess-free rate
  across all three bands, and both were cross-checked against brute-force
  counters -- which is a better statement about the proof than either alone.
  Worst case 47 ms against the 194 ms gate.
  **`is_solved()` is every rule at once and never a subset** -- every number
  met, no two runs crossing, and one single network. The crossing clause is a
  backstop (`cycle()` refuses a crossed lane) and it was added on 2026-09-20
  with the bug that made it reachable: `hint()` lifted only the **first** lane
  blocking the plank it wanted, and a lane can be blocked by several, so a
  hint could leave two runs crossing with both frozen. A hint now lifts every
  blocker, and costs one undo per blocker plus one. The near-miss
  -- every number met, the islets in two rings -- is **unsignposted by
  decision**. Check is the only door and it costs a check, which is why
  **Check's marks flash and then hold until the next move** rather than
  fading as Nonogram's do: a paid-for answer is kept, and a reduce-motion
  player, who is drawn no flash at all, is shown something.
  Measured with `tests/_shot_anim.gd -- bridges` at `--resolution 810x1440`:
  **64 bare, 64-65 played**, against the 855 budget, with Word Trail (65, 65)
  and Queens (71, 71) both reproducing their recorded counts as controls in
  the same session. Idle read 3.11 to 4.22 ms over eight runs -- but Word
  Trail's idle came back 20-40% above *its* record in that same session, so
  **the counts from it are trustworthy and the milliseconds are comparable
  only within it**. ANGLE agrees on 65 and matches to 4/255 on the sea's
  gradient rounding; the one three-figure difference is the shared wordmark's
  sun-dot, whose glint is on its own clock and differs that much between two
  runs of the *same* driver.
  **It cannot merge before a pager does.** `ui/menu.gd:139` loops the whole
  registry with no cap, so a thirteenth entry makes a fifth row and pushes
  the bottom bar off the screen -- the menu reads 313 draw calls against 322
  because the bar has left. Nothing on the board is wrong; the symptom just
  looks nothing like its cause.
- **A long title or motto is lettered smaller, never larger**
  (`ui/flat/flat_top_bar.gd`, 2026-09-20). The title block is whatever the
  buttons leave -- 496 with four, 370 with five -- and `Word Trail` measures
  391 at GameWordmark 84, so it used to run out under Undo and Reset, as
  Balance's and Untangle's mottos had since 2026-09-18. `_fit_title`
  measures the rendered face (`Font.get_string_size`, which carries the
  variation's letter spacing) against the block on every resize and takes a
  `font_size` override when it does not fit, removing the override when it
  does. **`floor(base * wide / want)` is the seed of that override and not
  the answer**: advance widths are not linear in the font size, so the
  linear guess can still overflow -- Balance's motto guesses 22 and the face
  at 22 measures 372 against a 370 block -- and `_fit` steps down from the
  guess (never from `base`, which is up to 60 measurements for a long title)
  until the rendered face actually fits. Measured across all twelve screens
  with a headless probe on 2026-09-20: exactly four labels are lettered
  smaller -- Balance's motto (24 to 21), Untangle's (24 to 22) and Word
  Trail's title (84 to 79) and motto (24 to 21) -- and every other label is
  untouched to the pixel, Hidden Word's 481-wide title included: its bar
  builds five buttons but `refresh()` hides Undo, so the block it measures
  against is 496 and it stays at 84.
- **A card that moves inside a container needs a slot.** A container writes
  its children's positions on every sort, so a child that tweens its own
  position (a shiver, a hop) fights it and loses; give the container a plain
  slot and let the card move inside that. Balance's weight cards learned it
  the hard way on 2026-09-18: a refused minus threw the card under the first
  one, and the player saw it vanish.
- **The flat screen breaks the sign rule on purpose.** Its title is a `Label`
  in ink (`Wordmark2D`) with the leaf drawn over it, not the carved sign, and
  it has no How to play card, working-line card or motto footer: a tip card
  with a sprout names the rule a tap just broke and opens the rules sheet.
  Nothing else may drop the sign; this screen is the experiment.
- **The rules live in a scene-free state class** the flat board draws
  (`puzzles/binairo_state.gd`, `puzzles/codebreak_state.gd`), and they are
  the island's move for move, so what was on trial was the screen and not
  the game. The island scripts in `legacy/` still carry their own copy,
  frozen; the state class is the one truth to keep.
- **Faces are code, not images** (`ui/faces/`): one Control per character,
  drawn from a few tweened properties (`expression`, `eye_open`, `spin`,
  `rock`) as one cached `ArrayMesh` per layer, because gl_compatibility pays
  per draw command. `radius_ratio` fixes R as a fraction of the rect and
  `plain` drops the face for a silhouette; `ui/faces/friends.gd` is the one
  list of Code Break's seven. Filled polygons get an antialiased feather in
  their own colour; MSAA for the 2D canvas stays off.
- **Code Break's score is a count and never a map.** Nothing on that screen
  may suggest which seat a pip came from -- not the pips' arrangement, not
  their colour, not a face, not the order things animate in. That is why the
  pouch is a loose pile with no socket for a miss, and why a checked row
  wears one expression rather than one per seat.
- **The flat host still hides the stage** (`Stage.visible = false` and
  `show_setting(false)`) while it is up, under an opaque paper page, and
  shows it again on exit. Since 2026-09-18 there is usually no stage there
  to hide -- it is mounted only for something opened from More -- and the
  guard stays because a flat board opened over one has to cover it.
- **The registry picks the shell**: `Registry.shell(entry)` is "island"
  unless the entry says `"shell": "flat"`; `ui/menu.gd` builds the flat host
  and `legacy/ui/island_host.gd` is the other, and both fill
  `ui/puzzle_host.gd`'s `_build_chrome` and `_enter`. The base has no rows
  of its own and errors rather than falling back. It picks the tray too
  (`"tray": "friends"`, `"weights"`, `"tiles"`, `"queens"`, `"keys"`), because
  the host lays out its rows
  before it has a puzzle to ask how many chips it wants -- and it can drop
  the actions row with `"actions": false`, which Balance does: that board is
  its own continuous check, so it has no Check to put in the row and Reset
  rides up into the top bar instead. It can drop the tip card too
  (`"tip": false`), which **Hidden Word** is the first board to do: the
  keyboard fills the space a tip card would sit in, and the screen has no
  room for both. This also leaves Hidden Word with no route to the rules
  sheet, since the tip card was every other board's only door to it -- see
  above. Hidden Word drops the actions row as well -- there is no Check on a
  board where a commit is the check, and no Undo, because the commit is the
  one irreversible move any flat board has. The flat host therefore measures
  its bottom slot from the rows it actually built, not from a constant; the
  twelve screens want 460, 460, 390, 290, 140, 290, 290, 290, 460, 460, 340
  and 140 -- Untangle drops the tray *and* the actions row, so its slot is
  the tip card alone, Hidden Word's is the keyboard alone
  (`ui/flat/key_board.gd`'s `HEIGHT`), and **Word Trail** is Untangle's
  shape again: it picks nothing up and there is no Check, because only a
  right word locks, so its slot is the tip card alone at 140 and Reset rides
  up into the top bar. Three boards now carry five buttons up there
  (Balance, Untangle, Word Trail); Hidden Word builds five and shows four,
  because its `capabilities()` has no Undo.
- **What the flat chrome asks a board for is optional and defaulted**:
  `palette()`, `weights()` (the weight cards' rows), `tip_line()` (the
  sprout's own line, in place of Binairo's cycle of rules), `flat_win()` (the
  characters of the answer, laid across the win screen in place of the sun
  and the moon, optionally each with a label under it), `win_delay()` and
  `card_height(available)` (a board that wants less of the slot than it was
  given: Balance caps its scale bands, and the leftover becomes air *above*
  the weight cards, because a gap under the day card reads as a mistake and a
  gap above the cards reads as room) and `card_centred()` (where that
  leftover goes: Tents, Light Up, One Line, Nonogram and Queens halve it,
  because their grid is square -- or, on One Line, wider than it is tall --
  while their space is tall, so the cell is capped by the width and there is slack
  however the card is cut; One Line's medium lattice is 4x3 and leaves 432 of a 1190 slot, the
  widest air of the eight and a call its spec's section 10 records rather than
  hides). A board that offers none gets Binairo's behaviour. Hidden Word
  answers `true` to `card_centred()` and **the answer does nothing on this
  phone**: five tiles across six rows is taller than it is wide, so height
  binds and the slack is zero -- measured at three slot sizes on 2026-09-19,
  `card_height()` hands back every pixel it is given (1140 of 1140, 1190 of
  1190, 900 of 900), so there is nothing to halve at any of them. It says
  `true` because on a squarer screen
  the width would bind instead; nobody should read a centring on the phone
  into it.
- **The flat cast is a shared drawing, and two screens already share one.**
  `ui/faces/friends.gd` is Code Break's seven and `ui/faces/fruit.gd` is
  Balance's five, and the apple in the second *is* the berry in the first --
  one class, one mesh cache, named differently by each screen because the
  mocks drew the same round red fruit twice. Light Up's lamp
  (`ui/faces/court_lantern.gd`) is the third: it is Untangle's paper lantern
  subclassed, with the cord and tassel off it and an iron foot under it, so it
  shares the parent's seat, halo and mesh cache. Check `ui/faces/` before
  drawing a new character -- in twelve screens two have earned one: One Line's
  walker (`ui/faces/snail_face.gd`), because nothing else in the cast walks
  anywhere and its trail *is* the mechanic, and Queens' bee
  (`ui/faces/bee_face.gd`), because nothing in the cast is a queen and the
  bee is the one thing that board seats. Nonogram went the other way and
  drew **no** character at all: its
  pieces are tiles and its clues are numbers, so the only face on the screen
  is the sprout's, and `ui/faces/mosaic_tile.gd` is builder shapes rather than
  a Control -- eighty-one of them go into one mesh. Hidden Word went the same
  way and added nothing to `ui/faces/`: its thirty tiles are Nonogram's
  mosaic tile, taught to carry a letter and nothing else, and the only face
  it shows is the shared sprout, which comes on stage once, for the reveal.
  Word Trail is the third to add nothing: its letter tiles are that same
  mosaic tile, its scenery band borrows `ui/flat/scenery.gd`'s clouds
  (`Scenery.cloud`) into the board's own builder -- the bushes under them are
  the board's own `_bush` -- and the only face on the screen is the sprout on
  the tip card.
- **A canvas command holds a mesh by RID, not by reference.** A board that
  rebuilds a cached `ArrayMesh` every frame and drops the previous one leaves
  the renderer drawing a freed RID -- "Parameter mesh is null", and an empty
  card -- on any frame rendered without its queued redraw flushed first, which
  is exactly what `RenderingServer.force_draw()` does in a harness.
  `lightup2d.gd`, `oneline2d.gd`, `nonogram2d.gd`, `untangle2d.gd`,
  `shikaku2d.gd` and `tents2d.gd` keep the mesh their last `_draw` handed
  over (`_shown`) until the next one replaces it; `word_trail2d.gd` keeps
  three (the still band, the field and the slots), so its `_shown` is an
  Array.
  A harness shooting one of these boards has to let a frame pass between the
  state change and `force_draw()`: `queue_redraw` is flushed on the next idle
  frame, so a probe that pokes the board and shoots in the same frame
  photographs the state before the poke.
- **A board that rebuilds only while it is moving has to ask about every
  wave.** `oneline2d.gd`'s `_animating()` first asked only its posts'
  entrance, and on a figure of twenty lines the lines' own wave outlasts it:
  the last few froze at four fifths of their fade, two pale lines that never
  arrived. It showed on a rendered frame and in no test.

## Art: shading direction

The look everything aims for is in `docs/art/shading-direction.md`: soft
painted cel, no harsh black outlines, warm muted pastels, diffuse and
painterly surfaces, soft coloured shadows, minimal specular, depth through
colour rather than fog. Read it before touching a shader, palette or light.

Every lit material is on it (2026-09-17), through `legacy/core/toon.gd`: the eased
ramp, the eased sky rim and the painterly wash come with `Toon.material()`
and its variants, and a shell wears the layer's own colour's line. Two rules
keep it that way: set a mesh's material *before* `Toon.add_outline`, which
reads the colour off it, and call `Toon.reline` after any recolour that
does not go through `Models.tint` or `tint_named`. Nothing may hand a layer
the shared ink `Toon.outline()` or a hard ramp again.

The HUD's paper takes the same wash through `CozyTheme.dress()`, installed
once by `world/main.gd` before any screen builds: every Button, Panel and
PanelContainer that enters the tree without a material gets the one shared
paper material (`shaders/paper_2d.gdshader`, measured in screen space), so
a new widget needs nothing. A widget that wants another surface sets its
own material and keeps it, the way the wood trays do. Harnesses that build
a screen without `main.tscn` show the faces flat; that is the harness, not
a regression.

## Playing on an Android phone

The game ships as a native APK through Firebase App Distribution (project
`daily-games-420bf`, package `com.peeplet.daily`). Run `tools/deploy_android.sh`
to export and distribute; the build lands in the Firebase App Tester app on
the phone. Nothing deploys on push.

The export is the non-gradle (prebuilt template) path, arm64-v8a only,
debug-signed. Machine-local setup it depends on: the Android SDK at
`/opt/homebrew/share/android-commandlinetools` and `~/.android/debug.keystore`,
both wired into Godot's editor settings, plus the 4.7 Android export
templates. `build/` is ignored -- it is output.

## Analytics

Gameplay events go to Firebase (project `daily-games-420bf`) over the GA4
Measurement Protocol, in `core/analytics.gd`. No native SDK, so the Android
export stays on the non-gradle path.

- **Nothing sends unless `Analytics.start()` runs**, and only `world/main.gd`
  calls it. Tests and harnesses build the same screens and stay silent; keep
  it that way rather than making this an autoload.
- The API secret lives in `analytics_secret.cfg` beside `project.godot`:
  untracked, packed by the preset's `include_filter`, overridable with
  `GA_API_SECRET`. Missing secret means the game runs untracked, not broken.
- Events: `game_open`, `puzzle_start`, `puzzle_complete`, `puzzle_abandon`,
  `hint_used`, `undo_used`, `check_used`, `board_reset`, `rules_opened`,
  `new_puzzle`, `reduce_motion`, and on a board that can be turned,
  `view_turn` and `peek_used`. A daily turn adds `turn_lock`, `turn_reveal`,
  `turn_share` and `crowd_reveal_opened`. Board events carry puzzle_id,
  difficulty, day, seconds, moves, hints, checks; the last two tell us
  whether Pipes' third dimension is a puzzle or a nuisance.
- **`puzzle_complete` carries a `solved` boolean**, added when Hidden Word
  landed (2026-09-19): until then `done` implied solved, so the event had
  nothing to say either way. Hidden Word can run out of rows
  (`PuzzleBase.finish_unsolved`) without solving, and that ending fires
  `puzzle_complete` with `solved: false` from `ui/puzzle_host.gd`'s
  `_on_ended` -- a lost board is still a terminal event, and without one a
  player who reads six rows and backs out looks identical to a crash. Every
  other board only ever sends `solved: true`, from `_on_solved`.
- **`locale` rides on every event**, stamped by `Analytics.track()` beside
  `session_id` and `engagement_time_msec` on whatever it is handed, so any
  event can be split by language without a caller remembering to pass it.
- To debug the wiring: `Analytics.validate = true` posts to GA4's validation
  endpoint and prints the verdict instead of recording; `Analytics.debug_mode`
  puts events in the console's DebugView.
- `tools/analytics_secret.sh <secret>` installs the secret in both places that
  need it (the untracked file and the `ANALYTICS_API_SECRET` repo secret) and
  then sends one DebugView-tagged event, so the wiring is visible rather than
  assumed. GA4's collect endpoint answers 204 to everything, so DebugView is
  the only proof a secret actually works.

## Turns and the backend

A **turn** is one committed input a day, an immediate reveal and a graded
result -- never a pass or a fail. Turns sit on the camp grid as cards beside
the boards (`ui/registry.gd` says `"kind": "turn"`), and cost a
`legacy/core/turn_base.gd` subclass plus a registry line, the way a puzzle costs a
`PuzzleBase3D`. Both stand on `legacy/core/stage_view.gd`, which owns the stage
mounting, the camera fit and the picking maths; `PuzzleBase` extends it too,
because GDScript is single-inheritance.

**The live project is `daily-games-420bf`** (provisioned 2026-09-17; it
replaced `peeplet-daily`, which now holds nothing this game uses). Firestore
is a `nam5` multi-region database with the rules from `server/` released,
anonymous sign-in is on, and `core/backend.gd`'s `API_KEY` is the project's
Web app key. The project is on Blaze and the three functions are deployed in
`us-central1` (`tools/deploy_functions.sh`), with their schedules enabled and
a one-day cleanup policy on their container images. Everything below was
verified against the local emulator suite first, then against the live
project.

**The project lives in a Google Cloud organisation with the "secure by
default" policies on**, and three of them bite anything that provisions it:
no service-account keys (`iam.disableServiceAccountKeyCreation`), no members
from other domains (`iam.allowedPolicyMemberDomains`, so a navlio account
cannot own the project and billing is attached from the hypertradeworx side),
and no automatic roles for default service accounts
(`iam.automaticIamGrantsForDefaultServiceAccounts`, so a fresh project's
functions cannot even build). Two one-time scripts hold the answers and are
safe to re-run: `tools/ci_identity.sh` (keyless CI sign-in for App
Distribution) and `tools/functions_identity.sh` (build and Firestore roles
for the functions' identity) and `tools/public_invoker.sh` (the domain
restriction also rejects `allUsers`, so `firebase deploy` leaves `submitTurn`
with no invoker and every call answers 403 from Cloud Run; this overrides the
constraint on this project alone and grants the invoker). All three grant
roles or change policy, so a person runs them, not an agent session. Billing
is the navlio account `013342-E2B1D4-0E3351`.

`core/backend.gd` is the only way out of the game. It is static and woken by
`world/main.gd` alone, exactly like `Analytics` -- **unstarted means offline**,
which is how the suite and the harnesses build these screens without touching
the network, and why neither is an autoload.

- Identity is **Firebase Auth anonymous** over the Identity Toolkit REST API,
  not an install id: a security rule cannot verify an unsigned id, and the
  leaderboard is coming. It upgrades in place to a real account later.
- Reads go straight to **Firestore's REST API**; writes go to one Cloud
  Function. Every document a client reads carries a **single `json` field**,
  which is what keeps Firestore's typed values from becoming a decoder.
- There is **no percentile endpoint**: the tally ships the 101-bucket
  histogram and `Backend.percentile()` does the arithmetic on the device.
  Instant reveal, works offline, and "the number moves if you come back" is
  just a second read.
- A submit is queued to disk before it is sent and flushed on the next
  launch. The server keys on uid, day and game, so a double flush is
  harmless. Nothing waits on the network, and in particular **nothing blocks
  Lock**. `submitTurn` itself only accepts a submit dated today or yesterday
  in UTC -- yesterday stays open so the offline queue can still flush after
  the day rolls over mid-queue.
- Server lives in `server/` (Cloud Functions v2, TypeScript, Node 22).
  `tools/deploy_functions.sh` deploys the functions and the rules; it is not
  in CI yet, and it has not been run against `peeplet-daily` for the reason
  above. `server/.gdignore` keeps Godot out of `node_modules`.
- `tools/_backend_probe.gd` drives the whole path against the emulator suite
  and prints what came back. It is a harness, not a suite entry.

Running the emulator suite locally has three traps worth knowing before you
lose an hour to them. The Firestore emulator needs **JDK 21+**; the `java` on
this Mac's `PATH` is Homebrew's 17, and firebase-tools refuses to start
against it, so every emulator command runs prefixed with
`PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`. The suite itself is started
`--project demo-peeplet` -- the `demo-` prefix is what forces the emulator
into fully offline mode with no real credentials touched -- which is why
`core/backend.gd` reads a `FIREBASE_PROJECT` environment override alongside
`FIREBASE_EMULATOR`, rather than hardcoding the project id it addresses.
And **`firebase functions:shell` cannot invoke a v2 `onSchedule` function** in
CLI 15.14.0: it prints "Successfully invoked function" and does nothing. To
trigger `publishDay` or `rollupTally` by hand, wrap the body in a temporary
`onRequest` function and curl it, or write to Firestore directly over the
emulator's REST API; this has already cost two implementers an afternoon
each. Against the live project, `tools/seed_turn_day.sh <game> <day> <json>`
writes one day's document the way `publishDay` would (create-only), for the
day a game ships on, which the 03:00 scheduler never reaches. How Big?'s
first two days (2026-09-17 and -18) were seeded this way.

**How Big?** (`legacy/turns/how_big.gd`, phase 1) is the first real turn, and it
**went to legacy with the rest of the 3D on 2026-09-18**: it is a scout on a
dock and a silhouetted model, so it could not stay on a flat first screen.
The turn flow, the backend, the histogram reveal and the seeded days all
still work, behind More; phase 1 is parked until the turn is redrawn flat.
It
replaced the Guess stub outright. The scout stands on a dock at a stated
height and the day's thing from the model set stands beside him as a black
silhouette (`Models.silhouette`, flat `Toon.ink`, no outline), so the player
sizes a shape and the reveal has the painted model to show; the finger
holds the thing's top (the turn overrides `_gui_input` and meets the touch
ray with the thing's frontal plane, because StageView drops any ray that
misses the ground plane and at 7 degrees the top half of the screen is sky).
The camera never moves: every item in the table fits four scout heights, so
the roadmap's pull-back was dropped along with the oak. `content/how_big.json`
is the one table -- the server's `npm run build` copies it into
`server/functions/src/`, gitignored there, so the two sides cannot drift --
and both pick the day's item by `fnv1a("how_big|<day>") % items`. A
published day names `item` and `metres`, and the published height wins, which
is how a day gets hand-picked. `TurnBase.result_text()` is the one line the
host's reveal panel shows under the score. The grade is symmetric in the log
ratio: within 6 percent is 100, a factor of five is 0.

`core/locale.gd` picks between `en`, `pt` and `es` and does the number
formatting `TranslationServer` does not. Only the turn flow's strings are
keyed (`locale/turn.csv`); the twelve boards are still hardcoded English, and
`HOWBIG_BLURB` is sitting in the CSV unwired, ready for whenever the registry's
own blurbs get keyed. Upper-case accented capitals turned out to be fine:
`ÁÉÍÓÚ` and `ÃÕÇÑ` both extrude cleanly at weight 700 (18,024 and 21,228
faces, in the same 3,600-5,600-faces-per-glyph range as `GUESS` at 22,356) --
the only glyphs that need the weight dropped to 550 are digits 8 and 9. That
was measured once with a throwaway probe; there is no need to re-run it for
a new accented title.

Roadmap: `docs/brainstorm/single-turn-roadmap.md`. Phase 0's design:
`docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md`.

## CI

`.github/workflows/android.yml` runs on push to `main` (and on demand from the
Actions tab): tests, then the APK, then Firebase App Distribution. The suite
gates it -- the job stops on a non-zero failure count before anything reaches
a phone. Each run stamps `version/code` with the run number so two builds are
never the same version.

Two repo secrets feed it, and the build says so when one is missing:

- `ANDROID_DEBUG_KEYSTORE` -- base64 of `~/.android/debug.keystore`. It must
  be *that* key: Android will not install a build over one signed differently.
- `ANALYTICS_API_SECRET` -- the GA4 Measurement Protocol secret. Absent, the
  build warns and reports nothing.

App Distribution itself needs no secret. The organisation the Firebase project
sits in forbids service-account keys, so the run signs in to Google keylessly
(Workload Identity Federation): the job's `id-token` is exchanged for the
`app-distribution` service account through the `github` identity pool, and
only runs from this repository are allowed to. `tools/ci_identity.sh` is the
one-time setup on the Google side; a failed sign-in fails the job rather than
warning, because there is no longer a missing secret to excuse it.

CI gets its Android SDK path into Godot by appending to the editor settings
file that `--import` generates, rather than writing one by hand; the appended
keys win over the defaults above them.
