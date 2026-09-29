# Hedgehogs

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Hedgehogs is the twenty-fourth card** (2026-09-26,
  `puzzles/hedgehogs2d.gd`, spec `2026-09-26-hedgehogs-flat-design.md`, mock
  `docs/brainstorm/concepts.html#hedgehogs`). Rake an autumn lawn's leaf
  piles; a number counts the hedgehogs asleep in the eight cells round it,
  a nought blows its neighbours clear, and a wrong rake only wakes one up
  grumpy (`woken`, on the win screen and the share line). It is the
  dig-and-flag game Mushroom Patch was drawn *away* from, off the same
  reference; **it is called Hedgehogs**. Two things travel: **a proof that
  plays the day out from its opening is also its uniqueness** --
  `hedgehogs_gen.gd`'s `prove` rakes every bare cell by singles, subsets and
  the count, never guessing, so no separate second-answer search is asked --
  and **a board whose moves all resolve in the state at once needs no input
  lock**: every cell carries its own gust timers, so a tap mid-gust is taken
  and the drawing still lands on the state. Its drawings are
  `ui/faces/leaf_pile.gd` (shared with the tray and the card) and
  `ui/faces/hedgehog_face.gd`. 79 draw calls bare, 80 raked, 83 with one
  woken and 115 on the win wave, ANGLE agreeing.
  Sounds generated (2026-09-26), one take a cue, awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's section 11): an autumn lawn with a
  wooden bed round the grid, heaped piles of almond, maple and oak leaves, a
  flag that drops in and presses its pile down, a rake pulled across each
  raked cell, leaves that spiral off and settle, wind streaks on a big flood,
  a breeze through one row at a time, a woken hedgehog that peeks, and a win
  where the sleepers stretch, yawn and hop under a swirl of leaves. The
  still mesh is cut into bands of three rows rebuilt only when a cell's look
  changes. 84 bare, 85 played, 119 on the win, ANGLE agreeing.
