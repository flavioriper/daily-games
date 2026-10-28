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

### The peach morning is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/word_trail_world.gd` is the card's peach
sky with the sun behind the wordmark, a cloud and two leaves in the gap of
the tools row, and at the foot two far hills, a trail of six paper
stepping tiles winding between them, turf edge to edge with bushes,
flowers and two spare tiles; seven pollen motes breathe. The board's old
rounded turf plate is gone: it tells the world its ground line
(`set_ground`). The field is on the host's margin, the slots under it.

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 83 draw calls at rest; `tests/_win.gd --
  wordtrail` passes; `tests/_probe_level_slide.gd -- wordtrail` slid
  Medium to Hard over one still world.
- Decided for the user, unconfirmed: on the win the block is about two
  thirds its size (it includes the band where the cheer card stands);
  Insane's night stays under the field only. Owed: a phone.
- **A themed day's words** (2026-10-14, the daily theme's stage 3,
  `docs/agents/days-dashboard.md`): every band's daily writes a path the
  first unused word of its length out of `ThemedPictures.words(daily_key,
  "wordtrail")` that its bucket holds, drawn after the random pick so the
  grid and the other words are the day's as without a theme.
- **No word on two bands of a day** (2026-10-15, the user: "there is a lot
  of repeated words accross difficulty, when generating the words let's
  make sure to generate unique words for each difficulty"). The themed
  words were taken first-unused on every band, so the picnic day (20261014)
  dealt cup, cake, candy and basket on Easy, Medium and Hard alike; and with
  no theme a year of days repeated 42 words between bands (the eights of
  Hard and Insane). `_write` now keeps the bands apart by rule, each still
  built alone from its own seed: a band's random words are its own fourth
  of the bucket (index % 4 == band), never one of the theme's, and its
  themed words of a length start after the ones the bands below take (one
  a path of that length, `BANDS`). Measured: the picnic day deals cup cake
  candy basket / mug bread picnic cupcake / grape teapot / none themed; a
  year unthemed repeats 0. Every day's deal changed (the random words come
  from a quarter of the bucket). The theme's lists are three a length, so
  Hard sees few themed words and Insane mostly none: the server's ask
  (`words.ts`) would need more a length to feed every band, which is a
  `publishDay` deploy and the user's to run.

- **No character (2026-10-27, `feat/peeplet-brand`).** The sprout is gone
  from the board and from its card (`ui/faces/sprout_face.gd` is deleted; the
  spec gives Word Trail no character, its pieces are marks). The stage on the
  band is the card alone (`STAGE_X` 0, so it starts at the field's left edge,
  where the sprout's room used to be); the cheer, the seal and the rise are as
  they were. The card's picture is the field, centred.

### The day's shape, a two-step bulb and a voice (2026-10-28)

The user: "make word trail and hidden word experience way better to play,
and game itself way funnier to play, right now nobody likes it", then "let's
try to add some different shapes based on daily theme on word trail to
avoid being just boring squares (use as reference the paper planes)". Read
against the theme-grid games (a word's tiles lit before its order, a right
word never silently refused).

- **The field is the day's thing.** `State.shape_for` takes the themed
  picture (`ThemedPictures.picture`, Paper Planes' `SHAPE_SIZES`) when it
  cuts for every band, else one of the bank's single things that does
  (`shared_shapes`, 16 of Pixel Garden's 10/12 things), picked by
  `Daily.fnv1a("trail_shape|<day>|<step>")`, so a day's four bands are one
  thing on every phone. `fit_shape` cuts it with `PlanesState.cut_shape`
  into the smallest square box from the band's square up `SHAPE_GROW`
  (never past `SHAPE_MAX_N` 10 across) that holds the band's letters plus
  `SHAPE_SPARE` walls, fills at most `SHAPE_FILL` 0.86 of the box and is
  one piece. Paths grow only inside it (`inside()`); the rest of the box is
  void, never drawn, off the field for a let-go. A shape the walks cannot
  fill in `ATTEMPTS` falls back to the square, so a day always deals.
  Forty seeds a band (`tests/_probe_wt_shape.gd`): shaped 39/40/40/36,
  boxes 5-7 / 7-9 / 8-10 / 9-10, walls 5.0/4.9/8.7/8.7, worst build 29 ms.
- **The field wears the picture.** A tile's face goes `PICTURE_WASH` 0.34
  to its colour family (`Pal.PG_BEADS`), its lip deeper; a wall a breath of
  it; a grey or white family stays near paper (a grey tile reads as one
  switched off). Found words keep their own colours and ribbons.
- **Laid by the shape's bounds** (`State.used`, `_used_box`): the cells are
  sized by the bounds, never taller than the band's own square would stand
  (so the slots and the band keep their place), centred, the night pond
  round the bounds.
- **The toast.** The host stopped reading `tip_line()` with the level
  cards, so "You tried that one already" and the wishes left were said to
  nobody. `_tell` puts a line in a dark pill (Sudoku's) just under the
  slots: the day's thing as the field comes in (`WT_SHAPE`), the wishes
  lines, the hint's and the next.
- **The right word on other tiles is never a miss** (`spelt_elsewhere`):
  "HOOD is right! It hides along other tiles.", free on every band (it
  used to unwind silently, and on Insane cost a wish).
- **The bulb is two steps a word** (`HINT_STEPS`): the first lights every
  tile of the shortest unfound word softly, in no order ("These 4 tiles
  hold one word"), the second its start in full. `HINTS_BY_BAND` unchanged.
  `HTP_WT_HINT_*` and the two captions say so; the tutorial's two presses
  read as before.
- Level lines `WT_LVL_0..3` drop the grid sizes (and Hard's stale wishes).
- Verified: suite 303252/0; `_win.gd -- wordtrail` PASS; `_shot_wordtrail.gd`
  `rest`, `words`, `solve`, `out`, `restore`, new `hint` and `elsewhere` on
  opengl3_angle, draw calls 82-101 peak.
- Decided for the user, unconfirmed: the tint strength; a bank thing (not
  the theme's) on days with no themed picture; the shape named by a toast,
  not on the card. A 6-10 cell silhouette is blocky: the colours carry the
  thing more than the outline. Owed: a phone, a themed day seen.
