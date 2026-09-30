# Mushroom Patch polish: hearts, Fairy Rings, rewards, motion and sound

2026-09-30, built unattended on `feat/mushroom-polish` at the user's word
("let's polish the mushroom path game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
to the user to keep engagement, and make sure the insane difficulty is
really insane, with something totally new (something only us do) that make
the game nearly impossible, user can also fail on insane and hard ... don't
worry if you need to redo something on the logic or design, as long as it
keep the cozy vibe").

Queens' pass the same day (`2026-09-30-queens-polish-design.md`) is the
pattern: the hearts, the dusk and the card, the streak, the gags, the party
and the seal. No concept tab: polish of a built screen with the user away.
The flat spec (`2026-09-20-mushroom-patch-flat-design.md`) stands except
where this says otherwise. The calls at the end are for the user to judge on
the phone.

## 1. Hard and Insane can be failed: hearts

Before this pass nothing could be lost, and a wrong mark was never refused
(refusing would let a player tap every cell and read the answer off what
stuck). Easy and Medium keep that.

| band | patch | mushrooms | hints | hearts |
|---|---|---|---|---|
| Easy (0) | 6x6 | 6 | 3 | - |
| Medium (1) | 7x7 | 9 | 3 | - |
| Hard (2) | 8x8 | 12 | **1** | **3** |
| Insane (3) | **9x9, Fairy Rings** | 14 | **0** | **2** |

A video hint is still offered once a board's own are spent.

- **Every mushroom is judged as she lands** on Hard and Insane, as phone
  games of this family with lives do. The answer is unique, so a wrong
  mushroom is wrong by proof. A heart is what makes tapping every cell
  cost something.
- **The wrong mushroom** sprouts like any other, goes WORRIED, her cell
  blushes and a heart splits (`heart_lost`); `EJECT_AFTER` (0.75 s) later
  she **wilts** -- droops to one side, sinks into the soil squashing wide and
  fades (`wilt`) -- and a pebble drops in where she stood **for good**, on a
  rose halo (`state.reveal`, `shown`: out of every history entry, skipped by
  a sweep, refused by a tap with "A heart showed that cell bare"). The heart
  bought the knowledge. Input, undo, hint, check and reset wait on
  `_ejecting`; `busy()` holds the host's hint video.
- **Pebbles are never judged.** Check on Hard and Insane *counts* the
  pebbles on mushrooms ("Two of your pebbles sit on mushrooms") and points at
  none: pointing would hand the mushroom over for nothing.
- **Out of hearts**: the patch eases to dusk, the mushrooms doze off along
  the diagonal (`out_of_hearts`), and `ui/hud/out_of_hearts.gd` comes up with
  `MP_OUT_BODY`/`_REST`. Try again plants the same patch from the top in
  Reset's wave, every heart back and the shown pebbles gone (hints spent stay
  spent, a hint's mushrooms stay); One more heart wakes them where they are.
- Rules add `MP_RULES_HEARTS`; Easy and Medium say `MP_RULES_SAFE` ("this
  patch can never be lost"), which the old rules said of every band.

## 2. Insane: Fairy Rings

The genre this board follows (Minesweeper, named once here to forbid it
anywhere else) is wide: one commercial collection of variants alone changes
what a number means seven ways (a cross, a knight's move, a liar off by
one, ...). We found none where **some numbers skip their neighbours and count the ring
two steps out**, shown only by how they are drawn, mixed with plain ones on
one field. Mushrooms really do grow in fairy rings, so the rule is the
board's own:

- **A fairy ring** is a turned-over number inside a ring of ten little
  violet caps. It counts the **sixteen cells two steps out** (Chebyshev
  distance exactly two, fewer at an edge) and says **nothing** about the
  eight touching it. Its numeral is violet while it is short, and a fairy
  ring's nought is lettered (it is a clue about far cells).
- **Half the turned cells are rings** (`Gen.RING_SHARE`), rolled per cell.
- **Press any number** (every band) and the cells it counts light up --
  sunlight for a plain number, a lilac haze for a ring -- and the sprout says
  what it counts. This replaced the old refusal on a turned cell.
- **Carved twice**: first with the subsets solver, then again with the deep
  solver, which may suppose a cell is a mushroom (or bare), follow the plain
  rules, the count and subsets, and take the other answer on a
  contradiction (`Gen.solve`). A banked field needs **13 to 29
  suppositions**; Hard's solver finishes none of them. Solvable by
  construction, never a guess.
- **Why it is nearly impossible**: fourteen mushrooms on 81 cells, about 22
  numbers of which about 11 are rings, a ring's number spread over sixteen
  cells it does not touch, no hints of its own, two hearts, and a field that
  only opens by holding a supposition in your head, over and over.
- **Banked** (`content/insane/mushroom.json`, 240 fields from 1200 tries,
  992 passing the gate, 721 s on 8 threads, `tools/insane/mushroom_ladder.gd`;
  rung = suppositions, work = suppositions tried). The phone checks a banked
  field's numbers against its mushrooms and trusts the rest: the deep
  re-proof is 72 ms on the Mac (138 worst over twenty), close to a second on
  a phone as the card opens (Queens' precedent). All 240 re-prove on the Mac.
  An empty bank falls back to a live ring field carved without the deep pass.
- **Easy to Hard are unchanged**: the solver was refactored (`_propagate`)
  and the ring roll happens only on a band with rings; 120 seeds over bands
  0-2 deal the very fields they dealt before.
- How it moves: the rings grow in cap by cap in a diagonal wave after the
  patch's entrance (`rings`), and glow gold at the party (`rings_glow`).
- Rules add `MP_RULES_RINGS`; the tips lead with `MP_TIP_RINGS`,
  `MP_TIP_RINGS_2` and `MP_TIP_HEARTS`. `MP_LVL_2` "12 mushrooms, 8 × 8, three
  hearts", `MP_LVL_3` "Fairy Rings: 9 × 9, two hearts". A ring shares as ⭕.

## 3. Rewards, even silly

- **The streak**: plants that hold in a row -- on Hard and Insane the
  answer's, on Easy and Medium any plant that sends no number over (it
  reveals nothing). `combo` up the pentatonic from the second, the "x3"
  bubble, confetti at 5 and 10. A pull, a wrong mushroom, an undo or a reset
  ends it.
- **Gags**, three of every five plants by the cell's hash: little **hearts**
  float up off her (`love`); she **twirls** a whole turn on a hop (`twirl`);
  or she winds up, eyes shut, and **sneezes** a puff of glittering spores
  (`sneeze`).
- **A flower on every finished number**: when every cell a number counts is
  marked and its count holds, a daisy opens in its bed's corner (`bloom`),
  and folds if that stops being true. Read off the player's own marks
  (`state.finished`), never the answer, like the count wash.
- **The party**, `PARTY_AT` after the solve wave: a **meadow**, a flower on
  every bare cell along the diagonal (`meadow`); the mushrooms **dance**;
  confetti twice; on Insane the rings glow gold; and the sprout shares **a
  bit of mushroom wisdom**, one of twelve silly ones picked by the patch
  (`MP_CHEER_0..11`: "everyone is a little fun-guy on the inside").
- **The seal**: Flawless (no hint, and no heart lost on Hard and Insane, or
  no Check on Easy and Medium) stamps the gold seal; any Insane solve the
  night seal, "Insane" over "Flawless" or "Fairy Rings".
  `completion_record()` keeps `flawless` so a reopened day keeps its seal.
  `share_glyphs()` gains `🏅 Flawless` or `🌙 Fairy Rings[ · Flawless]`.
- `win_delay()` is `WIN_WAIT` + `PARTY_EXTRA`.

## 4. Motion

New, on top of the flat spec's: the reach glow; the rings growing in and
glowing; a pebble drops in as it pops (`PEBBLE_DROP`); the worry, blush,
heart split and wilt; the dusk and the dozing; the heart pill popping in
with the tally; the streak bubble; the love hearts, twirl and sneeze; the
flowers opening and folding; the meadow, the dance and the seal's drop.
Under reduce motion: no gags, confetti or dance; the rings stand, the reach
glow and the wilt are instant, the flowers, meadow and seal stand open.

## 5. Sound

Re-prompted toward felt, moss, paper and kalimba, as Queens' and Word
Trail's were (the tape-rewind undo and the wooden "bonk" read as a toy or a
scold): `place`, `remove`, `locked`, `undo`, `hint`, `check`, `check_ok`,
`reset`, `enter`, `solved`. New: `pebble` (a pebble had shared `place`),
`reach`, `combo`, `confetti`, `love`, `twirl`, `sneeze`, `bloom`,
`heart_lost`, `wilt`, `out_of_hearts`, `heart_back`, `stamp`, `party`,
`dance`, `meadow`, `rings`, `rings_glow`. Rendered on the fallback key (the
first was out of credits); **unheard**.

## 6. Numbers

Draw-call peaks from `tests/_shot_mushroom.gd -- d=<n> <mode> [rm]`
(810x1440, `--always-on-top`, `opengl3_angle`), one run each:

| mode | peak |
|---|---|
| rest, Insane (rings growing, a ring held) | 90 |
| right, Easy (streak, bubble, gags, flowers) | 118 |
| right, Hard | 119 |
| wrong, Hard (wilt, card, Try again) | 119 |
| wrong, Insane | 114 |
| solve, Medium (party, meadow, seal) | 140 |
| solve, Insane (rings glow, night seal) | 147 |
| restore, Insane | 121 |
| solve, Hard, reduce motion | 81 |
| rest, Easy, reduce motion | 94 |

All far under the 855 budget. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- mushroom`: PASS.

## 7. Calls for the user

1. **Fairy Rings on the phone**: whether the ring of violet caps reads as
   "this number counts further out" at a glance, and whether pressing a
   number to light its reach is found without being told (the tips say it).
2. **Two hearts on Insane, three on Hard** are guesses; Queens gives Insane
   one. Only a wrong *mushroom* costs; pebbles are free.
3. **Judged mushrooms on Hard**: standard with lives and it makes Hard
   losable, but a mushroom that stays is known right, which is more help than
   the old Hard gave. Check there only counts wrong pebbles.
4. **The bank** cycles after 240 days.
5. **Twelve bits of mushroom wisdom**: silly on purpose.
6. **Sounds are unheard.**
7. **Review findings, fixed**: a solved patch with any pebble on it kept
   rebuilding its meshes every frame on the win card (older than this pass,
   but every lost heart now leaves a pebble); a wrong mushroom on Hard could
   open a finished number's flower and play `bloom` before she wilted; the
   plant that solves the patch still scheduled its combo note, confetti and
   gag over the party; a reopened daily lost its finished numbers' flowers
   and showed every heart full (`completion_record()` keeps `hearts` now).
