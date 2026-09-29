# Marigold

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Marigold is the twenty-sixth card** (2026-09-26,
  `puzzles/marigold2d.gd`, `puzzles/marigold_state.gd`, spec
  `2026-09-26-marigold-flat-design.md`, no concept tab -- built while the
  user was away). The pegs-and-launcher game the user asked for, re-dressed
  as a dusk pond garden: the family's sun shoots a seed, every bud it touches
  blooms, bloom every marigold; clovers split the seed, the violet moves, a
  seed in the sliding pot comes back, and the last marigold is a **full
  bloom** (slow motion, a rainbow, five worth-labelled pots). The reference's
  name is written once in the spec to forbid it; **it is called Marigold**.
  Out of seeds the same garden grows back (a try, never a loss). Two things
  travel: **a board whose physics is pure data stepped at a fixed `DT` gets
  an exact guide and an exact hint for free** -- both play the shot on a
  `clone()`, and the hint's 65-angle search (~330 ms here) runs on a
  `WorkerThreadPool` task -- and **`seed` is a global function in GDScript**,
  so a static helper named `seed()` fails to parse where it is called
  (`marigold_parts.gd`'s is `bead()`). Buds are drawn in six strips so a
  bloom rebuilds one. 74 draw calls bare, 76-78 played, 87 in the full
  bloom, 78 on ANGLE. Sixteen sounds generated (2026-09-26), one take a cue,
  awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's amendment): leaf-collared buds, a
  kernel seed that points along its flight, the pond's reflections and a
  moon's road, a garland and lanterns on the arch, a wooden seed trough, pip
  groove and tag; ripples round every bloom, each marigold flying up to its
  pip, picked blooms rising, the sun's recoil, the pot's wobble and catch
  squash, the tag's pop, a rolling score, fireflies and a full bloom of
  falling petals, carried by two small live meshes. 78 bare, 83 played, 91
  in the full bloom, ANGLE agreeing.
  **The last marigold since 2026-09-27** (the spec's second amendment): a
  seed heading for it slows the garden and zooms in under a drumroll, a
  near miss says so, and the hit slams to x0.15 at 2.1x zoom, easing out
  while the seed falls, under Ode to Joy arranged in the house instruments.
  The arrangement is synthesised by `tools/gen_marigold_music.py`, the one
  sound in the game not made by ElevenLabs, because the tune has to be
  exact. The view is `_cam`; the HUD never goes through it. 91 in the full
  bloom, unchanged.
  **Rewards made loud on 2026-09-27** (the spec's third amendment):
  Stackwood's sticker and bits kit -- petals, sparks and stars off every
  bloom, a bloom counter under the sun, hopping words by blooms in a shot
  (Nice! to Legendary!), Double!/Triple!/Bouquet!, Points xN!, Caught! with
  the seed flying back to the trough, the shot's points lettered and the
  score kicking, a warm edge glow on a long shot, FULL BLOOM and Jackpot!
  as stickers with coin rain. Stickers are in the card's pixels, never the
  view's. 78 at rest, ~159 at a long shot's peak (+2.6 ms here), ANGLE
  agreeing.
