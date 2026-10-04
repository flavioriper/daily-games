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
- **Sunny Spells** (`content/insane/oneline.json`, 187 figures, rungs 968-995,
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

### The checkup (2026-10-02)

Board 8 of the per-board checkup (`docs/agents/checkup.md`).

- **The lag** was script, not draw calls: `_build_figure` built the whole
  figure in GDScript on every frame anything on it moved -- 16-20 ms for a
  45-line Insane figure (`x=ol_count`), so the play window ran at 23 ms a
  frame and each step's own rebuild was a 17 ms hitch. Now `_cast_figure`
  puts one indexed mesh together from pieces:
  - every piece -- a post's glow, shadow, drum, cap and daisy, a line's
    shadow, stone and plank -- owns a run of vertices sized at layout for
    its largest look (`_slot`, laid out by `_lay_slots`, which builds every
    piece once: the old frame's cost, paid at open); a look is made once
    (`_looks`) with its indices offset to its run, and copied in natively;
  - a piece that only pops, hops, sinks, shivers, bumps or wobbles is its
    cached look under a transform (`_about`, `_line_pose`; an arriving
    line's fade is one of `FADE_STEPS` cached steps); only a piece whose
    colours move -- a blushing stone, a pressed or blushing drum, a warming
    cap, the plank being laid or blushing or brightening -- is built in
    script (`_show_live`), into its own run; Reset's falling planks go on a
    tail after every run;
  - the figure builds one frame past the motion (`_settling`), so nothing
    is left a step short, and the entrance now covers the lines' fade, so
    the looks are made while it plays and not on the first touch.
  Tried and dropped: a flat triangle list (FlatBuilder style, one native
  copy a piece, no indices) was four times the vertices and drew 1.3 ms a
  frame slower on a full figure at rest (`SurfaceTool.index()` on it: 30-40
  ms, no use); one MultiMesh per look was 65 more draw calls and 3.5 ms
  worse at idle; offsetting every index in script each frame is 6 ms.
- **What changed to look at**: the sparkles of a sunny line at rest no
  longer twinkle (they only ever twinkled while something else moved); a
  line arriving stretches along itself with its caps, rather than keeping
  their size.
- **Readings** (angle, 810x1440, second of two, `tests/_probe_perf.gd`,
  the planted walk as one drag): Insane play 23.1 -> 9.3 ms, p95 26 ->
  10.4, the per-step hitch 17 -> ~3 ms (the Sunny Spells judgment is ~2.5
  ms of what is left); idle unchanged (8.6 ms, 90 draws); near-full Insane
  idle 8.8 vs 8.7 ms before (alternating runs), play 11.7 -> 10.1 ms, p95
  28 -> 12.5; d=0..2 idle 6.1-6.9 ms, play 7.5-8.6. Draw calls unchanged
  (one mesh, as before). The ~50 ms spike after the solve is the host's
  win card.
- **Tutorial**: `tutorial_pages()`, five pages (one stroke, the green
  posts, never twice, stranding, the hint), the fourth teaching hearts on
  Hard and Insane, and a sixth on Insane (Sunny Spells), each a little
  house of eight lines on six posts walked by a quietened board through
  its own input (`ui/hud/oneline_tutorial_diagram.gd`, its `Walk`
  subclass: no sound, tips, gags, ladybugs, streak, solve or
  out-of-hearts card). `State.load_figure()` deals it a figure by hand.
- Undo, Hint, Check, Reset and the shared ? were already on every band.
  Suite 122403 passed, 0 failed; `tests/_win.gd -- oneline` PASS.

### Insane counts moves (2026-10-04)

`docs/agents/flat-screens.md`, "Insane counts moves".

- `HEARTS` is all zero and Insane's hint count is 0: no step is asked
  `step_leaves_finish` on a counted board, so the wrong-step blush, the
  heart and the eject are dormant (`_wrong_step`, `_eject`), and the
  Sunny Spells search no longer runs per step (~2.5 ms a step saved).
- **The budget** is one move a line plus a quarter, three at least
  (`State.moves_budget()`: 46 lines -> 57, 39 -> 48). Any finished stroke
  is exactly as long as the figure, so the base is exact.
- **Surprise: without a way back the counter could never run out** -- a
  stroke cannot be longer than the figure. Insane has no Undo, so the
  take-back is by hand: **stepping back onto the post she just came from
  takes the last line up** (`State.came_from`, `_take_back`, the Undo
  animation) and costs a move, as walking it did. On the other bands that
  gesture is still the "already walked" shiver. `REACH` (0.42 of a step)
  leaves a dead band between two posts, so a finger resting between them
  does not flip back and forth.
- **What Insane no longer shows**, because each was the board working the
  figure out for the player: stranded lines turning grey (`_cast_figure`'s
  `lost`), the strained snail and the sprout's stranded lines, the warning
  buzz, Check, and a streak that grew only on steps a walk still finished
  from. The streak, the gags and the daisies now come on every line laid,
  so they say nothing; no ladybug (it marked a judged step). Kept: the
  "already walked" shiver and Sunny Spells' own refusal and faded lines,
  which are the rule.
- No STRAND and no HINT page in Insane's tutorial; the ONCE page reads
  `HTP_OL_ONCE_BODY_MOVES`, and the shared moves page closes it with
  `HTP_OL_MOVES_BODY`. The rules close on `OL_RULES_MOVES` (the shared
  `RULES_MOVES_SEQ` says there is no taking a move back). All three are at
  the end of `locale/boards.csv`.
- Not seen on a screen yet (`tests/_probe_moves.gd -- id=oneline`);
  `tests/_shot_oneline.gd`'s `wrong` mode describes the old behaviour.
