## Binairo

### Hearts, Insane and the fibbing sign (2026-09-29)

Spec `docs/superpowers/specs/2026-09-29-binairo-insane-polish-design.md`,
section 1, built on `feat/binairo-insane-polish` in `puzzles/binairo2d.gd`
and `ui/hud/out_of_hearts.gd`.

- **Hearts**: Hard 3, Insane 1 (`HEART_COUNTS`), drawn as one mesh on their
  own layer in a `HEART_ROW` (64) strip the layout keeps over the grid only
  on a board that has hearts, so Easy and Medium lay out exactly as before.
  The day card's hearts at the top right are the day's streak, not these.
- **A wrong tile** costs a heart at once when set with a brush or as a moon;
  a sun set by a *tap* waits `WRONG_GRACE` (0.4 s) first, because tapping
  cycles empty, sun, moon and every tapped moon passes through a sun. Without
  the grace, half of all tapped moons would cost a heart. Any later change to
  the cell cancels the wait. Then: crack, shiver, WORRIED + squash,
  `heart_lost`, and `EJECT_AFTER` later `state.clear_silent()` (no move, no
  history). Input on that tile is locked until it ejects.
- **While a liar hides**, the board does not blush the ends of a broken sign
  (the state reads the liar as its true kind, so a blush where the *shown*
  sign is kept would name it) and `broken_rule()` never says 4.
- **Out of hearts**: input and the clock stop at once, the faces go SLEEPY
  along the diagonal and the tiles sag 4 px after the eject, then the card.
  Try again rebuilds from the same data (hearts full, clock, moves, hints and
  checks zeroed; hints a video paid for stay). One more heart is rewarded
  placement `"heart"` (counts toward the daily video cap like `double` and
  `continue`), once a board, hidden when no video is ready. A remove-ads
  player watches the same video: the spec's free heart for buyers was an
  error against "videos stay for buyers too... no free-reward path"
  (`docs/agents/ads-and-purchase.md`), fixed on 2026-09-29 and
  `BN_OUT_BODY_FREE` removed with it. Back to camp
  calls `finish_unsolved()` and the board's `leave` signal, wired to the
  host's `_on_back`, so the host logs `puzzle_complete {solved: false}` and
  no abandon; `_on_back` also ends a heartless board unsolved on its own.
- **Insane** takes `Gen.insane_board(rng, bank_step)` (10x10, 12 signs, one
  liar) and falls back to Hard's live row with no liar when the bank is
  empty. At the solve the liar's badge swells (x2.7), blushes, turns over
  onto a sheepish face with a "Caught you!" bubble, turns back onto its true
  glyph, and keeps the blush; cue `liar`; the solve wave and `solved` wait
  `UNMASK_WAVE` (1.6 s) and `win_delay()` tells the host.

**Draw calls, `opengl3_angle`, 810x1440, `tests/_shot_anim.gd`, second of
two readings**: Hard 8x8 (d=2) 207 before, 203 after (the harness's first
tap is a sun, which ejects when the answer is a moon); Insane 10x10 (d=3) 227. A
throwaway probe with the Insane board full but one cell read 367, and Hard
partly filled 219. All far under 855, so the tiles were not baked.

### Motion and rewards (2026-09-29)

The polish spec's section 2, built on `feat/binairo-insane-polish`.

- **The tile is a slot and a coin.** `_tiles[r][c]` is now a plain Control
  (the hops, nudges, shiver, press, entrance scale, sag and Check's wobble)
  and `_coins[r][c]` the Panel inside it with the stylebox, the tint, the
  face and the crack (the flip's `scale.x` and a high-five's lean). No two
  tweens write one property, which is what the press and the flip would
  otherwise have done on release.
- **Flip**: a tap, a brush and an undo turn the coin (`FLIP_IN` 0.1 to its
  edge, `FLIP_OUT` 0.14 open with the back ease); the new face is made at
  once but hidden until the edge, so a wrong tile's yelp and a glance find
  it, and the old face waits in `_outgoing`. A turn cut short lands first.
  Hint keeps its drop, reset and restore their pops. Reduce-motion swaps.
- **Glance**: `Face.look` (new, snapped to eight directions in the cache
  key) moves the eyes `LOOK_SHIFT` 0.06 R. Faces within two king moves of a
  tap look at it for 0.6 s; a newer glance takes over.
- **Eased blush**: `Motion.fade` took an `eased` flag (sine in-out on the
  quantised ramp); the blush in and out use it, the heartbeat already did. A
  hint warms its tile from white to the given sand over `WARM_TIME` 0.3
  (`_warm`, which `_paint` now reads instead of `given`).
- **Streak**: a cell counts once, the first time it is right, so cycling one
  tile never climbs. **Right means the answer on Hard and Insane, but "no
  rule broken" on Easy and Medium**: there nothing else tells a player a
  tile is right, and a bubble that did would be a free Check. A heart lost
  (or a blush on Easy/Medium) ends it; hint and undo neither count nor end
  it; reset and Try again zero it. The sound is `place` as ever with the
  `combo` pluck **layered** over it from the second in a row, at -4 dB,
  climbing the major pentatonic (-5, -3, 0, 2, 4, 7, 9 semitones; the eighth
  and on hold 9), chosen over re-pitching `place` because a wood tap pitched
  up 1.7x reads as a toy, and a kalimba pluck is written to be pitched. The
  bubble ("x3" and up, from 3) is one mesh and one `draw_string` on its own
  layer: pops, bumps, deflates over 0.25 s. Confetti at 5 and 10:
  `Fx2D.confetti(at, count, width)`, a sun emitter and a moon emitter per
  burst (two of each pooled), textures drawn in code like `star_texture`.
- **Silly lines** (all three, by `hash(Vector3i(r, c, n)) % 3` of the
  completing cell): sunglasses on the line's suns (`Face.glasses`, an
  accessory mesh in the face layer's transform) while its moons beam; one
  moon sneezes (stretch with its eyes shut, squash, a puff of stars in
  `SUN_RAY` and `CHEEK`, JOY) through `_act`, which holds an expression over
  the state's; the line pairs off and high-fives down its length (the coins
  tilt their tops together in a row, bump heads in a column, a sparkle where
  they meet). `line` still plays at the hop and `line_silly` (-3 dB) 0.32 s
  later on the punchline, so the two follow rather than stack. None on the
  solving tap -- the party is coming.
- **Flawless**: no heart lost since the deal (Try again deals afresh) and no
  hint; on Easy and Medium, no hint and no check. A gold scalloped seal,
  "Flawless" (`BN_FLAWLESS`), drops from 1.8x onto the grid's lower right
  0.7 s after the wave's lead, squashes and rings; on Insane a night-blue seal
  with a crescent, `BN_INSANE_SEAL` over a smaller "Flawless". It shows
  under reduce-motion too (standing still), since it is the result.
  `share_glyphs()` keeps the grid and appends `🏅 Flawless` or
  `🌙 Insane · Flawless`.
- **Party**: 0.9 s after the lead, hats (`Face.hat`, three `HAT_STYLES`)
  pop on along the diagonal, two confetti sweeps, and a big sun and moon
  (shadowless, hatted, JOY) slide in from off the edges on a cubic -- the
  back ease overshot a whole screen's slide by a tenth of the screen and the
  two crossed -- and lean into a hug. `win_delay()` is the lead plus the
  host's `WIN_AFTER` plus `PARTY_EXTRA` 1.7, so the win screen comes 0.77 s
  after the hug lands. Reduce-motion: no party and the host's still beat.
- **Hearts look**: the day card shows red streak hearts on a white pill
  right above, and the board's read as more of the same. They sit on a paper
  pill like a sign badge, and each heart is the board's two halves -- a sun
  half and a moon half with a small face; a spent one is the halves' ghost at
  22%. The split's falling halves are the same halves. The old split's right
  half never drew: its zigzag's first step cut across the curve at the tip
  and `triangulate_polygon` returned nothing; the crack now leaves the tip
  straight up the middle.

**Draw calls, `opengl3_angle`, 810x1440, `tests/_shot_anim.gd`, second of
two readings**: idle Hard 204 and Insane 227 (unchanged); the new `solve`
mode, whose window runs over the wave, stamp and party, peaks at **Hard 384
and Insane 10x10 492** -- 100 hats and the big pair are most of it, and it
is well under 855, so nothing was baked.
