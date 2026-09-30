# Sudoku polish: hearts, Hilltops, rewards, motion and sound

2026-09-30, built unattended on `feat/sudoku-polish` at the user's word
("let's polish the sudoku game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to the
user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the game
nearly impossible, user can also fail on insane and hard ... don't worry if
you need to redo something on the logic or design, as long as it keep the
cozy vibe").

Mushroom Patch's and Queens' passes the same day
(`2026-09-30-mushroom-polish-design.md`, `2026-09-30-queens-polish-design.md`)
are the pattern: the hearts, the dusk and the card, the streak, the gags, the
party and the seal, so the game fails and celebrates one way. No concept tab:
polish of a built screen with the user away. The flat spec
(`2026-09-20-sudoku-flat-design.md`) stands except where this says otherwise.
The calls at the end are for the user to judge on the phone.

## 1. Hard and Insane can be failed: hearts

Before this pass nothing could be lost: a wrong number stood until Check
found it.

| band | grid | hints | hearts | Check |
|---|---|---|---|---|
| Easy (0) | 6x6 | 3 | - | yes |
| Medium (1) | 6x6 | 3 | - | yes |
| Hard (2) | 9x9 | **1** | **3** | **no** |
| Insane (3) | **9x9, Hilltops** | **0** | **2** | **no** |

A video hint is still offered once a board's own are spent.

- **Every number is judged as it lands** on Hard and Insane, as the phone
  sudoku apps with a mistake limit do (three is their usual count, and a
  second chance behind a video is their usual offer). The answer is unique,
  so a wrong number is wrong by proof.
- **The wrong number** lands like any other, then goes rose, its cell
  blushes, the cell shivers and a heart splits (`heart_lost`); `EJECT_AFTER`
  (0.7 s) later it **tumbles off the paper** -- tips over, drops half a cell
  and fades (`tumble`) -- and that number is **crossed out of that cell for
  good**: a small rose numeral struck through, in the pencil marks' seat
  (`state.ruled`, `state.reject`; the move leaves the history). Placing it
  there again is refused, free, with "A heart already showed 7 doesn't go
  there" (`ruled`). The heart bought the knowledge.
- **A right number stays put** on those bands (`State.KEPT`): the pad and the
  remove chip refuse it with "That one is right. It stays." Undo may still
  take it back.
- **No Check** on Hard and Insane (`capabilities()`): no wrong number can
  stand, so it would only ever say "all good".
- Input, undo, hint, check and reset wait on `_ejecting`; `busy()` holds the
  host's hint video.
- **Out of hearts**: the tray eases to dusk, the line says "The numbers have
  dozed off", and `ui/hud/out_of_hearts.gd` comes up with
  `SD_OUT_BODY`/`_REST`. Try again takes the grid back to its givens in
  Reset's wave, every heart back and the crossed-out numbers gone (hints
  spent stay spent); One more heart brings the light back where it was.
- The hearts sit on the family's paper pill in a `HEART_ROW` strip over the
  tray. On the phone's slot the cell stays the nominal 100 (measured).
- Rules add `SD_RULES_HEARTS`; Easy and Medium say `SD_RULES_SAFE`.
  `SD_LVL_2` is "9 × 9, three hearts" (the level picker's Hard line).

## 2. Insane: Hilltops

Sudoku's variants are legion -- killer cages, thermometers, arrows, kropki
dots, XV, sandwiches, little killers, neighbour sums, quadruples, parity,
anti-knight -- and a search turned up none where **a clue in a cell counts
how many of its four orthogonal neighbours are smaller than it**. That is
Hilltops:

- **A hill** is a small green mound in a cell's lower right with **0 to 4
  dots**: how many of the cells beside it (up, down, left, right; fewer at
  an edge) hold a smaller number. The four share its row or column, so none
  can equal it: each is lower or higher. A hill of no dots is the lowest
  thing around it, a hill of four the highest. The cell under a hill is
  filled like any other.
- **Sixteen givens or fewer** (15 or 16 on every banked grid). No plain
  sudoku can go under seventeen and stay unique; the hills are how in.
- **Tap a hill's cell** and its neighbours light with a leaf rim, and the
  line says "This hill sees 2 lower beside it."
- A hill whose count has come true around it turns gold; one that what is
  written beside it cannot satisfy sits on a rose halo. Both read the
  player's own numbers, never the answer (the clash wash's rule).
- **The deal** (`Gen.generate_hills`): a full grid, 34 hills read off it,
  the symmetric dig down to `HILL_TARGET` 16 under a count that respects the
  hills, then every hill the answer can do without taken out (10 to 14 stay).
  The count with hills (`_count_hills`) propagates singles and the hills'
  reckoning at every node; the plain backtracking count took over a minute a
  grid at this depth.
- **Graded like a player** (`Gen.solve_logic`): singles (naked, hidden) and
  the hills' reckoning (a hill's number must leave exactly its count lower
  beside it; a neighbour keeps only numbers some hill number agrees with),
  then **suppositions**: put a number in a cell in your head, follow the
  rules, cross it out when the grid breaks. A banked grid is one that
  singles and the hills alone cannot finish and suppositions can: unique
  and never a guess. Hard's own grade (singles) finishes none.
- **Why it is nearly impossible**: 15-16 givens, two hearts, no hints, no
  Check, a clue that speaks only in comparisons, and a grid that opens only
  by holding a supposition in your head, again and again (see section 6 for
  the counts).
- **Banked** (`content/insane/sudoku.json`, `tools/insane/sudoku_ladder.gd`;
  rung = suppositions that crossed something out, work = suppositions
  tried). The phone checks a banked grid's answer is legal, its givens agree
  and its hills are its own counts, and trusts the miner's uniqueness proof.
  An empty or broken bank deals a live Hilltops grid under a 900 ms budget.
- **Easy to Hard are unchanged**: 60 seeds over bands 0-2 deal the very grids
  they dealt before (the hill paths never touch the plain count's RNG use).
- How it moves: the hills rise in along the diagonal after the grid's
  entrance (`hills`), and glow gold at the party (`hills_glow`).
- Rules add `SD_RULES_HILLS`; the tips lead with `SD_TIP_HILLS`,
  `SD_TIP_HILLS_2` (the supposition, taught) and `SD_TIP_HEARTS`. `SD_LVL_3`
  "Hilltops: 9 × 9, two hearts". It shares as 🌙 Hilltops.

## 3. Rewards, even silly

- **The streak**: right numbers in a row -- on Hard and Insane the answer's,
  on Easy and Medium any number that clashes with nothing (it reveals
  nothing). `combo` up the pentatonic from the second, the "x3" bubble,
  confetti at 5 and 10. A take-out, a clash, a wrong number, an undo or a
  reset ends it.
- **Gags**, three of every five right numbers by the cell's hash: little
  **hearts** float up off it (`love`); it **twirls** a whole turn with a
  sparkle (`twirl`); or it **boings** three times, each hop lower (`boing`).
- **All home**: the last of a number placed (and none of them clashing), every
  one of them hops in reading order and the line cheers "All the 7s are
  home!" (`all_home`).
- **Stickers**: a finished region gets a daisy sticker in its panel's top
  right corner, popping in with a twist (`bloom`), and folds if the region
  comes apart.
- **The party**, `PARTY_AT` after the solve wave: the numbers **dance**
  (sway and hop on the beat, `dance`), confetti twice (`party`), on Insane
  the hills glow gold, and the line shares **a bit of number wisdom**, one
  of twelve silly ones picked by the grid (`SD_CHEER_0..11`: "6 is just 9
  doing a handstand").
- **The seal**: Flawless (no hint, and no heart lost on Hard and Insane, or
  no Check on Easy and Medium) stamps the gold seal on the tray's lower
  right; any Insane solve the night seal, "Insane" over "Flawless" or
  "Hilltops". `completion_record()` keeps `flawless` and `hearts`, so a
  reopened day keeps its seal, stickers and hills. `share_glyphs()` gives
  `🏅 Flawless` or `🌙 Hilltops[ · Flawless]`.
- **The win card** now says the board's own words ("Every number in its
  place", no mascot, as Nonogram); it had fallen back to Binairo's "Perfect
  balance".
- `win_delay()` is `WIN_WAIT` + `PARTY_EXTRA`.

## 4. Motion

New, on top of the flat spec's and the 2026-09-25 polish: the hills rising
and glowing; a selected hill's reach; the wrong number's blush, shiver and
tumble; the heart pill popping in, splitting and a heart coming back; the
dusk; the streak bubble; the love hearts, the twirl and the boing; the all
home hop; the stickers opening and folding; the dance and the seal's drop.
Under reduce motion: no gags, confetti or dance; the hills stand, the tumble
is instant, stickers and the seal stand open.

## 5. Sound

Re-prompted toward felt, soft pencil, paper and kalimba, as Mushroom Patch's
and Queens' were (the tape-rewind undo and the wooden "bonk" read as a toy or
a scold): `place`, `pencil`, `line`, `locked`, `undo`, `hint`, `check`,
`check_ok`, `reset`, `enter`, `solved`. New: `all_home`, `bloom`, `combo`,
`confetti`, `love`, `twirl`, `boing`, `heart_lost`, `tumble`, `ruled`,
`out_of_hearts`, `heart_back`, `stamp`, `party`, `dance`, `hills`,
`hills_glow`. Rendered on the fallback key (the first was out of credits);
**unheard**.

## 6. Numbers

**The bank**: 200 grids kept of 500 tries (454 passed the gate; the miner
keeps the hardest), 15.2 s a try per thread, 960 s wall on 8 threads. Rungs
(suppositions that crossed a number out) 34 to 108, median 52; suppositions
tried 531 to 10947, median 2474; givens 15 to 16; hills 8 to 17, median 13.
All 200 pass the phone's checks (`from_bank`, 7 ms worst); every tenth was
re-proved unique by the hill count on the Mac.

**The live fallback** (empty or broken bank only): 0.8 to 1.1 s on the Mac
under its 900 ms budget, and the budget cuts the hill prune short, so on a
slower phone the same seed would deal an easier grid (the review's finding;
it never runs while the bank ships).

Draw-call peaks from `tests/_shot_sudoku.gd -- d=<n> <mode> [rm]` (810x1440,
`--always-on-top`, `opengl3_angle`), one run each:

| mode | peak |
|---|---|
| rest, Insane (hills rising, a hill selected) | 99 |
| right, Easy (streak, bubble, gags, stickers) | 108 |
| wrong, Hard (tumble, card, Try again) | 133 |
| wrong, Insane | 126 |
| solve, Medium (party, seal) | 132 |
| solve, Insane (hills glow, night seal) | 121 |
| restore, Insane | 102 |
| solve, Hard, reduce motion | 106 |
| rest, Easy, reduce motion | 102 |

All far under the 855 budget. The cell stays 100 on Hard and Insane under
the heart strip. Suite: 122778 passed, 0 failed. `tests/_win.gd -- sudoku`:
PASS. Easy to Hard: 0 of 60 seeds deal a different grid.

**Review findings, fixed**: a reopened Insane day played the hills' rise
sound (the entrance's queued cue outlived `restore_completed_board`).

## 7. Calls for the user

1. **Hilltops on the phone**: whether a mound with dots reads as "counts the
   lower cells beside me" at a glance, and whether tapping it to light its
   neighbours is found (the tips and the line say it).
2. **Two hearts on Insane, three on Hard** follow the apps' three and
   Mushroom Patch's two.
3. **Judged numbers on Hard** make Hard losable but a number that stays is
   known right, which is more help than the old Hard gave; Check is gone
   there.
4. **The bank** cycles once every grid has been played.
5. **Twelve bits of number wisdom**: silly on purpose.
6. **Sounds are unheard.**
