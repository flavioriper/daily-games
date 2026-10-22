# Hosepipes

- **Hosepipes is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  eleventh, a path board under Space. Taps and flowers on a raised garden
  bed; drag a hose from each tap to its flower, hoses never share a square,
  and every square must be watered. Spec
  `docs/superpowers/specs/2026-10-22-hoses-design.md`. The id is `hoses` and
  the locale prefix `HS_` (`HP_` is Horse Pen's).
- Files: `puzzles/hoses2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/hoses_state.gd` (hoses, strokes, cut and grow-back, Undo, the
  bulb's hose), `puzzles/hoses_gen.gd` (the deal, the solver, the bank's
  encoding), `puzzles/hoses_world.gd`, `ui/faces/hoses_art.gd` (soil, frame,
  hose, tap, flower, seed, halo, the pair marks and the colour order),
  `ui/hud/hoses_tutorial_diagram.gd`, `ui/menu/cards/hoses.gd`; the miners
  `tools/insane/hoses_ladder.gd` (Insane) and `hoses_hard_ladder.gd`.
- **The deal grows hoses, it never cuts a walk**: every square a hose of
  one, neighbouring ends joined shortest first, never so a hose runs
  alongside itself (`_grow`, `_touches`). Pieces of one random walk nearly
  always ran alongside themselves and were almost never unique.
- **The proof is uncapped and pruned** (`Solver._ok`): an empty square
  with fewer than two ways in, an open hose with no move, a patch of empty
  ground no open hose can both enter and finish in, a seed nothing can
  reach. Change a rule in `hoses_state.gd` and the solver must change with
  it: the win is exactly what the deal proves (every flower joined and
  every square watered).
- **Hard and Insane are banked** (240 and 225 days, `InsaneBank`), Easy and
  Medium dealt on the phone (365 days each, none failed, worst 37 and 134 ms on
  the Mac; the same seed deals the same bed, the probe checks it). A day that
  stalls is dealt again from seeds its own rng hands on (`State.deal`). Re-mine with
  `godot --headless --path . --script tools/mine_insane.gd -- hoses_hard 240 280`
  (and `-- hoses 240 300`); `tests/_probe_hoses.gd` re-proves both banks.
- **A stroke keeps its start** (`_before`): every step the other hoses are
  that start cut at the first square the live hose holds, so a cut grows
  back when the finger backs off. `end_stroke` turns a hose of its end
  alone into no hose, so a press and lift on a tap is no stroke.
- **The drag is walked a square at a time** toward the finger, the longer
  axis first and the other when that is refused (`_drag`); a finger slid
  back over its own hose cuts it there (`back_to`). A refusal sounds once a
  square under the finger (`_refused_for`).
- **Meshes**: the frame and soil are one mesh keyed by the watered squares,
  the hoses one keyed by the hoses, the ends one rebuilt only while one
  moves (shapes laid in by `_put`, never a mesh a piece). The head's halo is
  kept as a member: a mesh made in `_draw` and dropped is freed before the
  frame renders ("Parameter mesh is null").
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram drags with `demo_press`, `demo_move` and
  `demo_release`. Lessons JOIN, WATER, CUT (a straight run from another tap
  into the first hose, `run_into`, and back), SEEDS (Insane only, a fixed bed
  from the bank, never today's, which would spoil the answer), HINT.
- **Draw calls**: 78-93 in play on Medium, Hard and Insane (ANGLE agreeing
  on Hard), 141-144 on the win with the report, 85 a tutorial page, 8 on
  the card.
- Harness: `tests/_win.gd -- hoses` (real touches: bare soil pressed, the
  longest hose drawn, another tap dragged across it and back (cut, grown
  back, no stroke counted), a stroke and its Undo, the bulb, then every
  hose); `tests/_shot_hoses.gd -- <dir> d=<0..3> [tut=<page>|card]` shoots
  rest, drawing, cut, joined, undone, hinting, hinted, midway, the win and
  the reopened day.
