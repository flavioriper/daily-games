# Lattice

- **Lattice is the thirty-fifth card** (2026-10-09, `puzzles/lattice2d.gd`,
  `puzzles/lattice_state.gd`, `puzzles/lattice_gen.gd`,
  `ui/faces/lattice_art.gd`; no spec and no concept tab -- asked for and
  built in one sitting while the user was away, "do autonomous, no
  questions"). The daily web game it follows is Number Waffle, and **that
  name goes nowhere else**: not in code, comments, commits or on screen. The
  puzzle id is `lattice` and the locale prefix `LA_` (`LT_` was Lucky
  Thirteen's).
- **The rules were read off that game's own page and script on 2026-10-09**:
  a square of tiles with every odd-row, odd-column cell left out, so every
  other row and column is whole; each whole line holds 1 to n once (the
  short lines are not constrained); every tile is on the board, scrambled;
  the one move is to swap two tiles; a tile in its own cell changes colour,
  and there is only that one colour (the page's script answers `green` or
  nothing for a digit -- no "right number, wrong place"); a circle in a gap
  carries the sum of the tiles it points at, its directions any of left, up,
  right and down; twenty swaps for a deal that can be done in fifteen, and a
  star a swap left over. Ours, name for name: the lattice, the tiles, home
  (leaf green), the knots, swaps.
- **One move, two ways to make it**: drag a tile onto another, or tap one
  (it lifts, with a sun rim) and tap the other. A tile at home is not picked
  up and nothing is swapped onto it (`REFUSED_HOME`, a shiver and the
  toast); two tiles of one number are not swapped either (`REFUSED_SAME`: it
  would change nothing and, on Insane, cost a swap). A refused swap costs
  nothing. **That a home tile is locked was taken from the letter game it
  comes from, not read out of the page.**
- **The bands** (`Gen.BANDS`): Easy 5 by 5 on 1 to 5, four knots, par 8;
  Medium 7 by 7, nine knots, par 12; Hard 7 by 7, nine knots, par 15; Insane
  is **Twenty**, 7 by 7 with six knots of the nine, par 15 and twenty swaps.
  Easy to Hard cannot be lost: the pill reads the swaps made against the
  fewest there are ("4 swaps - best 15"), and the win says both. Undo and
  the bulb (3 / 3 / 2) up to Hard; neither on Insane.
- **Insane departs from "Insane counts moves" twice, on purpose**
  (`docs/agents/flat-screens.md`). The green of a tile at home comes from
  the answer and stays on Insane: it is the game's one piece of feedback,
  not a judgement added to it (Hidden Word's letters are the precedent).
  And the slack is **5, not max(3, par / 4)**, so the band is the original's
  twenty for fifteen. The out-of-moves card reads Out of swaps
  (`LA_OUT_*`; `ui/hud/out_of_hearts.gd` takes `words.more` for a counted
  board too since this board), its video buys five.
- **The phone never deals a lattice.** `tools/build_lattice.py [count]
  [seed]` writes `content/lattice.json`, 365 deals a band, in about 35 s. A
  deal is an answer (the crossings first, then each line's own cells), a
  scramble built from tiles that traded places in pairs and a few rings of
  three (so most swaps of a clean solve send two home at once, as the
  original's do), and knots that each point two of the four ways. It is
  kept when its **par** -- the tiles out of place less the most cycles their
  holds-wants graph splits into, searched exactly -- is the band's, and when
  the opening **allows one answer only**: the tiles on the board, the ones
  home, the ones known not to be, the whole lines and the knots. The
  original's knots may point one to four ways; ours always two.
  `tests/_probe_lattice_bank.gd` (headless) re-proves what the phone can
  (sizes, lines, the multiset, the bulb's own solve): **re-mine when a band
  in `lattice_gen.gd` changes**. Without the file the phone deals its own
  (`Gen.generate`), unproved, a fallback only.
- **The bulb** makes one swap of the answer as the player would, two tiles
  home at once when there is such a pair. Its own solve runs one swap over
  par on about one deal in ten (it does not plan the rings of three), which
  is why Insane has none and why `_win.gd` plays Medium.
- **Drawn as**: `_still` (the card, the slats, a socket a cell; a layout),
  `_knots` (rebuilt when one settles), and the tiles as unit meshes under
  transforms baked with `Face.FlatBuilder` -- `_rest` and, for a tile in the
  air, picked or under the finger, `_top` over it -- each followed by its
  numerals, a `draw_string` a tile under the tile's own transform. One pill
  and the toast on a layer of their own. **89-122 draw calls on both
  drivers** (forty numerals are forty commands; the win's confetti is the
  peak). No character: the pieces are marks.
- **A knot turns leaf** once every tile it points at is home, with a bump.
  It says nothing while its sum is merely met by the wrong tiles.
- **Motion that is this board's own**: the two tiles of a swap crossing in a
  shallow arc and growing a little at the top of it (`SWAP_TIME` 0.24); the
  turn to green as a tile lands, with a ring; a whole line hopping end to
  end; the win's hop along the diagonals; the seal for a day done in the
  fewest swaps, or any Insane one. A tile in the air is not picked up.
- **Harnesses**: `tests/_shot_lattice.gd` (rest, play, refuse, hint, solve,
  out, reset, restore); `tests/_probe_perf.gd -- lattice` makes the answer's
  swaps (`x=buzz` for the knocks, `howto` for the tutorial);
  `tests/_win.gd -- lattice` wins through the input path with a refused
  tap, the bulb and a drag on the way; `tests/_probe_lattice_bank.gd`.
- **Not seen on a phone.** Shots and probes on this Mac only, on both
  drivers. The seventeen sounds are one take a cue (`home` two) and unheard
  by the user; the pt and es lines are unreviewed (treliça / celosía, peça /
  ficha, troca / cambio, nó / nudo).
- **The sounds were redone against the cozy rules on 2026-10-10**
  (`docs/agents/sound.md`, the row for `lattice`): two ticks, one muffled
  note and Hedgehogs' air; a swap is a puff, a tile home a tock, two home
  two tocks rising, a line two soft notes over the tock. The only change in
  `lattice2d.gd`: `pick`, `drop`, `swap`, `home`, `home2`, `miss` and `undo`
  play at 0.94 to 1.06 at random (`TICK_VARY`; 1.0 every time before).
  Measured, not heard.
- **Calls made without the user** (2026-10-09): the name and the garden
  lattice; knots that always point two ways; Easy at 5 by 5 and the par of
  each band; Easy to Hard uncounted with the par on the pill; Insane's six
  knots and its name, Twenty; the green kept on Insane; tap-tap beside the
  drag; two of one number refused; one answer only, which the original does
  not promise; stars left out (the win says the swaps to spare).

## 2026-10-13: Insane has the bulb again

What this file says of Insane having no hint (or only a video's) is history:
Insane holds as many hints as Hard on every board with a bulb, at the
user's word. `docs/agents/flat-screens.md`, "Insane has the bulb again".

### The garden wall is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/lattice_world.gd` is the card's slate
paper as a garden wall on a pale morning, a sprig of the climber, a blank
tile and a knot bead in the gap of the tools row, and at the foot a low
diamond trellis of the board's own slats between two capped posts with a
climber wound across it out of a terracotta pot, the lawn's rise, two
blank tiles, a bead and dropped blooms; six pollen motes breathe. Nothing
in it has a number. The board has no rack (every tile is on the lattice),
so nothing lies under it; the paper card behind the lattice is gone and an
Easy cell is 200 (it was about 188). `set_foot(y)` sizes the trellis.

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 83 draw calls at rest; `tests/_win.gd --
  lattice` passes in par.
- Decided for the user, unconfirmed: the slats straight on the wall; the
  larger Easy cell. Owed: a phone, Insane with its swap pill.

## Made fun (2026-10-29)

The user: "make lattice and light up experience way better to play, and
game itself way funnier to play, right now nobody likes it", autonomous,
push when done. References from the web: reviews of the letter game it
follows praise the swap limit and the stars for few swaps, and its yellow
("right letter, wrong place") is what turns guessing into reading; in a
number lattice every line holds 1 to n, so a yellow would say nothing (the
2026-10-09 note: the original's script answers green or nothing). The lever
is the rules the player can read, said out loud.

**Measured first** (`tests/_probe_la_fun.gd`, headless, 40 days a band, a
hand making the answer's swaps in a random order, `State.read()` before
each): the rules alone (lines, knots, the tiles still out) decide a square
on **every** reading of every band -- a line's last square 60-76%, a knot
with its other tiles home 23-39%, the rest a square only one number fits;
the "no reason, here is the answer's swap" fallback fired 0 times, a
decided square was never wrong, a reading is under 1 ms (one 14 ms
outlier on Hard). At the opening a plain square still takes 2.7 (Easy) to
3.8 (Insane) numbers by the rules. So the lattice was always readable, and
the board said none of it: a swap came back green or plain, nothing else,
and the uncounted bands could be brute-forced.

**What changed**:

- **The bulb teaches in two presses** (`hint`, `State.read`, `_why`): the
  first rims the decided square in sun (thick), the tile to bring there,
  and the line or the knot that decided it, and the toast says why
  (`LA_WHY_LAST_ROW/COL`, `LA_WHY_KNOT`, `LA_WHY_ONLY`,
  `LA_WHY_HIDDEN_ROW/COL`, `LA_WHY_PAIR` unreached) plus `LA_READ_AGAIN`,
  for one hint; a second press makes the swap, free. A swap by hand, Undo
  or Reset puts the reading out. The tile chosen is one whose own square
  wants what the decided square holds, when there is one (two home).
  Tutorial HINT page presses twice (`HTP_LA_READ_CAP`, then
  `HTP_LA_BULB_CAP`, now "Second press").
- **The guide over a picked or held tile** (`_draw_guide`): every other
  plain tile its number cannot go to by the rules (`State.candidates`) is
  veiled in paper, and a tile whose square only that number fits is rimmed
  in sun. One mesh, made when the tile is picked. Rules only, never the
  answer. Said in the rules (`LA_RULES_GUIDE`).
- **A swap that sets a number where the rules rule it out** rims that
  square rose (`_wrong_at`, kept until that tile moves) and the toast says
  why (`LA_NOT_ROW/COL`: the line already has that number home;
  `LA_NOT_KNOT`).
- **Live stars** (`star_line.gd`) on the pill's strip, left: slips are
  swaps that sent nothing home (a clean solve sends one or two home every
  swap) and bulbs read; `STARS_CUT` [0, 2].
- **Runs**: each swap sending a tile home climbs the home cue 3.5% a swap
  (to 1.3); every third says `LA_RUN` with sparkles; two home at once
  sparkles both. The win's subtitle adds `LA_WIN_RUN` from a run of 3.
- **The toast** is the shared `ui/flat/toast_card.gd` (the board's own
  dark pill is gone), in the open garden under the lattice, else over its
  foot or head as before.
- Deals, bands, par, sounds and Insane's rules unchanged. en/pt/es
  (machine-written pt/es, unreviewed).
- Harnesses: `_shot_lattice.gd` modes `hint` (read, the tile picked under
  the guide, swapped) and `wrong`; `_win.gd -- lattice` checks both
  presses (PASS). `opengl3_angle` 810x1440: Medium 98 peak in `hint`, 88
  in `wrong`; Insane 98. `_probe_insane_hints -- id=lattice seeds=4`: 0
  failures. Suite 303252/0. Unseen on a phone.
- Calls made without the user: a bulb read is a slip (as Patio's);
  stars by slips, not by par; no running sum on the knots (the guide does
  that work); no yellow.
