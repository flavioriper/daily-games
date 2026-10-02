# Rings

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Rings is the twentieth card, and the one a merge deleted** (built
  2026-09-20, `puzzles/rings2d.gd`, spec `2026-09-20-rings-flat-design.md`).
  Pinwheel's `merge: main into pinwheel` (`57c8539`) took Pinwheel's side of
  every conflict and dropped Rings' registry entry, card picture, suite line
  and win-harness solver without a conflict marker saying so. The board, its
  state and its tests survived, so it sat built and unreachable for three
  days; it came back on 2026-09-24 from that merge's second parent. The same
  merge also dropped `ui/menu.gd`'s `Ads.banner_changed` inset handler, which
  is still missing. After merging a parallel board, diff the merge against
  **both** parents, not only against the side you were on. On the grid it is
  the eighth card on page two at 1080x1920 (8 % 3 = 2, so one filler), page
  two reads **181** draw calls and the board **58** (47 on Insane).
  **Its Insane is a move budget, not a harder deal**: the screen caps it at
  8 pegs and 6 colours, and less slack (6 on 7, 7 on 8) makes 85-93% of
  deals unsolvable and the survivors *shorter*. So Insane is Hard's deal
  sorted within the **shortest** solve plus `PAR_SLACK` 2
  (`rings_state.gd`'s `par`), shown as "N moves left" under the second row;
  Undo gives a move back, so the budget binds the finishing line and not the
  exploring, and there is no hint, because the game's own depth-first solver
  plays lines of 35-63 against optima of 16-24. The optimum is a
  breadth-first search of 90-600 ms a deal on this Mac, so it is mined
  (`tools/insane/rings_ladder.gd`, `content/insane/rings.json`, optima
  22-26) -- the first board with an Insane bank. Its sounds are wired and
  generated (lift, drop, lock, refused, undo, hint, reset, solved, enter).
  **Polished on 2026-09-25** (the spec's amendment): the rings are donuts with
  the post going into the top ring's hole, drawn through one `_append_peg` that
  the menu card shares; the board lays out in a 1000-wide design box scaled to
  the card, so the win screen shrinks it rather than spilling it; a lock is a
  glint and a gold cap, never a wash; a drop is threaded down its post. 54 draw
  calls bare, 60 played. **Polished again on 2026-09-26** (toward the same
  reference): a paved terrace built once into a third mesh, mossy planks with
  leafy daisy clumps (`_append_plank`, shared with the menu card), wooden
  dowels, and an inlaid emblem per colour in place of the pips (heart, sprout,
  circle, flower, diamond, triangle). A held ring turns on its post, shown by
  its emblem walking round the band; a flight whirls it to the next half turn;
  the lock's cap is a daisy; the solve spins every ring. 56 bare, 61 played. **Fixed on 2026-09-27**:
  a landed flight left its last frame in `_live_mesh`, a second ring hanging
  over the one in its slot (the "double ring"), and every station and plank
  was one mesh of ~30 ms rebuilt on every tap and landing frame (the lag).
  Each station is now its own rest-pose mesh, rebuilt only when what is on it
  changes (~2.7 ms), and whole-station motion is the draw transform: 78 draw
  calls on the animation strip where 72 were, ANGLE agreeing. **Run windowed harnesses with `--always-on-top`**: a
  covered window stops presenting after about 1.7 s and every later shot repeats
  the last frame.
- **Polished on 2026-10-01** (unattended, spec
  `2026-10-01-rings-polish-design.md`). **The move budget and its bank are
  gone.** Hard (now six colours on **seven** pegs) and Insane are judged by
  **dead ends**: `Gen.verdict()` proves a drop leaves the pegs unsortable,
  the ring wobbles, a heart splits and it hops home -- the state never holds
  a dead position. Insane is **Tumble**: six two-tone rings
  (`top | (under + 1) << 3`, plain rings still 0-5) that turn over when
  lifted, mined into `content/insane/rings.json` by
  `tools/insane/rings_tumble_mine.py` (Python, same search and move order);
  no undo, no hints, two hearts. The solver's old "never split a uniform
  peg" pruning was removed because a verdict now costs a heart and must be
  sound. Rewards and party follow Pinwheel (streak, twirl/love/bee gags,
  hoop, nap cat, seal, `RG_CHEER_0..11`); sound is the `TERRACE` style.
  `tests/_shot_rings.gd` plays every mode through the board's input. Peak
  draw calls 110 (the out-of-hearts card on Hard).
- **Checked up on 2026-10-02** (`docs/agents/checkup.md`, row 20). Every
  ring part is a `RunMesh` look made once (`_make_look`, `LOOK_*`) and a
  station or the ring in hand is those looks under the moment's squash,
  lean and turn (`_build_station`, `_put_ring`, `_put_emblem`, `_put_post`);
  `_append_peg`/`_append_donut` still draw the menu card, `_append_donut` now
  in parts (`_donut_body`, `_donut_emblems`, `_donut_face`, `_donut_glint`)
  that the looks share. The judge runs off the main thread from the lift
  (`State.prejudge`, `settle_judge`). The tutorial is
  `ui/hud/rings_tutorial_diagram.gd`, a `Yard` (one row, `_row_counts` and
  `_min_h` overridden, dealt with `State.take`). `tests/_probe_perf.gd`
  plays the solver's line (a lift tap and a drop tap a move) and
  `x=rg_count` times every station's rebuild and the ring in hand.
