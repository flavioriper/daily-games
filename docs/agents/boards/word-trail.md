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
