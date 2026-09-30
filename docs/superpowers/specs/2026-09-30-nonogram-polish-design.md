# Nonogram polish: shapes, failing, Leaf Fall, rewards, motion and sound

2026-09-30, built unattended on `feat/nonogram-polish` at the user's word
("let's polish the nonogram game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to the
user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the game
nearly impossible, user can also fail on insane and hard ... don't worry if
you need to redo something on the logic or design, as long as it keep the
cozy vibe. I saw on internet some boards with different shapes, like
rectangles as portrait, landscape, not just squares").

Shikaku's, Tents', Light Up's and One Line's passes the same day are the
pattern: this follows them wherever the boards meet, so the game fails and
celebrates one way. No concept tab: polish of a built screen plus a rule,
with the user away. The calls at the end are for the user to judge on the
phone. Sections 1 to 12 of `2026-09-18-nonogram-flat-design.md` stand except
where this says otherwise.

## 0. Shapes: tall and wide, not just squares

Every band draws its picture's shape from `Gen.SHAPES` with the day's rng,
before the picture: Easy 5x5, 5x6 or 6x5; Medium 7x7, 6x8, 8x6 or 7x9; Hard
9x9, 8x10, 10x8 or 9x11; Insane (banked) 10x10, 9x11 or 11x9. A drawn shape
that will not line-solve in 300 tries falls back to the band's square
(`State.SIZES`). The layout already measured the grid and both bands
separately, so a portrait picture is capped by the height and a landscape
one by the width; the card is cut to fit and centred as before. The level
lines say it: "5 × 5, tall or wide" (`NG_LVL_0`..`NG_LVL_3`).

## 1. Hard and Insane can be failed

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`), on the shared paper pill in
  a `HEART_ROW` strip over the clue band (`_heart_row()` in `card_height`,
  `_cell_for` and `_layout`).
- **What costs one**: a tile laid where the picture has none. Every tile on
  Hard and Insane is judged as it lands, as in every phone picross
  (Nonogram.com's three lives are the reference): a stroke stops at the
  first wrong tile, the cells after it are let go. The picture is unique, so
  a wrong tile is wrong by proof. Crosses are never judged -- they stay the
  player's notes -- and neither is a rub-out.
- **The wrong tile** lands like any other, blushing, with a rose puff; the
  heart's halves fall; the sprout goes WORRIED; `EJECT_AFTER` (0.8 s) later
  the tile turns out of its socket (the Remove moment) and a pebble drops in
  where it was, **for good** (`state.reveal`: marks MARK, locked, and dropped
  from every stroke in the history). The heart bought information. A press on
  that pebble is refused: "That cell is empty for sure. A heart showed it."
  Input, undo, hint, check and reset wait on `_ejecting`; `busy()` holds the
  host's hint video.
- **Out of hearts**: the floor eases to dusk (`modulate` toward `DUSK`), the
  sprout dozes off, and `ui/hud/out_of_hearts.gd` comes up with
  `NG_OUT_BODY`/`NG_OUT_REST`. Try again takes every tile up in Reset's wave
  and deals the same picture with every heart back (hints spent stay spent);
  One more heart brings the light back where it stands.
- **Insane has one hint** (`State.HINTS_BY_BAND`). Easy and Medium are as
  they were: nothing is judged until Check.
- **Check on Hard and Insane** looks at pebbles, since no wrong tile ever
  stays down there: a pebble on a cell the picture wants blushes its socket
  rose and shivers (the open call 6 of the flat spec, answered where it
  matters).

## 2. Insane: Leaf Fall

The known nonogram variants are colour (several inks), triangle and hex
grids, mega clues spanning two lines, missing or "?" clues, and 3D. All of
them keep a clue's numbers **in order**, and order is the backbone of every
nonogram technique: the first run is at least this far from the left edge,
the last run this far from the right, and every overlap argument leans on
it. We could find no variant that takes it away. Leaf Fall does:

- **On some lines the wind has tumbled the numbers.** Each rides a leaf,
  tilted, shown largest first -- an order that says nothing. Every run is
  there, but they may come in any order. A leafless line reads as ever.
- **The board**: 10x10, 9x11 or 11x9, 8 to 17 tumbled lines (only a line with
  two different numbers can tumble; "2 2" reads the same either way). The
  picture has a little raw noise in it (`Gen.picture`'s `grain`, 0.1 to
  0.2), so lines carry several runs of several lengths.
- **Why it is nearly impossible**: line logic on a tumbled line allows every
  order of its runs, and that is most of what a nonogram gives. On the banked
  boards plain line logic leaves **74% to 100% of the grid undecided** (the
  rung). What finishes them is the careful player's last resort: suppose a
  cell, follow the lines, and if they end in a contradiction the cell was the
  other way. The sprout teaches exactly that (`NG_TIP_LEAF_2`). With a single
  heart, one wrong supposition laid as a tile ends the board.
- **The rule is what makes it hard, measured**: with the numbers put back in
  order, Hard's own line solver finishes 150 of the 160 banked pictures, and
  line logic leaves a mean of 2.3 cells open. Tumbled, it leaves 74 to 100
  in a hundred.
- **Fair**: `Gen.Deep` (bit masks, one instance a thread) runs line logic,
  then one-cell suppositions, until the grid is known. A board it completes
  has exactly one answer, reached without guessing. `candidate` tumbles every
  line that can tumble and, while the board is not proved, puts back the order
  of one tumbled line through the open cells and tries again.
- **Banked** (`content/insane/nonogram.json`, 160 boards, rungs 737-1000,
  mined by `tools/insane/nonogram_ladder.gd`, 478 of 4000 tries kept, 54 s on
  8 threads). The rung is the per-mille of the grid line logic alone leaves
  open; `HARD_RUNG` 330. `work` is the suppositions it took. All 160
  re-proved through `Gen.from_bank`, the slowest in 28 ms. An empty bank
  falls back to a live 10x10 with nothing tumbled.
- The level card: "10 × 10 or so, leaf fall". Rules add `NG_RULES_LEAF` and
  the hearts line; tips lead with `NG_TIP_LEAF` and `NG_TIP_LEAF_2`.
- **Motion**: on the entrance each tumbled number flutters down onto its tab
  (`LEAF_DROP`, `LEAF_FALL`, `LEAF_SWAY`) on its leaf; the leaves leave with
  the scaffolding on the win, and fall again, twenty-six of them, at the
  party.

## 3. Rewards

- **Daisies**: a line that reads right opens a daisy at the outer end of its
  tab (`_bloom`, `bloom`), on every level, and folds it when it stops being
  right. At the party they let their petals go.
- **A finished line lays its pebbles** on Hard and Insane (every tile there
  is judged, so a line that reads right is done): its empty cells take
  pebbles in a ripple out from the stroke (`AUTO_STEP`, `pebbles`), in the
  same history entry, so one Undo takes them with the stroke.
- **Streak**: right strokes in a row. On Hard and Insane a stroke that laid a
  tile (all are judged); on Easy and Medium one that brought a line to read
  right and left none over-filled -- what the board already shows, so the
  streak gives nothing away. `combo` pitched up the major pentatonic from the
  second, the "x3" paper bubble by the stroke's end, confetti at 5 and 10. A
  wrong tile, an over-filled line, an undo or a reset ends it.
- **Gags**, three of every five right strokes by the stroke's hash: little
  **hearts float up** off the tiles just laid (`love`); a **mushroom pops up**
  out of the nearest pebble and grins (`mushroom`; a stroke with no pebble
  within four cells gets the hearts); **the queen bee from Queens zooms
  along** the line (`bee`).
- **The frame**: after the reveal, the finished picture is **hung in a
  wooden frame** with brass nails (`_frame`, `frame`), popping in wide, and
  the clue numbers go the rest of the way out.
- **What it looks like**: the sprout takes a guess at the picture, one of
  twelve silly ones picked by the picture itself ("A cat, if you squint. A
  loaf, if you don't.", `NG_LOOKS_0`..`11`). The generator's pictures are
  blobs -- the flat spec's call 3 -- and this makes a joke of it rather than
  hiding it.
- **Seal**: Flawless (no hint, and no heart lost on Hard and Insane, or no
  Check on Easy and Medium) stamps the gold seal; any Insane solve stamps the
  night seal, "Insane" over "Flawless" or "Leaf Fall". `share_glyphs()`
  gains `🏅 Flawless` or `🌙 Leaf Fall[ · Flawless]`.
- **Party**: confetti twice, the daisies' petals, and on Insane the autumn
  leaves. `win_delay()` gains `PARTY_EXTRA`.

## 4. Motion

New, on top of sections 11 and 12 of the flat spec: the wrong tile's blush,
puff and turn-out, the pebble dropping into its place, the heart split and
return, the dusk, the auto-pebble ripple, the daisies opening with a twist
and folding, the leaves fluttering onto their tabs, the streak bubble, the
love hearts, the mushroom, the bee's bobbing flight, the frame's wide pop,
the seal's drop, the petal and leaf showers. Under reduce motion: no gags,
no flutter, no showers or confetti; daisies stand open, the frame and the
seal stand still, the ripple lands at once.

## 5. Sound

Re-prompted toward felt, wood, ceramic and kalimba, as the other four were:
`place`, `locked`, `undo`, `hint`, `check`, `check_ok`, `reset`, `enter`,
`solved`. New: `combo`, `confetti`, `love`, `mushroom`, `bee`, `bloom`,
`pebbles`, `heart_lost`, `slip`, `out_of_hearts`, `heart_back`, `stamp`,
`frame`, `party`, `petals`, `leaves`. Rendered on the fallback key (the first
ran out of credits); unheard.

## 6. Numbers

Draw-call peaks from `tests/_shot_nonogram.gd -- d=<n> <mode> [rm]`
(810x1440, `--always-on-top`, `opengl3_angle`):

| mode | d=0 | d=2 | d=3 |
|---|---|---|---|
| rest | -- | -- | 90 |
| solve (party included) | 114 | 115 | 117 |
| solve, reduce motion | -- | 50 | -- |
| wrong, to the card and Try again | -- | 112 | -- |

All far under the 855 budget. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- nonogram`: PASS.

## 7. Calls for the user

1. **Leaf Fall on the phone**: whether the leaves read as "these numbers are
   loose" at a glance, and whether "largest first" is the right neutral order
   (the alternative is a true shuffle by hash, which reads more windswept but
   invites the player to believe it).
2. **Judged tiles on Hard**: standard in phone picross and it makes Hard
   loseable, but it also tells the player the moment a tile is right, which
   is more help than the old Hard gave. The alternative is judging only on
   Check, which is how Easy and Medium stay.
3. **The seal sits on the framed picture's corner** on a tall picture that
   fills the card; a sticker on the painting, or should it move off it.
4. **Twelve guesses** at what the picture is: the tone is silly on purpose.
5. **Sounds are unheard.**
