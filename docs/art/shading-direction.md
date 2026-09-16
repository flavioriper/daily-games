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
  sky-tinted rim. The grain itself (`toon_lit.gdshaderinc`,
  `wood_grain_2d.gdshader`) draws its streaks, zones and knots as tints with
  a brush-soft edge over a slow warm-to-cool wash. Palette hexes were left
  alone: ten exported models carry them as their wood key.
