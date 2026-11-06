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

## The daily theme (2026-11-06)

The bank word boards' wave: the day's sampler holds a theme word, and
stitching it puts a sun on the frame.

- **The deal**: on a daily dealt from its day (never New, never the
  tutorial's sampler) `State.deal` takes `ThemedPictures.theme_pool` and
  runs `bank_pick` over the band's bank, dealing the sampler that holds the
  strongest theme word. Only words the player must stitch count
  (`State._open_words`): one of Easy's two given words would never be
  stitched, so a sampler that gives the theme word away is not picked for
  it (with the fixture, Easy en picks `smoke` over the given `flame`). No
  hit, no pool (an unstarted backend, every harness's real path): the
  bank's turn as ever. Samplers and their fewest are never changed.
  Fixture hits: en flame/smoke/ember, pt pedra/cesta, es llama/fuego/brasa,
  every band.
- **The teaser**: a gold French knot with a thread's tail on the frame
  before the theme word's first letter (left of an across word, above a
  down one). It says which line is the day's, never what it spells.
- **The reward**: when the word is stitched whole its gold border is sewn
  as ever, with a rose thread in the gold's gaps (`Art.border`'s colour and
  dash share; no patch colour changes, so no state is a shade of a patch's
  own colour), and over the last 45 % of the needle's run the knot opens
  into a sun cross-stitched on a little round of linen pinned to the frame
  (`Art.sun`, SUN_K 0.34 of a patch): eight X-stitch rays, sun and rose,
  round a gold eye. As the needle ties off (SEW_TIME after the sewing
  starts): the `theme` cue, a sparkle and a ring at the sun. The say line
  toasts `CS_SAY_THEME` ("Today's word: SMOKE!") in place of the plain
  "SMOKE stitched!". All of it lives in the borders mesh: no new draw call
  once a word is sewn (one while only the knot shows).
- **The win**: stitched before the last swap, the word's five patches hop
  again one by one (THEME_STEP 0.07) THEME_AT 0.9 s after the wave starts,
  with the `theme` cue up a step, a sparkle at the sun and the toast;
  stitched by the last swap, its sun coming out is the beat and the toast
  replaces "A perfect sampler!". `win_delay` adds THEME_HOLD 0.7 (2.3 s).
  Subtitle `CS_WIN_THEME` ("Today's word: Smoke. %s", the plain line kept
  after it). A reopened themed day shows the sun. `day_dict` says
  `"source": "theme"` and `"theme"`: the word as the bank writes it
  (accents). Reduce motion: the sun is simply out, no hop.
- Draw calls, opengl3_angle 810x1440, `theme`: Easy en 122-131 play, 93
  in the win's hop, 186 on the card; Hard en 119-131, 186; Medium pt
  122-131, 186 (as before the theme).
- Harness: `tests/_shot_crossstitch.gd -- <dir> d=<n> theme [lang=pt|es]
  [pool=<json>]` hands the deal the fixture's words through the board's
  static `theme_pool_override` (set before the board opens, so the
  reopened day deals the same) and adds `theme_sewing`, `theme` and
  `won_theme`. `tests/_win.gd -- crossstitch` FAILs: it has no Cross
  Stitch solver (none of the five word boards has one yet), theme or not.
- Sound: new `theme` (the wrap climbing to the octave and a third, as
  Pie's). The rest of the set was checked against "The house sound" and
  is all bank pops by their jobs; nothing changed.
- Owed: phone, ear (the theme cue unheard), pt/es read by a native
  speaker, the night's `words.theme` deploy (until then the pool is
  Hidden Word's and Word Trail's picks and the pictures' names).
