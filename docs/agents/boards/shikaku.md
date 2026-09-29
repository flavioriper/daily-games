# Shikaku

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Shikaku's clues can ask for a shape** (2026-09-25). A clue is
  `{pos, area, shape}`: `shape` is `shikaku_gen.gd`'s `Shape` (any, square,
  tall, wide) and `area` 0 means no number -- the plot may be any size of
  that shape. `Gen.fits()` is the one rule every check goes through. The
  ladder is `shikaku_state.gd`'s `SHAPES`: Easy numbers only, Medium shapes
  on some numbers, Hard and Insane take numbers off shaped clues (about 19%
  and 54% of clues over 40 seeds), each removal kept only if the board stays
  unique. The solver is a cell-first exact cover now, because a numberless
  clue breaks the "areas sum to the field" shortcut; worst generation 57.5 ms
  on Insane. The sign *is* the shape (`marker_face.gd`'s `PLAQUES`), and a
  shaped sign carries an inked inner frame so a square never reads as the
  plain card. The win's flowers are coloured so no two touching beds match.
