# One Line

The flat board's history before 2026-09-30 is in
`docs/superpowers/specs/2026-09-18-oneline-flat-design.md` (and its
amendment) and in `docs/agents/flat-screens.md`.

### Failing, Sunny Spells, rewards, motion and sound (2026-09-30)

Spec `docs/superpowers/specs/2026-09-30-oneline-polish-design.md`, built
unattended on `feat/oneline-polish` after Shikaku's, Tents' and Light Up's
passes the same morning (the user asked for "the line up game"; read as One
Line, next in registry order). The names and the shape of the code are
Light Up's on purpose (`_break_streak`, `_draw_combo`, `_gag`, `_draw_life`,
`_party`, `_draw_stamp`, `_eject`, `_run_out`, `try_again`, `heart_back`),
so the game fails and celebrates one way.

- **Judging a step** is `state.step_leaves_finish(n)`, asked *before*
  `state.step`. One Line has many walks, so a step is never compared with
  one answer: it is wrong only when no walk finishes from where it lands.
  On Hard that is Fleury's question (`walkable_from`); on Insane it is the
  `Gen.Sun` search. A refused step (walked line, `STEP_SUN`) costs nothing.
- **Wrong step** (Hard and Insane): the plank is laid, the snail lands
  WORRIED, the plank blushes (`_bad_plank`), Hard's stranded lines wobble,
  the heart splits as she lands, and `EJECT_AFTER` later `_eject` undoes it
  with the undo animation and a `slip`. `_ejecting` holds input, undo, hint,
  check and reset; `busy()` holds the host's hint video. A wrong step still
  counts a move (`note_move` runs before `_wrong_step`).
- **Out of hearts** eases the whole board's `modulate` to `DUSK` (so the
  snail, the hearts and the fx dim with it), she goes SLEEPY, the ladybugs
  leave, and the card comes up. `try_again` runs Reset's wave
  (`_clear_figure`, shared with `reset_board`) and then `_deal`.
- **Sunny Spells** (`content/insane/oneline.json`,
  `tools/insane/oneline_ladder.gd`): sunny fords `Pal.FORD_SUN` with
  twinkling `SUN_SPARK` stars, dewy fords `Pal.FORD_DEW` with `DEW` drops,
  both in the one figure mesh. While she is dry (`state.dry()`, and only
  once she has stepped off the line, `_stroke_landed`) the sunny lines out
  of her post fade to `DRY_FADE` and `SnailFace.dry` hangs a bead of sweat
  by her head. A restored Insane day walks the banked planted walk
  (`state.solution_path()`), since `Gen.find_path` need not keep the sun
  apart.
- **The search** (`Gen.Sun`): a DFS over (walked bitmask, post, dry) with a
  dead-state memo kept per (post, dry) and reused across questions (a dead
  state is dead whoever asks). Pruned on connectivity and, per post, "sun
  <= dew + free ends" (the pass-pairing argument in the spec). On the bank
  it usually needs ~60 nodes, but a review timed 18394 judgments along random
  winning walks at 6.8 ms mean and 459 ms worst on this Mac, so a judgment
  stops at `State.JUDGE_NODES` (3000) and a spent search answers yes: an
  unknown never costs a heart and never stalls the frame for long. A hint
  asks `strict` and offers only a step it has proved. The bitmask caps a
  figure at 60 lines.
- **A drag board ejects**: `_wrong_step` lets the finger go (`_drawing`
  false, `_release_post`). Kept down, the next drag after the eject took the
  same wrong step again and cost a second heart (review, probe-confirmed);
  the tap boards this pattern came from cannot do that.
- **Petals** are one mesh rebuilt while they fall, one draw call for the
  shower (a mesh each was up to 125 calls on Insane).
- **Rewards**: daisies on spent posts (`_bloom`, drawn on the cap in the
  figure mesh, folded by `_unbloom` after an undo or eject); the streak;
  ladybugs on judged steps (`_want_bug`, flying in on the life layer, then
  `SnailFace.riders`); gags by `hash(Vector2i(e * 13 + 7, n * 5 + 3)) % 5`:
  0 sunglasses (`Face.glasses`, seated by `SnailFace._face_frame`), 1 love
  hearts off the plank, 2 the mushroom (`_pop_mushroom`, beside the post,
  never above it: the top row would cover the hearts). Hint steps are judged
  right but bring no ladybug.
- **Life layer** redraws one frame past going quiet (`_life_alive`): without
  it a ladybug that had just landed stayed painted where it last flew.
- **Seal** sized off the board's width (`size.x * STAMP_R * 0.75`): sized
  off Easy's short card it came out too small for "Flawless".
- `tests/_shot_oneline.gd -- d=<n> rest|right|wrong|sun|solve|restore|perf [rm]`.
  In zsh, split a mode string held in a variable with `${=args}`; an
  unsplit "d=3 solve" reads as level 3 in rest mode and walks nothing.
