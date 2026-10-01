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
- **Polished again on 2026-10-01** (unattended, spec
  `2026-10-01-hedgehogs-polish-design.md`): Hard (3 hearts) and Insane (2)
  can be failed -- a wake costs a heart, out of hearts is dusk and the card.
  **Insane is Sleepwalkers**: every third rake the moon's bell rings and one
  sleeping hedgehog not under a flag steps to a covered pile beside it; the
  two piles rustle alike (never the direction) and wear paw prints. A walk
  is taken only if `Gen.prove_from` still plays the lawn out from what the
  player can see, so whatever the rake order there is never a forced guess
  (`tests/_probe_hh_walk.gd`). **The numbers drawn are `_num_view`, a copy**
  synced after each gesture except one that rang the bell -- read it, not
  `g.num`, or a walk's new counts show before its rustle. No tidy-row reward:
  it would leak that the row's covered piles are hedgehogs. HARVEST sound
  set (unheard). Peak 138 draw calls (party), ANGLE agreeing.
