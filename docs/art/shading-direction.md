# Shading direction

The look every board, model, shader, palette and light rig aims for: a soft
painted cel style. Read this before touching any of them. Set on 2026-09-16.

- **Soft cel shading.** Clear light/shadow separation, but without harsh
  black outlines.
- **Warm, pastel colours.** Slightly muted greens, creams, browns, blues,
  oranges.
- **Diffuse materials.** Objects look painted rather than glossy or plastic.
- **Soft ambient lighting.** Lots of gentle bounced light and ambient
  occlusion.
- **Subtle shadows.** Shadows are usually soft and coloured rather than pure
  black.
- **Hand-painted feel.** Textures have small imperfections and painterly
  colour variation.
- **Strong environmental lighting.** Sunlight, sky colour, fog and the
  surroundings affect the scene.
- **Simple shapes.** Rounded, chunky geometry works particularly well.
- **Minimal specular.** Avoid the shiny "mobile 3D asset" look.
- **Depth through colour.** Distant objects become softer and lighter rather
  than relying entirely on realistic fog.

## Where it stands

Every lit material in the game is on the look (2026-09-17; wood and leaf
led on 2026-09-16, the rest followed in one step). The mechanism lives in
`core/toon.gd` and `shaders/toon_lit.gdshaderinc`, and every material comes
out of it the same way. Nothing may reintroduce the hard three-step ramp or
the shared ink line on a layer that has a colour.

- **The ramp is eased** (`Toon.ramp()`): three bands, each edge eased over
  a short run, so light and shadow stay clear and the terminator is soft.
  `water.gdshader` and `pipe_flow.gdshader` carry their own `light()` and
  ease their one terminator over the same run, so a board's shadow falls on
  the pond and the tube as a soft coloured one.
- **The line is the layer's own colour** (`Toon.line()`, `Toon.line_color()`):
  deepened and cooled a little, and thinner than the ink line the cel look
  started with. `Toon.add_outline` reads the colour off the material the
  mesh wears when the shell is added (`Toon.line_for`), so the material is
  set first; every recolouring path (`Models.tint`, `Models.tint_named`, a
  board's own repaint) calls `Toon.reline` afterwards, so a stone tile
  turned slate wears a slate line. `Toon.outline()`, the shared ink, is only
  the fallback for a shell on a layer whose colour cannot be read.
- **The rim is eased and sky-tinted** (`rim_soft`, `rim_color` = `SKY_TOP`)
  on every material, a little stronger on wood so a sawn edge catches light.
- **A painterly wash** (`paint_wash` in the include, on every material but
  wood): a slow drift of the colour between a warmer and a cooler tint of
  itself, with a finer drift in value under it, from two octaves of value
  noise over world position. A few percent at most, and a multiply on the
  colour, so the palette stays the only colour chosen outright; every tile
  of one colour is its own tone. World space rather than the piece's own so
  a hundred tiles of one mesh do not share one pattern; the paint sliding
  over a piece while it moves is below what the eye picks up at these
  amounts. Measured at 1080x1920 on this Mac against the hard look: Binairo
  4.66 to 4.77 ms idle, Code Break 8.19 to about 8.6 ms, no draw call added.
- **Wood** (2026-09-16), in three dimensions and in the HUD. The grain
  (`toon_lit.gdshaderinc`, under `WOOD_GRAIN`) draws its streaks, zones and
  knots as tints with a brush-soft edge over a slow warm-to-cool wash of its
  own, which is why the plain wash above skips it. Palette hexes were left
  alone: ten exported models carry them as their wood key. The HUD's wood
  (`wood_grain_2d.gdshader`) is a sawn plank rather than a log's face:
  straight grain along the panel and a few dark splits tapering to points,
  each with a lit lower lip, over the same wash. Signs and trays are boards;
  the stage's posts and frames are logs. The signs (the wordmark plaque, the
  day card) are also *cut* by that shader rather than by a StyleBox: the
  panel hands its size over in a material of its own (`CozyTheme.plank()`),
  and the shader carves a hewn silhouette from a signed distance field, the
  edge wandering in slow lobes and fine nicks with a chamfer knocked off
  each corner. No line is drawn round it (the painted grain carries the
  edge on its own); a lit lip where the edge faces up and a soft shade where
  it faces down give the board its thickness. The trays keep their rounded
  StyleBox shape; the cut is opt-in.
- **Leaf** (2026-09-16) was the second material over and needs no routing
  of its own any more. A crown built from leaf cards (the oak, brought over
  from the peeplet project's geometry) stays `_flat`, so it wears no shell,
  and keeps its baked smooth-proxy normals so the band reads across the
  whole crown rather than card by card.

- **Paper** (2026-09-17), the HUD's faces. Every Button, Panel and
  PanelContainer wears `shaders/paper_2d.gdshader` as its material: the same
  wash the pieces carry, over whatever colour the stylebox drew, plus a fine
  paper tooth, so a cream sheet, a slate card and a sun button each take it
  in their own colour and the labels they draw shift by the same few
  percent. It is measured in screen space, so one shared material
  (`CozyTheme.paper()`) serves every face, each showing the patch of paper
  it sits over; `CozyTheme.dress()`, installed once by `world/main.gd`,
  hands it to every face as it enters the tree, and a widget that wants
  another surface (the wood trays, the plank) sets its own material and
  keeps it. Measured at 1080x1920 on Binairo: 4.86 to 5.03 ms idle, no draw
  call added.

Only the backdrop's painted landscape cards stand outside the look, by
design: they are unlit and carry their paint's own variation.

## The first screen's light

The campsite on the menu is lit and coloured to
`docs/art/concept-menu-painted.png` (set 2026-09-17), a painted frame that
replaced the toy-render banner (`concept-menu-banner.png`) as the reference
for *light, palette and density*; the banner still governs the staging. The
frame is dark at every edge and bright only where the camp is, its greens
are forest rather than lime, and no bare ground shows. Boards are untouched:
everything below lives in `Stage.grade_camp`, the camp's own palette
constants and `world/camp.gd`, and `Stage.grade_board` puts every shared
thing back.

- **The grade** (`Stage.grade_camp`, the `CAMP_*` constants in
  `world/stage.gd`). A low golden sun from the right and a little in front
  (`CAMP_SUN_FROM`, about 30 degrees up) over a *dark, cool* bounce
  (`a9b8c4` at 0.075, against the boards' warm cream at 0.115), so every
  prop shows a warm lit side and a deep cool shaded one and casts a long
  shadow to its left. Saturation is no longer pushed (1.02, was 1.18);
  contrast is (1.16) and brightness sits a hair under 1. The sky is a deep
  summer blue over a warm horizon, and the shared water material's pair is
  graded to a deep teal with it. `grade_board` restores the sun's direction,
  the sky pair and the water pair along with the measured light.
- **The camp's palette** (`Pal.CAMP_*`): its turf, its grass blades, its
  path's earth and its leaf are all deeper and cooler than the boards' TURF,
  LEAF and PLOT_SOIL. Trees and bushes on the camp are tinted through
  `tint_named` so their lines follow (`Camp._tree`), and their crowns then go
  over to the wind shader (`Camp._blow`); the grass fields wear
  `Toon.wind_material(Pal.CAMP_GRASS, Toon.SWAY_BLADE)` over the library's
  LEAF.
- **Ground cover** is six MultiMeshes (three grasses, blossom cards, bushes)
  plus one for the leaf sheets closing the tree line. One draw call each, so
  the count costs fill rate and vertices only, never calls. Grown on
  2026-09-17 from 620 tufts over a third of the ground to 5,050 over all of
  it, so no bare turf shows anywhere the camera reaches:
  - **Two grasses**, because the bill is triangles: `grass_patch` is 480 of
    them and `grass_clump` 98, both about 0.4 tall. The patch goes where the
    camera is close -- the hero strip (1,150) and the lawn under the cards
    (1,200) -- and the clump fills the middle ground (2,000) and carries on
    across the river (700), at a fifth of the cost per tuft.
  - **Sow to what the camera sees.** A MultiMesh is culled as one thing and
    never per instance, so a tuft off screen costs its vertices every frame
    and shows nothing. The lawn under the cards *looks* like a wide band and
    is in fact the wedge from (x -2.9..3.4, z 7.9) to (x -0.9..0.9, z 10.5)
    in the camp's space -- eleven square units -- because the shift lens
    looks almost straight down there from (0, 2.7, 10.8). Cast the rig's
    rays at the screen's own pixels and read it off, rather than guessing at
    a range.
  - **A near tuft closes less ground than a far one**, being seen down the
    blade rather than across it, so the near lawn gets the fuller patch mesh
    at near full size rather than more small ones. It is also where the fill
    goes: measured at 1080x1920, three runs each, the near lawn costs
    2.3 ms and 650 tufts cost the same as 1,200, because a few hundred
    blades that close to the lens already cover the screen. Take the fuller
    one; `Camp.NEAR_GRASS` is the lever if a phone drops frames.
  - 130 blossoms, scaled to stand above the grass around them, and 14 bushes
    along the bank and the path.
- **The canopy framing the frame** (`Camp.FRAME_CANOPY`): a trunkless oak
  crown hanging into each top corner from a couple of units in front of the
  lens, in `CAMP_LEAF_DEEP`, casting nothing. Whole trees near enough to
  cut the corner stood their crowns in front of the day sign and the little
  board, which sit within a fifth of the frame's width of its edges.
- **The soft focus** (`shaders/soft_focus.gdshader`) gained a near band and
  a vignette. Nearer than `near_start` the screen blurs and *darkens* (never
  hazes), which is what turns the canopy into the painting's shaded
  foreground. The band is gated to the top of the frame (`near_gate`, set by
  `Stage.fit_camera` to the framed rect's bottom edge): the lawn under the
  cards is as near as the canopy and already takes the vignette.
  The vignette eases toward a deep foliage colour from about one half-width
  out, measured in the frame's own shape so a portrait phone darkens more at
  top and bottom than at the sides. The HUD draws over the pass, so none of
  it reaches the cards.
- **`SCREEN_UV.y` runs top-down in a spatial shader on gl_compatibility**
  (probed 2026-09-17: a gate keyed the other way blackened the bottom and
  left the canopy alone). Anything that gates by screen height keys off
  `SCREEN_UV.y < fraction` for the top.
- **The lantern is lit**: its glass is `Toon.ink(Pal.LAMPLIGHT)`, flat and
  unlit, bright enough to catch the grade's bloom.
- **The camp has weather and boards do not** (added 2026-09-17). Over the
  flutter the sway shader always had, `shaders/wind.gdshaderinc` lays a
  gust: a band travelling across the world along `wind_dir`, one crest every
  13 units, cubed so the lull is long and the crest arrives quickly -- a
  gust crossing a field, not everything waving at once. `toon_wind`,
  `outline` and the new `card_wind` all include that one file, because a
  gust each shader reads differently is a shimmer rather than a wind. It is
  gated on the `wind_gust` global (`world/ambient.gd`), which
  `Stage.show_setting` turns on with the pollen and the grade and
  reduce-motion stills with everything else, so a board's rim grass keeps
  exactly the flutter it was calibrated with.
  - The gust's direction is taken back through each model's own basis, so
    every prop leans the same way in the world however it is turned. The
    flutter never had to: it is a shimmer with no direction to read, and a
    field of tufts each blowing down its own local x reads as chaos.
  - Aimed much further toward the camera it lays the blades down the view,
    which reads as growing rather than bending. `(0.95, 0.31)` -- across the
    frame, the way the path and the river lead the eye -- is what the camp
    wants.
  - What blows: the grass, the blossom and foliage cards, the bushes and
    every tree crown. Trunks never do. A layer's lean is shaped by four
    `sway_*` parameters read in the model's own units, so the prop's scale
    carries them and one shape fits a sapling and the oak alike
    (`Toon.SWAY_BLADE`, `SWAY_CROWN`, `SWAY_BUSH`, `SWAY_CARD`).
  - **A shell must lean by its layer's own shape.** The outline is a second
    instance of the layer's mesh, so a line left on the shader's defaults
    peels off it; `Toon.line_for` reads the sway back off the layer and
    hands it to `wind_line`, which is why nothing has to remember to set it.
  - The cards went from `StandardMaterial3D` to `shaders/card_wind.gdshader`
    (the same Y-billboard and alpha depth pre-pass, written out) so they can
    lean. A billboard has no depth to lean into, so the gust is projected
    onto screen-right before it is applied.

Measured on this Mac at 1080x1920 through `tests/_shot_menu.gd`, which now
prints the idle mean and the peak draw calls: 10.1 ms and 337 calls before,
10.8 to 11.3 ms and 334 after; the difference is fill rate from the denser
cover and the larger sheets. The grass and wind pass of 2026-09-17 took that
to about 13 ms and 329 calls -- 2.3 ms of it the lawn under the cards, the
rest the wider fields -- all of it fill and vertices, none of it draw calls.
The ANGLE driver draws the same frame. What
this pass does not do, by scope: the set (a cliff over a sea), the camera's
pose, the lettering, per-layer textures, and the card dioramas, which keep
the board light and read brighter than the camp behind them.
