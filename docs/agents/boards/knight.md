# Knight

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Knight is the twenty-third card** (2026-09-26, `puzzles/knight2d.gd`,
  spec `2026-09-26-knight-flat-design.md`, mock
  `docs/brainstorm/concepts.html#knight`). Hop a cream knight in Ls to take
  the rose king; rose knights answer every hop by a fixed greedy rule, and a
  hop into their reach is caught and slid back one move. The reference is a
  Portuguese app's *Cavalo*; **it is called Knight**. Two things travel:
  **a deterministic opponent makes the whole game a graph** -- a position is
  only where everyone stands, so `knight_gen.gd`'s `solve` is a plain
  breadth-first search and the proof is the shortest line -- and **a knight
  always changes colour**, so a rose knight on your colour can catch you and
  you can never take it, and one on the other colour the reverse; the
  corners show it without a word. Its drawing is `ui/faces/chess_piece.gd`,
  shared with the menu card. 67 draw calls bare, 66 played, 71 solved,
  ANGLE agreeing. Sounds generated (2026-09-26), one take a cue, awaiting
  the user's listen. The board toasts its own explanations (Rings' toast), because
  the tip card is gone and `tip_line()` reaches no screen, and a Hint on a
  lost position rewinds to the last one that still has a line (`KN_REWOUND`).
  **Polished on 2026-09-26** (the spec's amendment): a garden table under the
  board (a third mesh, clipped to the card), shaded pieces, a hop that
  crouches and leans with dust on landing, a taken knight knocked tumbling
  away, a caught one knocked aside dizzy, hoofprints along the last three
  Ls, a blink and a dozing king at rest, and a win where the king is shoved
  over, his crown spins off, your knight rears and petals fall. 68 bare, 67
  played, 73 on the win, ANGLE agreeing.
- **Polished again on 2026-10-01** (spec `2026-10-01-knight-polish-design.md`):
  players got stuck in dead positions with nothing on the board saying so
  (a quarter of random Medium positions and half of Hard ones are lost), so
  Easy to Hard now prove `State.lost()` after every kept hop and raise a
  **Start over** button under the board. Hard has 3 hearts (a catch costs
  one), Insane 2. **Insane is Brambles**: every square you hop off grows a
  bramble nothing lands on again, a rose knight fenced in naps for good
  (`Gen.NAP`), and boxed in costs a heart and withers back to the opening;
  200 boards mined by `tools/insane/knight_bramble_mine.py` (lines 14-30,
  at most 12 lines within two more hops, 46 need a nap), re-proved by
  `tests/_probe_knight_bank.gd`. The move budget is gone. Rewards: streak,
  somersault / love / butterfly gags, the crown landing on your knight's
  head, the nap cat and the seal (moved to the lower left when the king is
  in the lower right). PADDOCK sound set, unheard. Peak 105 draw calls
  (out of hearts), `tests/_shot_knight.gd` has every mode.
- **Checkup on 2026-10-02** (`docs/agents/checkup.md`, row 23): four meshes
  now -- table, still (kept across the win card's relayout and drawn
  scaled), ground (brambles or trail, and the marks; handed back while
  `_ground_key` holds) and pieces -- the last two put together by `RunMesh`
  from looks made at `_ref_s` (`_make_shape`, ids `SH_*`). `Piece.knight` and
  `Piece.king` take `shadow := false` so the board can put the shadow as its
  own look, painted per alpha. The tutorial is
  `ui/hud/knight_tutorial_diagram.gd`, a quietened board (`Board`) on 5x5
  positions; the board gained `_inset()`, `_hearts_at()`, `_stuck_width()`
  and `_stuck_spot()` for it. Peak draw calls 111 (out of hearts, was 105).

- **Insane counts moves (2026-10-04)** (`docs/agents/flat-screens.md`,
  "Insane counts moves"): `HEARTS_BY` is all zero, so a catch and being
  boxed in cost no heart anywhere (`_lose_heart`, `_boxed_in` are dormant).
  **The budget** is the bank's line -- the shortest, re-checked against
  `Gen.solve` -- plus a quarter, three at least (`State.moves_budget()`:
  20 + 5 = 25, 14 + 3 = 17; not the state's old `budget()`/`moves_left()`,
  which are the 2026-09 Insane's cap and still read 0). Every hop costs one
  (`_spend`), **a caught hop too**: the catch still shows and slides back,
  as on Medium, since the rose corners already said it. **Boxed in no
  longer withers the board back by itself**: it brings up Start over (the
  lost-position button of the other bands, with `KN_BOXED_MOVES`), because
  `trapped()` reads only the corners and thorns on the board; the search
  that proves a position lost (`State.lost()`) is still never run on
  Brambles. Reset, Start over and Try again hand the whole budget back; the
  card's video buys `MOVES_BONUS` from where the knight stands. No Undo, no
  hint (`capabilities()` is empty on Insane). The tutorial's STUCK page on
  Insane now plays the Start over column like the other bands
  (`knight_tutorial_diagram.gd`: `judged` reads the hearts table), and the
  shared moves page closes it. New lines at the end of `locale/boards.csv`:
  `KN_RULES_BRAMBLES_MOVES`, `KN_BOXED_MOVES`, `HTP_KN_BOXED_BODY_MOVES`,
  `HTP_KN_RESET_BODY_MOVES`, `HTP_KN_MOVES_BODY`, `HTP_KN_BOXED_MOVES_CAP`;
  the rules close on the shared `RULES_MOVES_SEQ`. Not seen on a screen yet
  (`tests/_probe_moves.gd -- id=knight`).

### The castle court is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/knight_world.gd` is a courtyard in the
card's oat tones with faint flagstone joints, a horseshoe, three
hoofprints and a small crown in the gap of the tools row, and at the foot
the court's wall with battlements, two turrets under rose roofs with
pennants, a plank gate and rose bushes; five petals breathe on the air.
Once bled the board's own plank table is not drawn; the frame is on the
host's margin and the 170 cell cap is off (an Easy cell is 190).

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 79 draw calls at rest; `tests/_win.gd --
  knight` passes.
- Decided for the user, unconfirmed: a court, not the garden table; the
  larger cells. **Start over stays**: it does what the bin does, but it
  comes up only once the position is proved lost and does not ask; the
  user's to call whether it goes. Owed: a phone, the level slide.

### Made fun (2026-10-29)

The user, 2026-10-29: "make how big and knight experience way better to
play, and game itself way funnier to play, right now nobody likes it. Use
web for reference on how good games does it." Built unattended. What the
web said of knight puzzles: they turn into trial and error when "it is hard
to tell what path the knight is going to take", and a hint that just plays
the level is resented. **Measured first** (`tests/_probe_kn_fun.gd`, a
player who never lands in rose corners and otherwise hops at random, half
the time toward the king): **25 of 30 Medium days and 30 of 30 Hard days
walk into a dead end, at the 2nd-3rd hop** (p50), with nothing said until
the board proves it; Easy 2 of 30. The rose side's rule is fixed, so the
whole answer can be shown before a hop -- the fix is to show it.

- **Hold a dot to see the answer** (`_hold`, `_peek`, `_draw_peek`): while
  a dot is held, your knight's ghost stands on it with the hop's prints,
  each rose knight's ghost stands where it would answer with **the prints
  of its own hop** (so a ghost is never only a paler rose), a knight that
  would be fenced in shows its z's, a catch shows dizzy stars over your
  ghost, the rose corners become the reach the rose side would have
  *after* its answer, and the other dots go quiet. The finger slides from
  dot to dot (each heard, `fx.touch`); let go on one to hop, off the dots
  to cancel (heard at 0.84). `State.peek` matched `State.play` on every one
  of 3,018 legal squares of 120 deals (the probe's guard). The first catch
  or dead end of a board says once that holding shows the answer
  (`KN_CAUGHT_HOLD`, `KN_DEAD_END_HOLD`, a longer toast, `TOAST_LONG`).
- **A dead end steps back, not over**: the button under the board reads
  **Step back** (`KN_STEP_BACK`, the undo glyph) on every band without
  Brambles and rewinds to the last position that still has a way
  (`State.rewind_to_live`, free; "One hop back. There is a way from here.").
  The bin still starts over. Brambles keeps Start over. This is the call
  the 10-13 note left open, made.
- **Live stars and a count** over the board on every band (the pill where
  hearts or moves stood, `_draw_count`; the world's horseshoe and crown in
  the tools row's gap are off, `knight_world.gd`'s `gap`): "3 hops ·
  shortest 6" and three stars read off the solver after each kept hop --
  hops so far plus the shortest line from here, against the day's
  (`State.stars`, `STAR_SPARE` 2 and 6; a star lost falls with the lip).
  Undo and Step back keep the hops made; Reset gives them back.
- **The bulb in two presses**: the first, a hint, rings the next hop of the
  shortest line in sun (kept until a hop) and reads the dots -- "2 of your
  5 dots lead to a dead end. The ringed one keeps the way open." (or the
  king in reach, or a rose knight to take; `State.reading`); the second,
  free, hops there. From a lost position the first press still rewinds.
  The tutorial's HINT page and `tests/_win.gd` press twice.
- **The win's line** names the hops against the shortest ("The shortest
  way: 6 hops!") and the best run of safe hops from three.
- `opengl3_angle` 810x1440: 81-92 draw calls peak (peek, read, lost);
  `tests/_win.gd -- knight` PASS; suite 303252/0. No new sound file.
- Decided for the user, unconfirmed: hold-to-preview on every band
  (Insane too: it shows naps and catches, never whether a position is
  lost); no dead-end mark in the preview (that would be the puzzle);
  Step back free; stars by 2 and 6 hops over; the count pill on every band.
  Owed: a phone (does a held finger hide the ghost under it? the ghost
  stands on the held square), pt/es read by a speaker.
