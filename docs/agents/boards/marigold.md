# Marigold

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Marigold is the twenty-sixth card** (2026-09-26,
  `puzzles/marigold2d.gd`, `puzzles/marigold_state.gd`, spec
  `2026-09-26-marigold-flat-design.md`, no concept tab -- built while the
  user was away). The pegs-and-launcher game the user asked for, re-dressed
  as a dusk pond garden: the family's sun shoots a seed, every bud it touches
  blooms, bloom every marigold; clovers split the seed, the violet moves, a
  seed in the sliding pot comes back, and the last marigold is a **full
  bloom** (slow motion, a rainbow, five worth-labelled pots). The reference's
  name is written once in the spec to forbid it; **it is called Marigold**.
  Out of seeds the same garden grows back (a try, never a loss). Two things
  travel: **a board whose physics is pure data stepped at a fixed `DT` gets
  an exact guide and an exact hint for free** -- both play the shot on a
  `clone()`, and the hint's 65-angle search (~330 ms here) runs on a
  `WorkerThreadPool` task -- and **`seed` is a global function in GDScript**,
  so a static helper named `seed()` fails to parse where it is called
  (`marigold_parts.gd`'s is `bead()`). Buds are drawn in six strips so a
  bloom rebuilds one. 74 draw calls bare, 76-78 played, 87 in the full
  bloom, 78 on ANGLE. Sixteen sounds generated (2026-09-26), one take a cue,
  awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's amendment): leaf-collared buds, a
  kernel seed that points along its flight, the pond's reflections and a
  moon's road, a garland and lanterns on the arch, a wooden seed trough, pip
  groove and tag; ripples round every bloom, each marigold flying up to its
  pip, picked blooms rising, the sun's recoil, the pot's wobble and catch
  squash, the tag's pop, a rolling score, fireflies and a full bloom of
  falling petals, carried by two small live meshes. 78 bare, 83 played, 91
  in the full bloom, ANGLE agreeing.
  **The last marigold since 2026-09-27** (the spec's second amendment): a
  seed heading for it slows the garden and zooms in under a drumroll, a
  near miss says so, and the hit slams to x0.15 at 2.1x zoom, easing out
  while the seed falls, under Ode to Joy arranged in the house instruments.
  The arrangement is synthesised by `tools/gen_marigold_music.py`, the one
  sound in the game not made by ElevenLabs, because the tune has to be
  exact. **Not synthesised since 2026-10-05** (the user: cozy, never
  synth): the script still sequences the tune, since it has to be exact,
  but every note is now a recorded one -- three ElevenLabs takes in the
  board's own POND_TUNE family (`note_kalimba`, `note_box`, `note_low`,
  `tools/gen_sfx.py marigold`), each measured for its pitch and resampled
  to the score, the way a sampler plays. The parts move by octaves to sit
  near the note each instrument was recorded at; the timpani and the
  glockenspiel are gone. The board never cues the three notes. The view is `_cam`; the HUD never goes through it. 91 in the full
  bloom, unchanged.
  **Rewards made loud on 2026-09-27** (the spec's third amendment):
  Stackwood's sticker and bits kit -- petals, sparks and stars off every
  bloom, a bloom counter under the sun, hopping words by blooms in a shot
  (Nice! to Legendary!), Double!/Triple!/Bouquet!, Points xN!, Caught! with
  the seed flying back to the trough, the shot's points lettered and the
  score kicking, a warm edge glow on a long shot, FULL BLOOM and Jackpot!
  as stickers with coin rain. Stickers are in the card's pixels, never the
  view's. 78 at rest, ~159 at a long shot's peak (+2.6 ms here), ANGLE
  agreeing.
  **Polished again on 2026-10-01** (unattended; spec
  `2026-10-01-marigold-polish-design.md`). Hard (3 hearts) and Insane (2)
  can be lost: a garden run out of seeds, or Reset once a seed has flown,
  costs a heart (on a wooden sign off the arch); out of hearts the sun
  sleeps, dusk, the out-of-hearts card. **Insane is Sweethearts**: the
  marigolds come in ribbon-tied pairs, and one that blooms without its
  sweetheart in the same shot folds back into a bud. Its 160 gardens are
  mined (`tools/mine_marigold_sweethearts.gd`, merged by
  `tools/merge_marigold_sweethearts.py`): every pair is tied out of one
  shot's blooms, so six `proof` shots bloom them all from the opening.
  **A banked shot must ship at full precision and never mirrored**: the
  physics is chaotic, and rounding buds to a thousandth or flipping a garden
  lost every proof (nine significant digits are exact for float32). Gags:
  the frog on the lily pad, the ducks, the sun's sunglasses, the streak; the
  party has the nap cat on the right lily pad and the seal. The POND /
  POND_TUNE sound set (real garden foley, kalimba, music box, hand bells;
  32 cues, a `cut:` flag in gen_sfx for takes that come back doubled),
  unheard. 92 draw calls at rest, 224 at the full bloom's party.
  `tests/_shot_marigold.gd` drives every mode; `tests/_win.gd -- marigold`
  fails, as on `main` before (it cannot aim a seed).
  **The checkup on 2026-10-02**: the lag was script, never draw calls --
  every bud strip a seed brushed past (~3.7 ms each, 50k vertices for all six
  on Insane), the breathing blooms, Sweethearts' ribbons (3.5 ms a bloom), the
  bits, ripples, frog and ducks, the full bloom's pots and the band's pips
  were drawn live. Now buds, blooms, ribbons, the garden's pieces and the
  pots are `RunMesh` looks (a layer a RunMesh sharing one shape cache; looks
  made at the first layout's scale and drawn scaled after a smaller one),
  bits and ripples are meshes of copies with tiled indices, and the looks are
  primed one a frame after the entrance. Native GL Insane play 9.1 -> 4.9
  ms, p95 14.2 -> 7.1. **Undo** takes the last shot back on every band (the
  state's `snapshot()`/`restore()` before each shot; on Hard and Insane it
  costs a heart, as Reset does, and stays grey at one heart so it never puts
  the sun to sleep; it breaks the flawless seal). **The tutorial**
  (`ui/hud/marigold_tutorial_diagram.gd`): aim, the last marigold and the
  full bloom, clover and violet, the pot, out of seeds (a heart on Hard and
  Insane), Sweethearts (Insane), Undo and Reset, the bulb -- a quietened
  board zoomed onto hand-made staggered rows, each shot an exact angle found
  by `tests/_mg_tut_search.gd` (the garden is chaotic: re-run it if the
  physics or the gardens change).
  **Insane counts moves since 2026-10-04** (`docs/agents/flat-screens.md`,
  "Insane counts moves"). No heart here was ever a judgement (one went when
  a garden ran out of seeds, on Reset after a shot, on Undo), and the board
  already had a move counter: the seeds. So the hearts, which only bought a
  second garden, are dormant (`HEARTS_BY` all zero) and the seeds are the
  count: `State.moves_budget()` is the proof's six shots + 3 = **9 seeds**
  (was 8 a try, two tries), one garden, and out of seeds with a marigold up
  is the loss (`_out_of_seeds` -> `_moves_out` -> the old `_run_out`).
  `moves_left` only follows `_state.seeds` (`_count_moves`), so the pot's
  catch and a big shot's seeds still come back; `_spend` is the door for
  anything else (the probe). The pill sits where the hearts' sign hung,
  beside the trough it repeats. No Undo on Insane (a shot back is a seed
  back); Reset is free and is `State.restart()` there, not `regrow()`,
  because a new try moves the violet and the proof was mined against the
  first one's; it costs the flawless seal once a seed has flown. The card's
  video gives `MOVES_BONUS` 3 seeds on the garden as it stands, not a regrown
  one. Sweethearts' fold-back stays: it is the band's rule, seen on the
  field, never the answer. The tutorial drops OUT and UNDO on Insane and
  ends on the shared moves page with `HTP_MG_MOVES_BODY`. Not seen on a
  screen: the pill's place, and the new locale rows wait for an import.
