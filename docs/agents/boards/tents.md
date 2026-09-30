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
