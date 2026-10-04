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
