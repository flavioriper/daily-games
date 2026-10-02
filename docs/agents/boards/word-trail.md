# Word Trail

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Word Trail is the twelfth board, and the first whose signature is a
  drawn path** (2026-09-20, `puzzles/word_trail2d.gd`, spec
  `2026-09-20-word-trail-flat-design.md`, mock
  `docs/brainstorm/concepts.html#wordtrail`). Drag orthogonally through a
  field of letters; every open tile belongs to exactly one hidden word and
  the lengths under the field are the only clue. Only a **right** word
  locks, so nothing wrong can sit on the board and there is no Check --
  which, with no tray, leaves the tip card alone in its bottom slot at 140
  and Reset up in the top bar. **It is called Word Trail and nothing else**,
  in code, in a comment or on screen: LinkedIn ships this game under its own
  name, which the design docs record once each, in order to forbid it, and
  which nothing else may repeat. This is
  the third time the repo has renamed a game it did not invent (Code Break,
  Hidden Word). The wave is its
  motion, and it needed nothing new from `core/motion.gd`: the ribbon takes
  the word's colour from its first tile to its last at `WAVE_STEP` a tile,
  `_front(i, t)` is the one truth four things read (which tile wears the
  colour, how far the ribbon is drawn, which slot box is lit, which letter
  has arrived), and Undo and Reset run the same wave backwards. Its only two
  motion constants are `WAVE_STEP` and `BEAM_TIME`. Since 2026-09-25 a trace ticks (`select`,
  pitch climbing with length) and is spelt into the smallest unfound slot it
  fits (`_preview_slot`), stepping up a size as it grows. Its band is Hidden
  Word's, appended to the board's own builder rather than mounted as a
  `Scenery` node, so it is one draw call. Measured on this Mac with
  `tests/_shot_anim.gd -- wordtrail` at `--resolution 810x1440`, 2026-09-20:
  **65, 62, 65** draw calls over three runs with one word locked (the 62 is
  the outlier of the three; the likely cause, inferred from the timings and
  not measured, is the lock's ring and sparkles dying just as the idle
  window opens), **60/61** bare, **61/61** under reduce motion, and idles of
  2.51/2.49/2.51, 2.40/2.39 and 2.40/2.37 ms. Queens (71, 71) and Hidden
  Word (110, 110) were run as controls in the same session and came back
  exactly as recorded above, which is what makes those figures worth
  quoting. On the phone's driver (`--rendering-driver opengl3_angle`): the
  same **65** twice, and the settled frame matches the default driver to
  5/255 on four pixels -- edge antialiasing, no `instance uniform`. The
  reduce-motion pair 1.5 s apart is pixel-identical again.
- **The polish pass** (2026-09-30, spec
  `2026-09-30-word-trail-polish-design.md`) made Hard and Insane losable
  and gave Insane a rule of its own. A **dandelion** on the band holds the
  wishes (Hard 7, Insane 5, `State.WISHES`); a wrong trail blows a seed
  away only when it could have been a word (as long as a hiding word, three
  tiles or more) and was never tried (`State.could_be`, `State.miss`,
  `tried`), and letting go off the field puts a trail down free on every
  band. The last seed droops the tiles and brings Code Break's
  `out_of_rows.gd` card in `WT_OUT_*` keys (placement `"wish"`): More
  wishes (three, once) or Show the words (`State.reveal_next`, a paler
  ribbon, `finish_unsolved()`; `is_solved()` is false with any shown word).
  Hints are 3/3/1/0 by band. **Insane is Night Walk**: the field is dark,
  walls and tiles alike, a lantern (Untangle's `LanternFace`) lights the 3x3
  round the finger with an afterglow, found words light their neighbours for
  good, and the solve brings the dawn. Rewards: a note up the scale per word,
  a bubble (big, quick, a streak), a gag (hearts, conga, butterfly, twirl),
  and a party (dance, a flower on every wall, the stage with a cheer, the
  seal by plausible misses). Every cell has one pose (`_cell_pose`) and a
  tile adds its own (`_tile_xf`, with a turn its glyph follows).
  `tests/_shot_wordtrail.gd` drives every scenario; peaks 82 to 111 draw
  calls on `opengl3_angle`.
- **The board checkup** (2026-10-02, `docs/agents/checkup.md` row 12). The
  field and the slots are put together by `ui/flat/run_mesh.gd` from shapes
  made once (`_shape`, `_slot_shape`) into runs laid in paint order
  (`_lay_runs`: sky, cells, ribbons, beam, glows, flowers, lantern pool);
  a whole ribbon is its word's shape, a ribbon mid-wave, its glint and the
  beam are drawn live into their run. The shapes are made at the first
  layout (`_ref_cell`, `_ref_origin`, `_ref_q`) and drawn scaled after a
  smaller one, remade for a bigger. `_tile_xf` is memoised a frame. The
  tutorial (`ui/hud/word_trail_tutorial_diagram.gd`) is the board itself,
  quietened, on a fixed 4x4 of three words from `HTP_WT_WORDS` (a four, a
  four, a five in the player's language), with the slots in a column beside
  the field through the layout hooks `_slots_wide`, `_slots_left`,
  `_puff_foot`, `_puff_height`, `_lamp_rest`.
