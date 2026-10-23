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
- **The look redone, 2026-10-23** (the user: the card "hard to read ...
  due to numbers and letters"; the board "more elegant and modern, but
  keeping cozy ... should not look like a canvas game"). The dashed
  pickets read as a web page's dashed border: a fence is now one
  unbroken soft line (`FENCE_W` 2.4, opaque `FENCE`), thicker and in the
  state's colour when its plot is selected (sun), right (leaf) or past
  saving (rose). A tag is a small paper pill in the plot's corner with a
  hairline, its number `TAG_WEIGHT` 700 at `TAG_SIZE` 23; selected, right
  or past saving it fills with that colour, number in paper. The panels
  are all plain paper (`_panel_shaded` false: a chequer under the fences
  read as plots of its own) and the cells' rules faint (`THIN_FAINT`
  0.38). Sudoku gained the two hooks `_panel_shaded` and `_thin_alpha`
  for it, defaulting to its own look. The world's fence behind the tools
  row is lower and paler, so the buttons no longer stand on its posts.
  `fence_cell`, `tag_pill`, `tag_rect` and `tag_base` are static so the
  card draws the same fence and tags.
- **The card is one region, 3x3, at a 64 cell** (`ui/menu/cards/picket.gd`),
  four plots (8, 15, 6, 16), the go tile in the 16 holding a 9. The
  nine-by-nine fragment it replaced put its tags over the digits. Sudoku's
  card gained `_trays` and `_panel` for it. Draw calls: card 9, board
  81-85 playing, 148-150 reopened (unchanged). Verdict owed.
- **A solved board keeps its tags paper**, numbers in leaf, fences thin
  leaf: every tag filled green at once shouted over the win. The card's
  done seal stands on the cloth left of the tray's top (`seal_centre`),
  off the 15's tag in the template's corner.
