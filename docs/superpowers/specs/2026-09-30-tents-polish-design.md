# Tents polish: failing, Old Oaks, rewards, motion and sound

2026-09-30, built unattended on `feat/tents-polish` at the user's word
("polish the tents game, add more smooth animations, reinforce that the sfx
sounds are really cozy, add more visual rewards even if silly ... make sure
the insane difficulty is really insane, with something totally new ... user
can also fail on insane and hard ... don't worry if you need to redo
something on the logic or design, as long as it keeps the cozy vibe").
Shikaku's pass the same morning (`2026-09-30-shikaku-polish-design.md`) is
the pattern; this follows it wherever the two boards meet, so the game fails
and celebrates one way. No concept tab: polish of a built screen plus a rule,
with the user away. The calls below are for the user to judge on the phone.

Earlier the same morning the user said Tents felt too close to Mushroom
Patch and Light Up (place a piece, rule squares out, numbers go green). This
pass answers that with the one thing only Tents has: **tents belong to
trees**. The oaks, the trees that beam once they have their tents, and the
lamp in a right tent all lean on it.

## 1. Hard and Insane can be failed

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`), on Shikaku's paper pill in
  a `HEART_ROW` strip over the column counts, only on a board with hearts
  (the layout keeps the strip in `card_height`, `_cell_for` and `_layout`).
- **What costs one**: a tent pitched by a tap that the board **cannot fault**
  (`state.tent_fair`: beside a tree, touching no tent, and no known line
  over its count) and that is not the answer's. The answer is unique, so it
  is wrong by proof. A tent the board already shows as wrong (rose) costs
  nothing: the board has said so, and a heart is for a hidden mistake.
  Cairns never cost anything.
- **The wrong tent** goes WORRIED, which fades its canvas toward grey
  (`TentFace.WILT`), sags with a squash after `WILT_LAG`, its cell blushes,
  and `EJECT_AFTER` (0.75 s) later it is struck through `state.undo()`,
  leaving no history. Input, undo, hint, check and reset wait on
  `_ejecting`; `busy()` holds the host's hint video meanwhile.
- **Out of hearts**: trees and tents nod off SLEEPY along the diagonal, the
  butterflies leave, and `ui/hud/out_of_hearts.gd` comes up with
  `TN_OUT_BODY`/`_REST`. Try again deals the same meadow with every heart
  back (hints spent stay spent); One more heart wakes the camp.
- **Insane has one hint** (`State.HINTS_BY_BAND`).

## 2. Insane: Old Oaks

A rule no Tents we could find has. The known variants are Odd Tents (the
counts become shading for odd or even), two-cell tents and Forest Walk (a
loop through the empty cells). None has a tree that takes two tents.

- **An old oak** (`ui/faces/oak_face.gd`) is a round four-lobed crown on a
  short thick trunk with **two acorns** hanging from it, one for each tent.
  It takes two tents. Two tents on neighbouring sides of a tree touch at a
  corner, so an oak's pair always stands on **opposite sides**. The rules
  never say so: it is the first thing the player has to see for themselves
  (`TN_TIP_OAK` asks the question).
- **Hidden counts**: every line count that can go while the answer stays
  unique is taken off, and its chip shows a soft "?" (`CountChip.number`
  -1). A hidden line never goes green or rose and never counts as over.
- **The board**: 10x10, 10 pines and 3 oaks, so 16 tents. Kept only when
  the rule carries the day: read with each oak taking one tent *or* two, the
  board has more than one answer.
- **Banked** (`content/insane/tents.json`, 150 boards, mined 2026-09-30 from
  600 tries by `tools/insane/tents_ladder.gd`). Rung = counts hidden: 88
  boards hide 16 of the 20 counts, 29 hide 15, 25 hide 17 and 8 hide 18.
  So a day shows 2 to 5 numbers on a 10x10. A try takes tens of
  milliseconds, so the bank is for uniformity and a fixed pool, not speed.
  An empty bank falls back to the old live band 3 (10x10, 14 tents, no
  oaks).
- **Solver**: `Gen.count_layouts` counts distinct layouts by the tents they
  pitch, not by which tree took which (so two trees swapping a pair of
  tents is one answer). It places the most constrained tree first, bounds
  each known line from above and from below, and has a node budget. It
  agreed with a naive enumeration on six 8x8 oak boards.
  `Gen.is_valid_oak_solution` is the win test for a board with oaks or
  hidden counts: the known counts, no tent touching another or on a tree,
  and a perfect matching with each oak in the tree list twice.
- Level card: "10 × 10, old oaks" (`TN_LVL_3`).

## 3. Rewards

- **Trees beam** (JOY) once they have as many tents beside them as they want
  (one, an oak two), and hop (`CHEER_HOP`) the moment they get them. An oak
  getting its second also sparkles and plays `oak`. It is adjacency, not
  ownership: which tent is whose is still the player's problem.
- **Lamp-lit tents**: on Hard and Insane a tent whose tap was judged right
  (fair and the answer's; `_judged`, which hints join) goes JOY at once. Its
  doorway lights and it throws the win's warm pool on the grass. Only a
  judged tent lights. The review caught a tent turning fair another way
  (its touching neighbour taken off, or an undo) and lighting without ever
  being charged for, which was a free check. Easy and Medium have no hearts, so
  a lamp there would claim a correctness the board has not checked, and
  their tents only light at the win.
- **Streak** (Binairo's and Shikaku's): right tents in a row. Right means
  the answer's on Hard and Insane, and fair on Easy and Medium. `combo` is
  pitched up the major pentatonic from the second, an "x3" paper bubble
  shows by the tent, and confetti fires at 5 and 10. A tent in trouble, a
  wrong tent or a reset ends it.
- **Gags**, three of every five right tents by the square's hash:
  - a **camper** in a bobble hat peeks out of the doorway, looks round,
    waves a mitten and ducks back in (`peek`);
  - the tent slides on **sunglasses** (`cool`);
  - a **bunny** hops past in front of it (`bunny`).
- **Butterflies** perch on beaming trees and lit tents: one from the first
  happy tree, two past 40% of them, and four more at the party.
- **Seal**: Flawless (no hint, and no heart lost on Hard and Insane, or no
  Check on Easy and Medium) stamps the gold seal. Any Insane solve stamps
  the night seal, "Insane" over "Flawless" or "Old Oaks". `share_glyphs()`
  gains `🏅 Flawless` or `🌙 Old Oaks[ · Flawless]`, and oaks share as 🌳.
- **Party**: party hats on every tree and tent along the diagonal, and a
  **bunting** garland of pennants that drops in and swings to rest between
  the column counts and the meadow. Then two confetti sweeps and the
  butterflies. `win_delay()` is `WIN_WAIT` + `PARTY_EXTRA`.

## 4. Motion

- **Glance**: trees and tents within two squares of the finger look at it,
  follow a sweep, and look ahead again on release.
- The wilt, the sleep and wake along the diagonal, the heart split and
  return, the tree cheer, the three gags, the butterflies, the hats and the
  bunting. Under reduce motion: no gags, no butterflies and no party; the
  seal and the bunting stand still.

## 5. Sound

- **Re-prompted** toward felt, canvas and kalimba, as Shikaku's were: `place`
  (a canvas whump and a peg tap), `locked`, `undo` and `check`.
- **New**: `strike` (a tent folded down); `cairn` and `clear` (a tick per
  square of a sweep, pitched 4% higher per square up to 1.6, like Shikaku's
  drag); `combo`, `confetti`, `peek`, `cool`, `bunny`, `oak`,
  `heart_lost`, `out_of_hearts`, `heart_back`, `stamp` and `party`.
- All 18 are one take each, from the fallback ElevenLabs key (the main key
  was already out). None has been judged by ear.

## 6. Numbers

`tests/_shot_tents.gd -- d=0..3 rest|right|wrong|sweep|solve|perf [rm]`,
810x1440:

| Run | Draw calls (peak) |
|---|---|
| Insane solve window, `opengl3_angle` | 226 |
| Insane solve window, default driver | 206 |
| The same, reduce motion | 135 |

All far under 855. The butterflies fly off `FLIES_STAY` (5 s) after the
party, so a solved board goes quiet. A restored solve shows the bunting and,
on Insane, the night seal (a restore cannot know whether it was flawless). Suite 122778/0; `tests/_win.gd -- tents` windowed 1/1.
