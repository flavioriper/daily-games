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
- **Insane counts moves again, 2026-10-04** (`docs/agents/flat-screens.md`,
  "Insane counts moves"). `HEARTS_BY` is all zero, so `judged` is false on
  every band: no dead-end verdict, no wobble and hop home, no heart, and the
  worker judge never starts (`would_doom`, `prejudge`, `_doom` and the hearts
  are left in place, asleep). Tumble stays and gets the budget back, on the
  shared pill where the hearts sat: `State.moves_budget()` = the deal's
  **shortest** solve + max(3, a quarter of it, rounded up), a drop on another
  peg costing one and a put-back none (`_spend`). The shortest solve is
  `grade.par` in `content/insane/rings.json`, written by a breadth-first pass
  added to `tools/insane/rings_tumble_mine.py` (the same 180 deals, re-run
  in 70 s; a Tumble deal's whole graph is only 400-3500 positions, so the
  optimum is cheap, unlike the plain deals' of 2026-09-24). Par runs 19-46
  (mean 30) against the DFS line's 19-70, budgets 24-58. Without the bank
  the budget stands on the DFS line, a known solve and not the shortest. No
  Undo, Hint or Check on Insane (`capabilities()` is empty); Reset and Try
  again hand the whole budget back, the card's video five moves. A dead end
  is now the player's to notice: the stuck toast still shows when nothing
  can move (it reads the pegs, as on Medium), and its words still offer an
  Undo that Insane does not have. Not updated: `RG_LVL_3` ("two hearts") on
  the level picker, `tests/_shot_rings.gd`, the tutorial diagram's dormant
  HEARTS lesson. Not seen on screen: only headless checks were run.
- **Sounds redone on 2026-10-10** against the cozy rules (`docs/agents/sound.md`,
  the `rings` row): the set is no longer `TERRACE`'s. At the board: the
  streak's `combo` climbs a semitone a step, five in all (`COMBO_STEPS`
  `[-2, -1, 0, 1, 2, 3]`; it was `[-5, -3, 0, 2, 4, 7, 9]`, fourteen), and
  `lift` and `drop` play at 0.94 to 1.06 at random (the doomed drop's 0.9
  stands). Measured, not heard.

### The terrace is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/rings_world.gd` is the sunny flagstone
terrace the board drew inside its card, edge to edge under a cream
morning light at the top, with leaf shade at the sides, two fallen leaves
and a daisy in the gap of the tools row, and at the foot three bushes, a
short spare plank with a stub peg holding two rings, a lone ring on the
stones and fallen leaves; seven pollen motes breathe. The spare rings have
no emblem and are half size. The board paints its own shapes into the
world's mesh through a `painter` callable. Everything hangs from one
`_box` (the span on the host's margin, at scale `_s`); the rows hang
from its top and leftover height goes three tenths between them.

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 83 draw calls at rest; `tests/_win.gd --
  rings` passes once its taps are mapped through `_box` and `_s` (a
  station is in design space; unmapped, the first tap fell on the level
  card and changed the level).
- Decided for the user, unconfirmed: the terrace, not the card's blush
  wall; 147 of air over the first row for the lifted ring. Owed: a phone,
  Insane with its move pill, the level slide.

### A move carries the run; Insane is Hidden (2026-10-16)

The user, with three screenshots of a nut-sorting game: "when user move a
color, all following same color go with it till there is no more room or
pieces ends. Remove the insane double color logic and add this complexity
instead, making insane for being bigger, more color and with hidden colors".
Built straight in Godot (no concept tab: the reference set the rules).

- **The run.** A tap lifts every face-up ring of the top colour lying
  together (`Gen.run`); a drop lands `min(run, room)` of them and the rest
  thread back down their own post beside the flight. A move is still
  `(from, to)` for the solver -- what it carries is the position's
  (`Gen.take`, `Gen.apply`/`unapply`) -- and `(from, to, carried)` in the
  state's log (`Vector3i`). The hand is `held: Array`, bottom ring first.
  The solver prunes a whole-peg run onto an empty peg and tries only the
  first empty peg (both sound).
- **Insane = Hidden**: eight colours on ten pegs (two rows of five; the
  design box widens to 1236 and the board scales to ~0.81), every ring under
  a top dealt face down (`Gen.HIDDEN`, bit 8 over the colour). A face-down
  ring is a slate ring with a question mark (`VEIL`, `Emblem.QUESTION`),
  never a shade of its own colour. It turns face up for good when it is a
  peg's top (or its peg locks): `_reveal_at` squashes it to its edge and
  opens it face up, on the old `tumble` cue. **A run stops at a face-down
  ring**, and the solver plays by that rule, so a deal is proved under it
  and a hint never lifts what the player could not. Undo and Reset never
  turn a ring back down (Reset keeps the face-down count of each peg's foot:
  a face-down ring has never moved). Measured on the Mac over 40 seeds:
  Insane deals 6.6 ms mean, 25 ms worst; the solver's lines 25-48.
- **Gone**: Tumble (two-tone rings, `flip`, the somersault), its bank
  (`content/insane/rings.json`) and miner (`tools/insane/rings_tumble_mine.py`),
  the dormant judge (`would_doom`, `prejudge`, `_doom`, the wobble) and the
  tutorial's HEARTS lesson. Insane has Undo and the bulb like the others;
  no band counts moves (`MOVES_SLACK` all zero, as it already was).
- Two new colours, a leaf green with a star and a lemon with a square
  (`RING_COLOURS`, `EMBLEMS`, `SHARE_GLYPHS`); the seal reads Hidden.
  Sound: a drop is a run of `drop` pops a ring a step (`_pops`).
- Tutorial: LIFT moves a run of two; SORT locks with runs; HIDDEN (Insane)
  lifts off face-down rings. Locale rows en/pt/es rewritten, Tumble's and
  the doom's rows removed.
- `opengl3_angle` 810x1440 Insane: peak 87 draw calls over a run move
  (`tests/_shot_rings.gd -- d=3 run`, a new mode; the harness's taps now add
  `_box.position`). Suite 248464 passed 0 failed.
- Decided for the user, unconfirmed: ten pegs at cap four rather than
  taller pegs; the run stopping at a face-down ring; leftover rings going
  home rather than staying in the hand; reveals kept through Undo and
  Reset; the slate-and-question-mark look; leaf and lemon as the new
  colours. Owed: a phone, the sound heard.
