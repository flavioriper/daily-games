# Tents

The flat board's history before 2026-09-30 is in
`docs/superpowers/specs/2026-09-18-tents-flat-design.md` (and its two
amendments) and in `docs/agents/flat-screens.md`.

### Failing, Old Oaks, rewards, motion and sound (2026-09-30)

Spec `docs/superpowers/specs/2026-09-30-tents-polish-design.md`, built
unattended on `feat/tents-polish`, following Shikaku's pass of the same
morning.

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`). A heart goes only on a tent
  that `state.tent_fair` passes (beside a tree, touching no tent, no known
  line over) and that is not the answer's. The tent wilts (WORRIED fades the
  canvas) and `_eject` strikes it through `state.undo()`. Everything waits
  on `_ejecting`. Out of hearts reuses `ui/hud/out_of_hearts.gd` with
  `TN_OUT_BODY`/`_REST`. The board's layout variable `_card` is a Rect2, so
  the out-of-hearts card is `_heart_card`.
- **Insane is Old Oaks**: banked 10x10 (`content/insane/tents.json`,
  `tools/insane/tents_ladder.gd`). Three oaks (`OakFace`, two acorns) take
  two tents each, which the no-touching rule forces onto opposite sides.
  Every count that can go while the answer stays unique is hidden (-1, a
  "?" chip): 15 to 18 of the 20. A board is kept only when it stops being
  unique with the oaks relaxed to one tent or two. `Gen.count_layouts`
  counts layouts by tent set; `Gen.is_valid_oak_solution` is the win test
  when oaks or hidden counts are present. One hint.
- **Trees beam and hop** once they have the tents they want beside them.
  **Right tents light** (JOY and a warm pool) on Hard and Insane only.
- **Streak, gags (camper peek, sunglasses, bunny), butterflies, seal, party
  with hats and bunting**: see the spec. `TentFace`, `ConiferFace` and
  `OakFace` seat the glasses and hat through `_face_frame`/`_hat_place`.
- **Sweep** ticks `cairn` / `clear` per square, pitched up as it grows.
  Taps play `place` or `strike`.
- **Harness**: `tests/_shot_tents.gd -- d=0..3 rest|right|wrong|sweep|solve|perf
  [rm]` (the `wrong` mode ends with Try again). Draw calls (angle): 226 peak
  across the Insane solve, 135 under reduce motion.

### Performance checkup and the tutorial (2026-10-01)

- **Measured first** (`tests/_probe_perf.gd tents d=3 [fill]`, ANGLE,
  810x1440, second of two runs; the probe now sweeps every row into cairns a
  run at a time and then taps the answer's tents): Insane idled at **142
  draw calls, ~9.6 ms**; a near-full meadow (70 cairns) at **182, ~14.8 ms
  with p95 25 ms**, and every gesture on it ran ~26 ms frames. One rebuild of
  the ground mesh (every cairn, shadow and pool) cost **~28 ms** with 70
  cairns, and it was rebuilt every frame anything on the ground moved. The
  faces were the other half: a tree one call, a tent two, a chip two (card
  and numeral) -- about a hundred calls on a full meadow.
- **The ground at rest is one mesh** (`_still`, `_rest_parts`,
  `_bake_still`): each still part on a square (a cairn, a tree's or tent's
  shadow, a lit tent's pool) is made once per square and layout and baked
  with `Face.FlatBuilder`, again only when the set changes. `_ground` keeps
  only what moves (stacking and leaving cairns, popping shadows, the camp on
  the win), `_under` the shade and blush (they lie under the cairns), and
  the win's sinking cairns are each their standing mesh under a transform
  (`_sink_xf`) for the second they take.
- **The cast** (`_cast`, `_sync_cast`): trees, tents and chips keep their
  motion but draw only hats and glasses (`skip_layers`; a chip also skips
  its `numeral`); their bodies are one MultiMesh per mesh on show and every
  numeral one run of glyphs. Their transforms are copied every frame (the
  trees always sway); a buffer is handed over only when it changed.
- **Shared fix**: `Face._mesh_for`'s per-face memo now keys on `_kind()`
  too. A tent pegged by a hint on a square tapped before kept its unpegged
  fabric; a bee pinned, a lantern lit (Light Up's lit level is in its kind)
  could do the same.
- **After**: Insane idle **95 / ~6.3 ms**; near-full idle **109 / ~9.7 ms,
  p95 10.6**; play on the full meadow ~8.7 ms; the Insane solve's peak
  (`_shot_tents solve`) **211 -> 134**. Easy to Hard full idle 99-102 /
  ~8-9 ms. Visuals compared frame for frame with the old build (sweep and
  solve shots). Still open: the winning tap's own frame (~7 ms of script,
  `_on_solved`); no phone reading.
- **Undo, Hint, Check and Reset** were already on every band.
- **The tutorial is four to six pages** (`tutorial_pages()`,
  `ui/hud/tents_tutorial_diagram.gd`): each page holds a real board
  (`Meadow`, tents2d.gd with sound, tips, gags, butterflies, the solve and the
  out-of-hearts card taken out; its id names no sound set) dealt a 4x3
  meadow and played through its own `_gui_input`, so every tent, cairn, chip
  and heart is the board's. Beside a tree and not on a corner (PITCH), never
  touching (TOUCH), a full line turning green and the sweep over the rest and
  over a 0 line (LINES), the hint's pegged tent refusing a tap (HINT), then
  hearts on Hard and Insane (HEARTS: two layouts with the same counts, so
  the wrong one breaks no visible rule) and Insane's oak with hidden counts
  (OAK). Reduce motion shows each lesson's answer.
