# Light Up polish: failing, Cat Naps, rewards, motion and sound

2026-09-30, built unattended on `feat/lightup-polish` at the user's word
("polish the light up game, add more smooth animations, reinforce that the
sfx sounds are really cozy, add more visual rewards even if silly ... make
sure the insane difficulty is really insane, with something totally new
(something only us do) that make the game nearly impossible, user can also
fail on insane and hard ... don't worry if you need to redo something on the
logic or design, as long as it keep the cozy vibe"). Shikaku's and Tents'
passes the same morning (`2026-09-30-shikaku-polish-design.md`,
`2026-09-30-tents-polish-design.md`) are the pattern: this follows them
wherever the boards meet, so the game fails and celebrates one way. No
concept tab: polish of a built screen plus a rule, with the user away. The
calls below are for the user to judge on the phone.

Earlier the same morning the user said Light Up felt too close to Mushroom
Patch and Tents (place a piece, rule stones out, numbers go green). This
pass answers that with the one thing only Light Up has: **the beam**. The
Insane rule, the right lamp's moth and the sky lanterns all lean on light
travelling down a line.

## 1. Hard and Insane can be failed

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`), on the shared paper pill in
  a `HEART_ROW` strip over the court, only on a board with hearts (the
  layout keeps the strip in `card_height`, `_cell_for` and `_layout`), as on
  Tents.
- **What costs one**: a lamp set down by a tap that the board **cannot
  fault** (`state.lamp_fair(cell)`: no lamp in its sight, no numbered block
  beside it pushed over its number, and on Insane no cat pushed over its
  number) and that is not the answer's. The answer is unique, so it is wrong
  by proof. A lamp the board already shows as wrong (a rose clash beam or a
  rose block) costs nothing: the board has said so. Chips never cost
  anything, nor does a sweep.
- **The wrong lamp** goes WORRIED, its flame gutters (the lantern's glow
  fades toward the paper's own colour and its light draws back along the
  beam, stone by stone, the travelling wave run backwards), it sags with a
  squash, its stone blushes, and `EJECT_AFTER` (0.75 s) later it is taken
  off through `state.undo()`, leaving no history. Input, undo, hint, check
  and reset wait on `_ejecting`; `busy()` holds the host's hint video.
- **Out of hearts**: the court slips to dusk (the floor's warmth dims), the
  lanterns and cats nod off SLEEPY along the diagonal, the moths leave, and
  `ui/hud/out_of_hearts.gd` comes up with `LU_OUT_BODY`/`LU_OUT_REST`. Try
  again deals the same court with every heart back (hints spent stay spent);
  One more heart wakes the court.
- **Insane has one hint** (`State.HINTS_BY_BAND`).

## 2. Insane: Cat Naps

A rule no Light Up we could find has. The known variants are Mirror Akari
(diagonal mirrors bend the light), Regional Akari (a count per region) and
Lighten Up (a triangular grid where lamps may see each other and add up).
All their clues sit on walls; none puts a clue **on the lit floor, counting
the light that reaches it**.

- **A cat** sits on a cushion on an open stone. It asks for exactly as many
  lanterns shining on it as its number: **0** (a cat napping, who wants the
  dark), **1** (one lamp to bask in) or **2** (a greedy cat who wants two
  beams crossing on her cushion). Since no lamp may see another, one row
  line and one column line can each bring at most one lamp, so 2 is the
  most a cat can ask for.
- **Light passes over a cat** (she is on the floor), so two lamps with a cat
  between them still see each other. **No lamp or chip goes on a cat's
  stone**, and a cat's stone is exempt from "every stone lit": her number is
  her whole rule. A napping cat is the only stone on the court that must
  stay dark, and every lamp in her row and column is ruled out by her. That
  is the first thing the player has to see (`LU_TIP_CAT` asks the question).
- **Her face**: waiting while short; JOY with a slow tail swish and a purr
  when her number is met; STRAIN (ears back, fur up) when more lamps reach
  her than she wants. A napping cat is SLEEPY with a small "z" while dark,
  and wakes cross (STRAIN) the moment light reaches her. Her number sits on
  a little bell tag on her collar, and the napping cat shows a "z" there
  instead of "0". It is the kitten (`ui/faces/kitten_face.gd`), curled on a
  cushion (a body-and-tail pose of her own, not a new character).
- **The board**: 10x10 (the proofs were fast enough; 9x9 was the plan), four to six cats with at
  least one napping (0) and one greedy (2) cat, and every block number
  that can go while the answer stays unique taken off. A board is kept only
  when, read with its cats' numbers ignored (a cat's stone still takes no
  lamp and needs no light), it has **more than one** answer: the rule
  carries the day.
- **Banked** (`content/insane/lightup.json`, mined by
  `tools/insane/lightup_ladder.gd`, at least 100 boards). Rung = block
  numbers taken off; `HARD_RUNG` sits above what Hard shows. An empty bank
  falls back to the old live band 3 (8x8, no cats).
- **Encoding**: a cat is a grid value of its own (`Gen.CAT + n`), so the
  win test, `lit`, `clash` and the solver all learn that light crosses it.
  `State.is_solved` stays the rules, not the answer: numbers exact, no lamp
  sees another, every non-cat stone lit, every cat's count exact.
- Level card: "10 × 10, cat naps" (`LU_LVL_3`).

## 3. Rewards

- **Right lamps glow** on Hard and Insane: a lamp whose tap was judged right
  (fair and the answer's; `_judged`, which hints join) goes JOY at once, its
  candle flares, and **a moth** flutters in to circle it. Only a judged lamp
  gets one, never a lamp that turns fair another way (Tents' review found
  that to be a free check). Easy and Medium have no hearts, so a moth there
  would claim a correctness the board has not checked.
- **Blocks hop** the moment their number is met, and **cats purr** (little
  hearts rise) the moment theirs is.
- **Streak** (Binairo's, Shikaku's and Tents'): right lamps in a row. Right
  means the answer's on Hard and Insane, fair on Easy and Medium. `combo` is
  pitched up the major pentatonic from the second, an "x3" paper bubble
  shows by the lamp, and confetti fires at 5 and 10. A lamp in trouble, a
  wrong lamp or a reset ends it.
- **Gags**, three of every five right lamps by the stone's hash:
  - the lantern slides on **sunglasses** (`cool`);
  - the lantern puffs a small **heart-shaped smoke ring** that drifts up and
    fades (`puff`);
  - a **snail** carrying a tiny lantern of her own slides across the stone
    in front of it (`snail`; `ui/faces/snail_face.gd`).
- **Seal**: Flawless (no hint, and no heart lost on Hard and Insane, or no
  Check on Easy and Medium) stamps the gold seal. Any Insane solve stamps
  the night seal, "Insane" over "Flawless" or "Cat Naps". `share_glyphs()`
  gains `🏅 Flawless` or `🌙 Cat Naps[ · Flawless]`, and cats share as 🐈.
- **Party**: party hats on every lantern and cat along the diagonal, a
  **garland of paper lanterns** that drops in and swings to rest over the
  court, then **sky lanterns**: every lamp lets a small paper sky lantern go,
  which rises, sways and fades above the card. Two confetti sweeps and the
  moths. `win_delay()` is `WIN_WAIT` + `PARTY_EXTRA`.

## 4. Motion

- **Glance**: lanterns and cats within two stones of the finger look at it,
  follow a sweep, and look ahead again on release.
- **Flicker**: every lit lantern's candle breathes (a transform on its own
  cached draw, never a rebuild).
- The gutter and eject, the dusk and nod, the wake along the diagonal, the
  heart split and return, the block hop, the cat purr and tail, the three
  gags, the moths, the hats, the garland and the sky lanterns. Under reduce
  motion: no gags, no moths, no sky lanterns and no flicker; the seal and
  the garland stand still.

## 5. Sound

- **Re-prompted** toward paper, felt and kalimba, as Shikaku's and Tents'
  were: `place` (a paper lantern set down and a warm glow), `locked`, `undo`
  and `check` (the old bonk, tape rewind and wooden boops read as a scold or
  a toy).
- **New**: `strike` (a lamp softly blown out); `chip` and `clear` (a tick
  per stone of a sweep, pitched 4% higher per stone up to 1.6, like
  Tents'); `combo`, `confetti`, `cool`, `puff`, `snail`, `moth`, `purr`,
  `wake` (a cat woken, a small cross mew, cute and not a hiss),
  `heart_lost`, `out_of_hearts`, `heart_back`, `stamp`, `party` and
  `lanterns` (the sky lanterns rising).

## 6. Numbers

Draw-call peaks from `tests/_shot_lightup.gd -- d=<n> <mode> [rm]`
(810x1440, `--always-on-top`, `opengl3_angle`), the second of two readings
(each pair matched within one):

| mode | d=0 | d=1 | d=2 | d=3 |
|---|---|---|---|---|
| solve | 138 | 146 | 157 | 213 |
| solve, reduce motion | 64 | 68 | 73 | 107 |
| right | 103 | 108 | 111 | 139 |
| right, reduce motion | 98 | 102 | 105 | 127 |
| wrong | -- | -- | 112 | 138 |
| wrong, reduce motion | -- | -- | 111 | 136 |

The peak is the Insane party (17 lamps: hats, garland, moths, a sky lantern
each, the seal), 213 against the 855 budget. Before the rewards (part 1)
the Insane solve read 165. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- lightup`: PASS (8 lanterns, board fit, HUD).
