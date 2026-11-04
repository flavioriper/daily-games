# Cross Stitch

- **Cross Stitch is a Puzzles card (2026-11-04)**, the first of
  `docs/roadmap-word-boards.md`, under Words, after Four Shelves. Six
  five-letter words cross on a sampler (three across, three down, four
  holes); their 21 letters are sewn on in the wrong places; swap two at a
  time until every one is stitched within the band's swaps. Spec
  `docs/superpowers/specs/2026-11-04-cross-stitch-design.md`. Id
  `crossstitch`, prefix `CS_`. Built unattended at the user's word, with no
  concept tab first.
- Files: `puzzles/crossstitch2d.gd`, `puzzles/crossstitch_state.gd`,
  `puzzles/crossstitch_world.gd`, `ui/faces/crossstitch_art.gd` (patch,
  linen, frame, flower, border, needle, spool, cushion),
  `ui/hud/crossstitch_tutorial_diagram.gd`, `ui/menu/cards/crossstitch.gd`,
  `tools/build_crossstitch.py`, `content/insane/crossstitch*.json`.
- **The banks are the only source**: `tools/build_crossstitch.py` sweeps
  Hidden Word's answers (folded as the keyboard folds; ñ kept) for six words
  agreeing on the nine crossings, each word in at most `WORD_CAP` (14)
  samplers, then shuffles each to exactly the band's fewest swaps, solved
  exactly. A change to Hidden Word's answers wants a rebuild.
  pt/es Easy and Medium hold 132-187 samplers (repeat after ~5 months).
- **The fewest is solved, not assumed** (`State.fewest_from`: misplaced
  letters less the most rings of the letter graph, memoised). Checked
  against a brute-force search in Python and against every banked `min` in
  GDScript (`tests/_probe_crossstitch.gd`: 0 mismatches over the twelve
  banks, ~0.2 ms a sampler, worst 1.2 ms). The bulb's swap always cuts the
  fewest by one, so a bulb-only solve takes exactly the fewest.
- **A swap is final**: no Undo, the bin greyed (`can_reset` false). The
  bulb's swaps are free (`helped`), and do not count against the stars;
  they do count in `quality()`.
- **Stars** on the pill read `used + to_go` against the fewest (3 at it, 2
  within `STAR_TWO`, 1 after). The pill's swaps-left goes red at two.
- Out of swaps: `out_of_hearts`, `out_of_rows.gd` with `CS_*` keys and the
  `row` placement, Three more swaps once a day (`State.MORE`), Show the
  sampler ends it with `finish_unsolved`.
- Harness: `tests/_shot_crossstitch.gd -- <dir> d=<0..3> [out|tut=<page>|card]`.
  Draw calls (opengl3_angle, 810x1440): 121-131 in play, 186 on the win.
- Owed: the user's eye and ear (every cue unheard), a phone, pt/es read by
  a native speaker.
