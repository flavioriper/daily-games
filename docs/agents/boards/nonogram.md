# Nonogram

Board notes (the flat spec `2026-09-18-nonogram-flat-design.md`, its
amendments 11 and 12, and the polish spec `2026-09-30-nonogram-polish-design.md`
hold the rest).

- **The polish pass (2026-09-30)**, unattended, One Line's pattern. Shapes
  are drawn per band from `Gen.SHAPES` (squares, tall and wide) with the
  day's rng before the picture, so a completed day restores the same shape.
  Hard 3 hearts, Insane 1: every tile is judged as it lands, a stroke stops
  at the first wrong one, which blushes and after `EJECT_AFTER` turns out to
  a **locked pebble** (`state.reveal`, dropped from the history like a
  hint's tile). Finished lines lay their pebbles on Hard and Insane in the
  same history entry (`state.apply_more`). Check there looks at pebbles.
- **Leaf Fall (Insane)**: tumbled lines (`state.tumbled`, rows then columns;
  `Gen.reads` compares the multiset). Numbers drawn largest first on leaves;
  leaves live in the floor mesh, numbers are draw_string through the same
  `_line_xf * Transform2D(rot, at)` (`_numbers`). The bank is
  `content/insane/nonogram.json` (`w`, `h`, `bits` row-major, `leaf` rows
  then columns); `Gen.Deep` is the proof and must stay one instance a thread
  (the old static `_line_cache` is not safe in the miner's threads).
  Re-proved 160/160; with the order put back Hard's solver finishes 150 of
  them, so the rule is the difficulty.
- **Life** is three full-rect layers (`Hearts`, `Life`, `Combo`) as on One
  Line; the mushroom and the queen bee (`ui/faces/bee_face.gd`) are nodes.
  The frame, daisies and leaves are in the floor mesh. Peaks 90 at rest on
  Insane, 117 at the party, 50 under reduce motion (ANGLE).
- `tests/_shot_nonogram.gd -- d=<n> rest|right|wrong|solve|restore|perf [rm]`;
  in zsh pass the args through `${=args}` or they arrive as one word.
