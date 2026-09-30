# Light Up

The flat board's history before 2026-09-30 is in
`docs/superpowers/specs/2026-09-18-lightup-flat-design.md` (and its
amendment) and in `docs/agents/flat-screens.md`.

### Failing, Cat Naps, rewards, motion and sound (2026-09-30)

Spec `docs/superpowers/specs/2026-09-30-lightup-polish-design.md`, built
unattended on `feat/lightup-polish`, following Shikaku's and Tents' passes of
the same morning. The names and the shape of the code are Tents' on purpose
(`_judge`, `_break_streak`, `_draw_combo`, `_gag`, `_glance`, `_perches`,
`_want_flies`, `_spawn_fly`, `_fly`, `_draw_life`, `_party`, `_draw_stamp`),
so the game fails and celebrates one way.

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`), on the shared pill in a
  `HEART_ROW` strip over the court. A heart goes only on a lamp that
  `state.lamp_fair` passes (no lamp in its sight, no block or cat pushed over)
  and that is not the answer's. The lamp worries, sags, its flame gutters
  (`CourtLantern.gutter`, a transform on the glow) while its light draws back
  along the beam stone by stone, and `_eject` takes it up through
  `state.undo()` with a soft `strike`. Everything waits on `_ejecting`;
  `busy()` holds the host's hint video. Out of hearts: the court slips to
  dusk, lanterns and cats nod off, the moths leave, and
  `ui/hud/out_of_hearts.gd` comes up with `LU_OUT_BODY`/`_REST`. Insane has
  one hint.
- **Insane is Cat Naps**: banked 10x10 courts (`content/insane/lightup.json`,
  200 boards, rungs 17-24, mined by `tools/insane/lightup_ladder.gd`). A cat
  (`Gen.CAT + n`, `ui/faces/nap_cat.gd`, the kitten curled on a cushion) wants
  exactly n lamps shining on her: 0 napping, 1, or 2 greedy. Light passes
  over her; no lamp or chip goes on her stone and it needs no light. A court
  is kept only when it has more than one answer with the cats' numbers
  ignored. An empty bank falls back to the old band 3 (8x8, no cats).
- **Right lamps**: `_judged` (a tap judged fair and the answer's, and every
  hint lamp) is the only thing a reward may hang on. On Hard and Insane a
  judged lamp goes JOY, its candle flares (`CourtLantern.flare`, the halo
  swelling as a transform, plus the floor's wick disc and a sparkle) and a
  moth comes to circle it. Easy and Medium get no flare and no moth before
  the party: without hearts nothing has judged the lamp.
- **Blocks hop** (`CHEER_HOP` of a cell, with a leaf sparkle) the moment
  their number is met (`_cheer_blocks`, a diff of `_met_blocks`), and cats
  purr little hearts (`_on_cat_happy`, three cached heart meshes rising).
- **Streak** exactly Tents': combo up the major pentatonic from the second
  right lamp, the "x3" bubble on its own layer, confetti at 5 and 10. Right
  is the answer's on Hard and Insane, fair on Easy and Medium.
- **Gags**, three of every five right lamps by the stone's hash: sunglasses
  on the lantern (`cool`; `CourtLantern._face_frame`), a heart-shaped smoke
  ring puffed off its cap (`puff`), and the One Line snail
  (`ui/faces/snail_face.gd`) sliding across the stone's front with a tiny lit
  `CourtLantern` riding on her shell (`snail`). The snail is one node, made
  on first use and kept, moved by its transform.
- **Moths** (the butterflies' part): cached meshes per tint and wing opening
  (`_moth`), drawn under a transform; each chases a point going round its
  lamp, so it flutters in and circles. One from the first judged lamp, two
  past `MOTH_SECOND` of the answer's lamps, a newly judged lamp takes the
  moth that has circled longest, `MOTH_PARTY` more at the party, gone
  `FLIES_STAY` after it. `moth` plays on arrival.
- **Seal and share**: Flawless (no hint, and no heart lost on Hard/Insane or
  no Check on Easy/Medium) stamps the gold seal; any Insane solve stamps the
  night seal, "Insane" over "Flawless" or "Cat Naps" (`LU_CAT_SEAL`).
  `share_glyphs()` adds `🏅 Flawless` or `🌙 Cat Naps[ · Flawless]`.
- **Party**: hats on every lantern and cat along the diagonal (the napping
  cat sleeps through it in hers; `CourtLantern._hat_place` seats it on the
  iron cap), a garland of small round paper lanterns on a cord dropping in
  and swinging to rest over the court's top edge (rebuilt only while it
  swings, then one cached mesh), two confetti sweeps and the moths, then
  every lamp lets a paper sky lantern go (`_sky_lantern`, one cached mesh,
  rising and swaying past the card's top through the win screen; `lanterns`
  once). `win_delay()` is `WIN_WAIT` + `PARTY_EXTRA` (1.3). A restored solve
  keeps the garland and, on Insane, the night seal.
- **Motion**: glance (lanterns and cats within two stones look at the finger
  and follow a sweep); the candle's flicker was already `CourtLantern`'s idle
  (a transform on its glow). Under reduce motion: no gags, moths, sky
  lanterns, flares, purr hearts, block cheers or flicker; the seal and the
  garland stand still.
- **Sound**: taps play `place`, `strike` (a lamp taken off) or `clear` (a
  chip taken up); a sweep ticks `chip`/`clear` per stone it changes, 4%
  higher each up to 1.6. The rest as the spec's section 5. None of the new
  cues has been judged by ear.
- **Harness**: `tests/_shot_lightup.gd -- d=0..3 rest|right|wrong|wake|sweep|solve|perf [rm]`
  (810x1440, `--always-on-top`, `--rendering-driver opengl3_angle`). `right`
  sets down one lamp of each gag first; `sweep` sets two lamps down and shoots
  mid-sweep; `solve` runs through the party into the win screen.
- **Draw calls** (angle, 810x1440, second of two readings; every pair
  matched within one): solve 138 / 146 / 157 / **213** at d=0..3, 64 / 68 /
  73 / 107 under reduce motion; right 103 / 108 / 111 / 139, reduce 98 /
  102 / 105 / 127; wrong (Hard, Insane) 112 / 138, reduce 111 / 136. The
  Insane party is the peak, a quarter of the 855 budget. Part 1 alone read
  165 (d=3 solve) and 137 (d=3 wrong). Suite 122778 passed, 0 failed;
  `tests/_win.gd -- lightup` PASS.
