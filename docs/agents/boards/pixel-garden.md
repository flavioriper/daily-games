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
- **Polish (2026-10-01, unattended, spec
  `2026-10-01-pixel-garden-polish-design.md`).** The board is four plates
  with a seam and clips; a plate full is ironed at once by an iron with a
  face (`ui/faces/iron.gd`): right fuses it for good (`locked` FUSED, a
  hint's is HINTED), wrong sends the beads astray home -- a heart on Hard
  (3) and Insane (2), which have no Check. Only the plate under the iron
  waits; the rest of the board stays live. Insane is **Windblown**: the
  pattern card's squares shuffled and turned (`perm`, `turn`,
  `card_peg`), each framed in its plate's colour with its clip (pips 1-4)
  on the plate's top edge. The chips are a clear compartment box with
  heaps of beads and steel tweezers. Rewards: plate words and streak,
  love hearts or a butterfly, Steady hand!/Whoosh!, the party (nap cat on
  the pattern card, seal). BEADBOX sound set, 26 cues, unheard. Use `_won`,
  never `_solved_at < 0` (a restored day's clock can be negative). Peak 124
  draw calls; `tests/_shot_pixel_garden.gd`, `tests/_probe_pixel_garden.gd`.
  Amended the same day (spec section 11): hairline seams, every bead left
  drawn in its compartment, and a seated bead flies there from the box.
  Then (section 12): a stroke locks to its row or column after 0.7 of a
  cell, and a peg holding another colour refuses a bead (`taken`).
- **Checkup (2026-10-03, `docs/agents/checkup.md` row 27).** Beads, bare
  pegs and the box's beads are copies of `Kit` looks
  (`puzzles/pixel_garden_looks.gd`): one topology a kit, so a layer is
  native copies and tiled indices. `Looks.bead_kit` must stay in step with
  `Bead.bead` by hand (the menu card still draws through `Bead.bead`); a look
  that breaks the topology trips the kit's assert. The board's beads are in
  bands of four rows at rest (`_update_bands`, keyed on colour and fused) and
  one live mesh of the moving ones (`_live_beads`), with Check's halos and a
  hint's dots in `_marks` over both. The head is five meshes (`_head_under`,
  `_head_pick`, `_heaps`, `_head_over`, `_head_lid`). The tutorial is
  `ui/hud/pixel_garden_tutorial_diagram.gd` (lessons SEAT, KIT, PLATE, PEEK,
  WIND, CHECK, UNDO, HINT) on a hand-made 6x6 tulip, five beads a plate; its
  Windblown card is `PERM` [3, 2, 1, 0], `TURN` [1, 2, 3, 1]. Probe flags
  `x=pg_count`, `x=pg_relay`, `x=pg_hud`.
- **The iron waits for a full board (2026-10-04, the user's call).** A plate
  filled on its own is no longer ironed: four irons a picture read as the
  finish playing on every plate. `State.plates_due()` (it replaced
  `plates_full()`) is empty until the plates not yet ironed hold as many
  beads as the picture puts on them; then `_maybe_iron` irons every plate
  that is right (fused, with its word and streak) or holds a bead astray
  (home it goes), one after another, and leaves alone a plate that is only
  short. One pass costs one heart at most on Insane (`_plate_done`'s
  `costs`), however many plates are wrong, or two wrong plates would end a
  two-heart board at once. A board finished right still skips the plate
  irons for the win's own. `PG_RULES_PLATES` and the two `HTP_PG_PLATE_BODY`
  strings say so in the three languages; the tutorial's PLATE diagram still
  draws one plate ironed alone and `HTP_PG_LAST_CAP` still says "one bead
  short of a full plate" -- both are owed a redraw. `_probe_pixel_garden.gd`
  was already stale (five Hard-hearts checks, since hearts went to Insane
  only); its "plate 0 ironed by the moved bead" and "not flawless" checks
  now fail too, by design.
