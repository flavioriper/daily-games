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
