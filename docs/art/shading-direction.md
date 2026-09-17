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
