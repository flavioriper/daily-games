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

Materials are brought over one at a time; the rest still wear the original
cel look (hard bands, the shared dark outline) until their turn.

- **Wood** (2026-09-16), in three dimensions and in the HUD. The mechanism
  the next material reuses lives in `core/toon.gd`: `soft_ramp()` for eased
  bands, `line()` for an outline shell in the layer's own deepened colour at
  the thinner line width, and the include's `rim_soft` uniform for an eased,
  sky-tinted rim. The grain itself (`toon_lit.gdshaderinc`) draws its
  streaks, zones and knots as tints with a brush-soft edge over a slow
  warm-to-cool wash. Palette hexes were left alone: ten exported models
  carry them as their wood key. The HUD's wood (`wood_grain_2d.gdshader`,
  since 2026-09-16) is a sawn plank rather than a log's face: straight grain
  along the panel and a few dark splits tapering to points, each with a lit
  lower lip, over the same wash. Signs and trays are boards; the stage's
  posts and frames are logs. The signs (the wordmark plaque, the day card)
  are also *cut* by that shader rather than by a StyleBox: the panel hands
  its size over as an instance uniform (`CozyTheme.plank()`), and the shader
  carves a hewn silhouette from a signed distance field, the edge wandering
  in slow lobes and fine nicks with a chamfer knocked off each corner. No
  line is drawn round it (2026-09-16: the painted grain carries the edge on
  its own); a lit lip where the edge faces up and a soft shade where it
  faces down give the board its thickness. The trays keep their rounded
  StyleBox shape; the cut is opt-in.
- **Leaf** (2026-09-16). The palette's leaf greens (`LEAF`, `LEAF_LIGHT`)
  take the same eased ramp and sky-tinted rim as wood, without the grain,
  through `Toon.soft_material`; `Toon.material_for` routes them there by
  colour the way it routes wood. A crown built from leaf cards (the oak,
  brought over from the peeplet project's geometry) stays `_flat`, so it
  wears no shell, and keeps its baked smooth-proxy normals so the band
  reads across the whole crown rather than card by card.
