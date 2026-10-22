# Picket Sums

- **Picket Sums is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  sixth and the first board that is mostly arithmetic (skill Logic). Sudoku
  fenced into garden plots that add up to their tags; Insane is **Lost
  Tags**. Spec `docs/superpowers/specs/2026-10-22-picket-design.md`.
- Files: `puzzles/picket2d.gd` (extends `puzzles/sudoku2d.gd`),
  `puzzles/picket_state.gd` (extends `sudoku_state.gd`: plots, standings,
  clashes in a plot, hint and write aware of plots), `puzzles/picket_gen.gd`
  (fencing, the reasoner, banks), `puzzles/picket_world.gd`,
  `ui/hud/picket_tutorial_diagram.gd` (Sudoku's page with plots: PLOT,
  LINES, LOST, UNDO, HINT), `ui/menu/cards/picket.gd` (extends Sudoku's).
- **Sudoku's board gained two hooks** for it: `_new_state()` and
  `_new_world()`. Anything else Picket changes is an override; a change to
  Sudoku's board reaches Picket's too.
- **The plots' moments are diffed in `_update_stickers`**, the one place
  Sudoku diffs its daisies after every move (place, erase, undo, hint,
  Reset).
- **Hard and Insane are banked** (`content/insane/picket_hard.json`,
  `picket.json`, 120 days each). Re-mine with
  `godot --headless --path . --script tools/mine_insane.gd -- picket 120 160`
  (about 10 min on the Mac). `tests/_probe_picket.gd` re-proves every
  banked day and times each band's setup.
- **Inner-class trap**: the tutorial's `Sheet` extends picket2d.gd, so a
  bare `State` inside it is sudoku2d's const, not the page's; it builds a
  `PicketState`.
- Harness: `tests/_win.gd -- picket` (the bulb, a wrong number into a plot
  and out again, then the answer through the real pad);
  `tests/_shot_picket.gd -- <dir> d=<0..3> [tut=<page>|card]` shoots rest,
  selected, wrong, plot coming right, the win and the reopened day, with
  draw calls (81-84 playing, 148-150 reopened).
