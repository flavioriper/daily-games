# The flat boards: one motion, one dressing

Every flat screen moves with the same hand and wears the same cloth. The
flat Binairo (`puzzles/binairo2d.gd`, its spec's section 6) set the hand;
Code Break was the second board to take it, on 2026-09-18, and the vocabulary
was lifted into `core/motion.gd` on that day so a third does not copy it. This
page is the table a new or a ported board is built against. When a number
here and a number in a board disagree, the board is wrong.

## The rules

1. **Everything goes through `core/motion.gd`.** A decorative recipe returns
   `null` under reduce-motion and lands its final state at once; the state
   change itself (a face swapping, a row scoring) is essential and stays,
   shortened to `Motion.REDUCED_TIME`. A board never checks `Motion.reduce`
   to decide *what* happens, only to skip a delay that paced a decoration
   (Code Break's `_beat`).
2. **A mover owns its place until it lands.** Layout code leaves a node
   alone while its tween runs (`Motion.running`), and the recipe's landing
   callback puts it back where the layout would. Otherwise a relayout mid
   flight teleports the piece.
3. **Kill on rebuild.** Every tween a board keeps is stopped in `_stop_all`
   before the nodes it aims at are freed, and a timer is guarded by a
   generation counter (`_after`), so a new board never inherits a hop aimed at
   the last one.
4. **Stagger through `Motion.stagger(i, per, cap)`.** The cap (0.6 by default)
   keeps a big board's wave from outlasting the player's attention.
5. **Particles only through `ui/fx2d.gd`**: `puff` for a placement, `sparkle`
   for a hint or a win, `ring` for the hint's pulse, all in the board's own
   pixels. No board builds its own emitter or its own ring.
6. **One voice.** A number that has to differ for a board goes through a
   recipe's parameter (Code Break's seats nudge 7 where Binairo's tiles nudge
   3) and never through a copied constant. What a board keeps as its own
   constants is what nothing else does: Binairo's blush, Code Break's flight
   and lids.
7. **Square pops from nothing, wide from most of the way.** A tile, a lid or a
   face enters from scale 0.01; a row or a card from `ENTER_WIDE_FROM` (0.86),
   because the back ease's tenth of overshoot on a thousand units of width is
   a wobble, not a spring.

## The moments

Times in seconds, distances in the game's 1080-wide design units. Each row is
a recipe in `core/motion.gd` unless it names another file.

| Moment | What happens | Recipe, numbers |
|---|---|---|
| Entrance | The pieces pop in along the diagonal from the top left (a grid) or down the column (a list), with the back ease; a resident face lands a beat after its tile with the squash. The chrome slides in row by row (`ui/hud/panel.gd`). | `slide` on scale, `ENTER_POP` 0.25, `ENTER_STAGGER` 0.03; face `pop_in` 0.12 later |
| Press | The tile sinks under the finger and springs back on release. Every tappable piece does this, including one that will do nothing when released. | `press`: `PRESS_SCALE` 0.94 in `PRESS_TIME` 0.08, back-ease out `RELEASE_TIME` 0.25 |
| Place | The old piece pops out; the new one pops in with the squash; the tile hops; the side neighbours lean away and back; a puff of five stars in the piece's colour. | `pop_out` `POP_OUT` 0.12; `pop_in` `POP_IN` 0.22 with `POP_SQUASH` 0.15; `hop` `HOP` -6 over `HOP_TIME` 0.3; `nudge` `NUDGE` 3 over 0.3 after `NUDGE_LAG` 0.04; `fx.puff` |
| Remove | The piece shrinks to nothing with a quarter turn, rising a little if the board wants; whatever it hid pops back under it. | `pop_out`, optional `lift`; `pop_in` 0.18 on what returns |
| Hint | A ring pulses out of the cell, the piece drops in from above with the back ease while it fades in, sparkles rise, the cell takes the given look. | `fx.ring` `RING_TIME` 0.5; `drop_in` `DROP` 40 over `DROP_TIME` 0.3; `fx.sparkle` |
| Wrong on Check | Each wrong cell wobbles and flashes toward `Pal.BAD_TILE` and back. | `wobble2d` 0.45; `fade` in `FLASH_IN` 0.15, out `FLASH_OUT` 0.45 |
| Clean Check | The Check pill squashes and says All good for a moment. | `ui/flat/flat_actions.gd` |
| Undo | The reverse of Place. | as Place |
| Reset | Free pieces pop out in a wave from the far corner; givens hop 4. | `pop_out`, `RESET_STAGGER` 0.02 |
| Solved | Every piece hops in a wave with JOY eyes, sparkles across the board, then the host brings the win screen. | `hop` `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4, `SOLVE_STAGGER` 0.04 after `SOLVE_DELAY` 0.25; win after 0.8 or the board's `win_delay()` |
| Palette | A pressed chip squashes, lifts and takes a border in its symbol's colour. On a brush tray (Binairo) that is a mode and it stays; on a direct-action tray (Code Break) it is a beat of feedback and settles after `CHIP_LIT`. | `squash` 0.1 over 0.18; `CHIP_LIFT` 8 over `CHIP_LIFT_TIME` 0.18; `CHIP_LIT` 0.35 |
| Tip | The line fades in and the sprout hops with its new face. | `ui/flat/tip_card.gd`: `appear` 0.25, `hop` -8 over 0.35 |
| Idle | Faces blink at their own 3 to 7 s; suns turn a revolution in 40 s; a third of the moons rock. | `ui/faces/face.gd` |

What is a board's alone stays a board's: Binairo's blush with its two
heartbeats and its focus tint; Code Break's flight from the palette, its dip
under a score, its pips dropping into the pouch, its lids and the code's pop.
A new board may add one signature of its own on top of the table, not
instead of it.

## The dressing

- **Cards**: corner 28, a bottom edge of 6 in `Pal.LINE`. The live thing is
  `Pal.SURFACE`; a resting one (a history row) is `Pal.PARCHMENT` warmed 0.45
  toward `SURFACE` with the edge at `LINE` 0.45, and everything on it a blend
  of the same bigness, so a card sliding between the two states is dressed
  continuously rather than flipped.
- **Tiles and sockets**: corner 18 on a Binairo tile, 0.22 of the piece on a
  Code Break socket, a bottom edge of 4 or 5. No paper wash on anything
  smaller than a card: set `material = null` *after* `add_child`, which is
  when `CozyTheme.dress()` puts it on.
- **Dimming the rest**: sockets to 0.72, dotted rings to 0.55, an unscored
  pouch to 0.6. **The record never dims**: a scored pouch, a placed piece.
- **Faces below about 22 px are silhouettes** (`plain`), because a face there
  is a smudge.
- **Decoration says so**: the sparks beside Code Break's lids, the hearts on
  the menu's day row. Nothing decorative may read as a count of anything.

## Porting a board

1. Read its inline tweens and match each to a row above. Replace the ones
   that match with the recipe, passing the board's own number only where it
   truly differs. Delete the constants the recipes now own.
2. Keep `_stop_all` and its generation counter; add any new tween you keep
   to it.
3. Route every ring, puff and sparkle through `fx`.
4. Shoot it: `tests/_shot_anim.gd -- <id>` for the strip and the idle cost,
   and a throwaway `SceneTree` probe that plays the moments the table names
   and saves a frame of each. Read the frames; a tween that does nothing
   shows in no test.
5. Measure the fullest board's draw calls against the 855 budget and write
   the number in the board's spec.

## Boards on it

| Board | Status |
|---|---|
| Binairo | the source; its press, pop in, pop out, drop, nudge, ring and waves call the recipes (2026-09-18) |
| Code Break | on it (2026-09-18): entrance pop, seat press, flight landing with squash and puff, lit chip, pop-out on send back, flash on an incomplete Check, solve wave, ring and drop through Fx2D. Measured: fullest board 234 draw calls, 3.8 ms idle at 1080 x 1920 on this Mac |
| Balance, Shikaku, Untangle, Tents, Light Up, One Line, Nonogram | still carry their own tweens; port when next touched, by the steps above |
