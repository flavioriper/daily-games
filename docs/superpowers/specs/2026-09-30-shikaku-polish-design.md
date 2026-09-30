# Shikaku polish: failing, Scarecrows, rewards, motion and sound

2026-09-30, built unattended on `feat/shikaku-polish` at the user's word
("polish the shikaku game, add more smooth animations, reinforce that the sfx
sounds are really cozy, add more visual rewards even if silly ... make sure
the insane difficulty is really insane, with something totally new ... user
can also fail on insane and hard"). No concept tab: this is polish of a built
screen plus a rule, and the user was away; the choices below are the calls
made, for the user to judge on the phone.

## 1. Hard and Insane can be failed

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`, Binairo's counts), on a paper
  pill in a `HEART_ROW` strip the layout keeps over the field only on a board
  with hearts. Pink hearts with a face and a leaf, split along Binairo's crack.
- **What costs one**: a bed that *fits* its sign (the green wash:
  `state.fitted_clue(rect) >= 0`) but is not the answer's plot. A bed that
  does not fit -- rose, or holding no sign or two -- costs nothing: the wash
  already says it is wrong, so it tells the player nothing a heart should pay
  for, and fumbling a drag is not a deduction. The answer is unique, so a
  fitting bed outside it is a mistake by proof.
- **The wrong bed** wilts (`WILT_TINT`, sags `WILT_SAG`), its sign goes
  WORRIED, shivers and squashes, the sprout says `SK_WRONG_BED`, and
  `EJECT_AFTER` (0.75 s) later the move is taken back with `state.undo()` --
  so a redraw that went wrong gives back the bed it replaced -- and leaves no
  history. Input, undo, hint, check and reset wait while it goes.
- **Out of hearts**: the signs nod off SLEEPY along the diagonal, the
  butterflies leave, and `ui/hud/out_of_hearts.gd` comes up (Try again, One
  more heart through the rewarded `heart` placement once a board, Back). The
  card now takes a board's own body lines (`SK_OUT_BODY`/`_REST`), since
  Binairo's talk about suns and moons. Try again deals the same field with
  every heart back and the clock and moves from zero; hints spent stay
  spent (Insane has one). A tap on bare ground draws nothing, so looking at
  a blank square sign or a scarecrow never costs a heart.
- **Insane has one hint** (`State.HINTS_BY_BAND`).

## 2. Insane: Scarecrows

A rule no Shikaku we could find has. The web has Shikaku with shapes,
numberless signs, and "no two touching plots the same size" (Hakata); none
has a sign that counts its **neighbours**.

- **A scarecrow** is a sign in a straw hat with stick arms and a straw plaque.
  It asks for no size and no shape; its number is **how many beds share a
  fence with its own** (edges, not corners). Clue `{"crow": n}`, area 0,
  shape ANY.
- **Its face**: waiting while any cell round its bed is bare; STRAIN the
  moment the bed has more neighbours than its number, or its ring is closed
  on the wrong count; JOY (and its sprouts) only when the count is met.
- **The board**: 8x10 (Hard is 7x9), plots up to 12, three scarecrows, every
  other sign shaped, and the number taken off every one that can go while the
  answer stays unique (`Gen.generate_crows`). A board is kept only if, read
  with its scarecrows as plain blank signs, it has **more than one** answer:
  the rule is what the day turns on.
- **Banked** (`content/insane/shikaku.json`, 120 boards, mined 2026-09-30:
  1087 of 1200 tries kept, rungs 13-17 numberless signs out of 18-21) by
  `tools/insane/shikaku_ladder.gd`; a proof costs up to a minute on this Mac,
  so the phone only reads. An empty bank falls back to the old live band 3.
- **Solver**: the exact cover now runs in `Gen.Search` and checks every placed
  scarecrow at each placement (too many distinct neighbours, or its ring
  closed on the wrong count, drops the branch). `solve_count(..., crows=false)`
  reads scarecrows as blank signs.
- Level card: "8 × 10, scarecrows".

## 3. Rewards

- **Sprouts**: a settled bed (its sign JOY; on a board with hearts only the
  answer's beds) grows shoots in every cell -- the win's seedling held at
  `SPROUT_U` 0.4, a stem and two leaves -- over `SPROUT_TIME` after
  `SPROUT_LAG`, baked into the bed's mesh (the cache key carries the step).
  The planting wave grows every flower on from its shoot, so the win is the
  field finishing what the player grew.
- **Streak** (Binairo's): right beds in a row. Right is the answer on Hard and
  Insane, the green wash on Easy and Medium. `combo` layered over `plot` up
  the major pentatonic from the second, an "x3" paper bubble on the bed's
  corner, confetti at 5 and 10. A bed that does not fit, a wrong bed or a
  reset ends it.
- **Gags**, three of every five right beds by the bed's own hash: a **worm**
  pokes out of a cell of the bed, looks round, waves and dives; the sign
  slides on **sunglasses**; the sign **twirls** once.
- **Butterflies** come to settled signs: one from the first settled bed, two
  from 40% of the signs, flying sign to sign and perching 2-4.5 s with slow
  wings; four more at the party. Drawn with the worm and the seal on one
  `Life` layer, one mesh a frame.
- **Seal**: Flawless (no hint, and no heart lost on Hard and Insane, no Check
  on Easy and Medium) stamps the gold seal on the field's lower right; any
  Insane solve stamps the night seal, "Insane" over "Flawless" or
  "Scarecrows". `share_glyphs()` gains `🏅 Flawless` or
  `🌙 Scarecrows[ · Flawless]`.
- **Party**: hats on every sign along the diagonal (`MarkerFace._hat_place`
  seats them on the plaque's top edge -- the base put them a cell up), two
  confetti sweeps, the butterflies. `win_delay()` is `WIN_WAIT` +
  `PARTY_EXTRA` (3.5 s).

## 4. Motion

- **Glance**: signs within a king's move or two of the drag's corner look at
  it (`Face.look`), and look ahead again on release.
- The wilt, the sleep, the heart split and return, the sprouts, the worm and
  the butterflies above. Reduce-motion: no gags, no butterflies, no party;
  sprouts and the seal stand still.

## 5. Sound

`locked`, `check`, `clear`, `undo` re-prompted toward felt and kalimba (the
bonk, the tape rewind and the wooden boops read as a scold or a toy, as
Binairo's and Code Break's did). New: `sprout`, `combo`, `confetti`, `worm`,
`cool`, `twirl`, `stamp`, `party`, `heart_lost`, `out_of_hearts`,
`heart_back`, all Shikaku's own takes (the last seven on the fallback key,
after the main ElevenLabs key ran out). None judged by ear.

## 6. Numbers

`opengl3_angle`, 810x1440, `tests/_shot_shikaku.gd`, second of two readings:
half an Insane board with butterflies **151** draw calls; the Insane solve
window (planting, party, seal) peaks at **272**. Far under 855.
