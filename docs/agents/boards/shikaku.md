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

### Performance checkup and the tutorial (2026-10-01)

- **Measured first** (`tests/_probe_perf.gd shikaku d=3 [fill]`, ANGLE,
  810x1440, second of two runs; the probe now drags Shikaku's answer bed by
  bed, and `fill` leaves two whole drags): Insane idled at **129 draw calls,
  ~9.0 ms**, play ~11.1 ms with 27-32 ms frames; a near-full field idled at
  **156, ~12.1 ms**; the solve peaked at **253** with 25-30 ms frames through
  the planting wave and ~60 ms as the crop was folded into the beds. The
  signs were a third of the board's calls (stake, plaque, numeral each), the
  beds one call apiece, the wave one call a seedling, and the fence was
  rebuilt whole every frame it moved (1.5-2 ms).
- **Signs at rest are one mesh** (`_bake_signs`, `SignBake`): every sign
  standing still in its slot is baked eyes open and looking ahead
  (`Face.bake_into(..., rest)`) with its numeral (`MarkerFace.numeral()`),
  remade only when one joins, leaves or changes face; a party hat or glasses
  fully on is baked too. A sign that is only blinking or glancing draws
  itself over its baked twin (the plaque is opaque), so blinks never rebake.
- **`Face.FlatBuilder`**: the bake flattens each source mesh once into a
  plain triangle list (cached in a dict the board owns, `_flat_cache`), so a
  bake is native array copies; `Builder.append`'s per-index loop made a sign
  bake 4-8 ms, this ~0.8.
- **Beds at rest are one mesh** (`_beds_baked`): untinted, unmoved beds that
  are done tilling and sprouting; arriving, wilting and flashing beds draw on
  their own after it (beds never overlap).
- **The fence is two meshes** (`_build_fence`): finished stretches in
  `_fence_still`, made again only when that set changes; growing or leaving
  ones and their posts in `_fence`, every frame they move.
- **The crop is its own mesh** (`_crop_bake`): the wave is one mesh a frame
  from the cached seedlings, and the planted field keeps it; the beds are
  never rebuilt with the crop in them (`_build_bed` lost its `planted`).
- **After**: Insane idle **100 / ~7.2 ms**, play 119 / ~9 ms; near-full
  idle **~115 / ~9.3 ms**; the solve's peak **164**, mean ~11 ms. Easy,
  Medium and Hard idle 96-99 / ~7 ms. Still open: the solve's own frame
  (~23 ms: the release, `_on_solved` and the host's save) and the win card's
  first frame (~55 ms, the shared host, every board); no phone reading.
- **Undo, Hint, Check and Reset** were already on every band.
- **The tutorial is three to six pages** (`tutorial_pages()`,
  `ui/hud/shikaku_tutorial_diagram.gd`): a 4x3 field drawn by an off-tree
  board instance (`_art`) with the lesson's own State -- its ground, beds,
  pinned line, fence, dashed wash, count disc and heart pill -- under real
  MarkerFace signs; every move goes through `State.commit`, `undo` and
  `apply_hint`, so the signs beam, puzzle and blush as on the board. Draw a
  bed (DRAG), one sign in each and a tap to clear (ONE); then shapes from
  Medium (SHAPES), the hint with the band's count (HINT), hearts on Hard and
  Insane (HEARTS: a fitting bed that is not the answer wilts) and Insane's
  scarecrows (CROW: its neighbours counted). Reduce motion shows each
  lesson's answer.
- **Insane counts moves (2026-10-04)** (`docs/agents/flat-screens.md`,
  "Insane counts moves"). `HEARTS` is all zero, so `_judge` never calls
  `_wrong_bed` and `_settle` sprouts any bed whose sign is met, as on
  Medium (it used to hold the shoots back for the answer's beds); the
  HEARTS lesson is unreachable. That code is left in place, dormant.
  Scarecrows hands out `clues.size() + 3` moves (`State.moves_budget`; 21
  on an 18-sign field). `State.move_cost(rect, own)`: a bed fenced is one,
  a bed cleared is one, **a redraw from inside a bed is two** (one off, one
  down; a redraw landing on the same bed is free), and a refused drag
  (overlap) costs nothing. A redraw with one move left is refused with
  `SK_MOVES_SHORT`. The rules sentence is the board's own, `SK_RULES_MOVES`,
  because the shared one does not say what a redraw costs. No Undo, Hint
  (`HINTS_BY_BAND[3]` is 0) or Check. Signs still beam, strain and puzzle,
  and a scarecrow still counts its neighbours.
