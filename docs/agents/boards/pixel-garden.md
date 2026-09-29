# Pixel Garden

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Pixel Garden is the twenty-seventh card** (2026-09-27,
  `puzzles/pixel_garden2d.gd`, `puzzles/pixel_garden_state.gd`, spec
  `2026-09-27-pixel-garden-flat-design.md`, no concept tab -- built while the
  user was away, from their mock). Copy a little picture onto a pegboard
  bead for bead: pick a chip, tap a peg or drag a run, tap a bead of the
  chosen colour to lift it; hold the picture to see it big. The pictures are
  **hand-drawn and banked** (`content/pixel_garden.json`, ten a band, 10 to
  16 pegs square, in the nineteen `Pal.PG_BEADS`), never generated, and each
  one's name is a `PG_PIC_*` key. Two things travel: **the kit holds exactly
  the beads the picture needs**, so a misplaced bead is felt as a colour
  running out before its shape is done -- a nudge the player finds -- where
  a counter of correct beads would give the picture away a peg at a time
  (the bar counts beads seated, right or wrong); and **Check rings, never
  tints**, a bead being coloured by index. The chips live in the card beside
  the picture (Quilt's shape): `"tray": "none"`, the actions row is Reset
  and Check. The solve is ironed: a warm band crosses the diagonal, each
  bead's hole closes and the bare pegs fade. Drawing is `ui/faces/bead.gd`,
  shared with the menu card; still beads in bands of four rows. `PG_BANK`
  (debug builds) points a harness at another bank.
  77-78 draw calls with a stroke seated on every band, 101-103 at the iron's
  peak, idle 3.2-3.6 ms; ANGLE agrees on 78 (frames within 1/255) and the
  reduce-motion pair is pixel-identical. 13 sounds generated (2026-09-27),
  one take a cue, awaiting the user's listen.
