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
