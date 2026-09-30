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
- **A plot may not spill over another** (2026-09-30). `commit(rect, own)`
  refuses a drag that overlaps any plot but `own`, the one the finger went
  down in, with `{"kind": "taken", "plot": i}`: the board blushes that bed,
  shivers its sign and says `SK_TAKEN`. Drawing from inside a plot still
  redraws it. The pending wash turns rose while it overlaps another plot, so
  the refusal is seen before the release. Hints still clear what they cover.

### Failing, Scarecrows, rewards, motion and sound (2026-09-30)

Spec `docs/superpowers/specs/2026-09-30-shikaku-polish-design.md`, built
unattended on `feat/shikaku-polish`.

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`). A heart goes only on a bed
  that fits its sign (`fitted_clue`) and is not the answer; the bed wilts and
  `_eject` takes the move back with `state.undo()` (a redraw gives back what
  it replaced). Everything waits on `_ejecting`. Out of hearts reuses
  `ui/hud/out_of_hearts.gd`, which now takes a board's own body keys.
- **Insane is Scarecrows**: banked 8x10 (`content/insane/shikaku.json`,
  `tools/insane/shikaku_ladder.gd`), three signs whose number counts the beds
  sharing a fence with theirs (`clue.crow`), everything else shaped and
  stripped of numbers while unique, and kept only when the board is not
  unique with the scarecrows read as blank signs. One hint.
- **Settled beds sprout** (the seedling at `SPROUT_U`, in the bed's mesh);
  the planting wave grows on from the shoots. On a board with hearts only the
  answer's beds sprout, so a bed about to wilt never does.
- **Streak, gags, butterflies, seal, party**: see the spec. Hats needed
  `MarkerFace._hat_place` (the base seat is a cell above a plaque).
- **Harness**: `tests/_shot_shikaku.gd -- d=0..3 rest|right|wrong|solve|perf
  [rm]`. Draw calls (angle): 151 mid-board with butterflies, 272 peak across
  the Insane solve.
