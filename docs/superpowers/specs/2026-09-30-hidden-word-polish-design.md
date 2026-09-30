# Hidden Word polish: failing for real, Snail Mail, rewards, motion and sound

2026-09-30, built unattended on `feat/hidden-word-polish` at the user's word
("let's polish the hidden words game, add more smooth animations, reinforce
that the sfx sounds are really cozy, add more visual rewards even if silly
... make sure the insane difficulty is really insane, with something totally
new (something only us do) that make the game nearly impossible, user can
also fail on insane and hard ... don't worry if you need to redo something
on the logic or design, as long as it keep the cozy vibe").

Code Break's pass (`2026-09-29-codebreak-polish-design.md`) is the pattern,
because it is the other board that runs out of rows; Queens' and Nonogram's
passes the same day set the rewards and the seal. No concept tab: polish of
a built screen with the user away. Sections 1 to 14 of
`2026-09-19-hidden-word-flat-design.md` stand except where this says
otherwise. The calls at the end are for the user to judge on the phone.

## 1. Hard and Insane can be failed

Before this pass Reset replayed the same word from the first row with every
row wiped, so a player who had read six rows could clear them and go again
with all of it in their head: unlimited rows on every band.

| band | words | hints | Reset clears | clue rule | colours |
|---|---|---|---|---|---|
| Easy (0) | the commonest | 2 | every row | no | at once |
| Medium (1) | the first band two | 2 | every row | no | at once |
| Hard (2) | all | **1** | **the row being typed** | **yes** | at once |
| Insane (3) | **the Snail Mail bank** | 0 | the row being typed | yes | **a row late** |

- **Rows are ink on Hard and Insane** (`State.keeps_rows`): Reset sends back
  only the letters of the row in hand, right to left, and the caret glides
  home.
- **The clue rule** (`State.strict`, `keeps_clues`): every clue the shown rows
  gave must be used -- a green stays in its place, and a letter a row marked
  green or amber goes in the guess as many times as that row found it. The
  refusals are toasts naming the letter: "R stays in the 2nd spot", "Use the
  O" (`HW_TOAST_KEEP`, `HW_TOAST_USE`, `HW_PLACE_1..5`). It is the well-known
  "hard mode" of this genre; it kills the burner guess, which is most of what
  makes six rows comfortable.
- **Out of rows** (every band): the last row lands, every tile sags and leans
  a little (`DROOP*`), and Code Break's card (`ui/hud/out_of_rows.gd`, this
  board's keys) asks **One more row** (the rewarded video, placement `row`,
  once a word, left off when no video is ready) or **Show the word** (the old
  ending: keyboard away, the sprout rises with the word, `finish_unsolved()`).
  The board takes no keys while the card is up; the host's Back ends it
  unsolved through `out_of_hearts`. Reset gives nothing once the rows have run
  out, on any band (`can_reset()`): replaying a word already all but read is
  not a second try.
- **One more row** grows the grid to seven (`State.MAX_ROWS`, `tries`): the
  cell shrinks from 149 to about 126 over `GROW_TIME` (the band is rebuilt
  each frame of that and never otherwise) and the new row rises in. A solve on
  it stamps "Second wind".

## 2. Insane: Snail Mail

We found word games where the word changes (the adversarial one), where a
tile lies, where several words share a guess, where the scoring is a count
-- and none where **the colours arrive late**. Snail Mail does that:

- A committed row turns over **sealed**: a moonlit envelope (`POST`, cool on
  purpose so it can never read as a mark) with its flap folded down and a
  berry wax seal, the letter in ink. The snail (`ui/faces/snail_face.gd`,
  One Line's walker) sits in the side air beside the row it carries.
- When the next row is committed and has landed, the snail's row turns over
  into its colours (`_deliver_at`, `snail` cue), the keyboard learns it, and
  the snail crawls down to the new envelope. So **every guess is made without
  the row just before it**.
- Good news travels fast: the answer turns over in its colours at once, and
  so does the last row, each bringing the carried row with it
  (`snail_hurry`). A row bought on the card is the last row again.
- Everything that reads colours reads only delivered rows
  (`State.delivered()`, kept as `sent` so a bought row never takes a shown
  row's colours back): the keyboard, the clue rule, the hint, the reactions.
- **Why it is nearly impossible**: an entropy solver that knows the whole
  answer list wins every English word in 3.19 rows on average with colours at
  once, and in 4.59 with them a row late. A person knows no list, and the
  clue rule stops them spending a row on letters alone.
- **The bank** (`content/insane/hiddenword.json`, `.pt.json`, `.es.json`,
  `tools/insane/hiddenword_ladder.py`): every answer graded by that solver
  under Snail Mail, kept when it needs five rows or more, or misses in six.
  English 337 of 968 (278 five, 53 six, 6 missed), Portuguese 221 of 746
  (196 / 25 / 0), Spanish 256 of 762 (218 / 34 / 4). `rung` is the rows it
  took, 7 a miss. Picked through `InsaneBank` like every other bank; an empty
  one falls back to the list.
- Rules add `HW_RULES_STRICT` and `HW_RULES_SNAIL`; Insane's tip is
  `HW_TIP_SNAIL`; the level lines are `HW_LVL_2` "Any word, every clue used"
  and `HW_LVL_3` "Snail Mail: colours a row late".

## 3. Rewards, even silly

All of them wait for a row to show its colours, never for the Enter.

- **A note up the scale**: every green at a place no row had greened plucks
  `combo` a step up the major pentatonic, across the whole game.
- **Gags**, one a row at most, on three in five new greens by hash: **little
  hearts** float up off the tile (`love`), the tile **twirls** a whole turn on
  a hop (`twirl`), or a **sprig** of two leaves pops out of its shoulder and
  waves (`sprout`).
- **Row reactions** (Code Break's words, in a paper bubble over the row's
  right shoulder): a clean miss puts **sunglasses** on the row -- dark lenses
  over its second and fourth letters -- "Cool. Five crossed off."; every
  letter found and not solved **congas**, two hop waves, "Everyone's here!";
  more greens than any row before is "Warmer!", and at four "So close!" with
  confetti.
- **The party**, `PARTY_AT` after the winning row's hop: its tiles **dance**,
  the rows it never needed **bloom into a meadow**, one flower a bed, confetti
  twice, the sprout comes up on the band **in a party hat** beside a card with
  the word and **a silly cheer** (twelve, `HW_CHEER_0..11`, picked by the
  word), the snail gets a hat too, and `STAMP_AT` later **the seal** drops on
  the card: gold with the rows' word (1 "Mind reader" to 6 "Phew!", "Second
  wind" for a bought row), or on Insane the night seal, "Snail Mail" over it.
- `share_glyphs()` gains `🏅 Genius` or `🌙 Snail Mail · Genius`.
- A restored solve shows the meadow, the sprout in its hat with the cheer,
  the seal, and on Insane the snail in its hat.

## 4. Motion

New, on top of the flat spec's: the rows cascade in top to bottom inside the
grid's wide pop; the caret glides to the next bed; the fifth letter makes the
row hop, ready; the sealed turn and the delivery turn; the snail's crawl; the
reactions above; the droop; the seventh row rising; the dance, the meadow,
the stage and the seal's drop. Letters ride their tile's pose (`_move`), so a
dancing, twirling or drooping tile carries its glyph. Under reduce motion: no
gags, bubbles, sunglasses, conga, dance or confetti; flowers stand open, the
snail sits, the seal stands, rows turn in one frame.

## 5. Sound

Re-prompted toward felt, paper and kalimba (the wooden "bonk" read as a
scold): `type`, `erase`, `flip`, `refused`, `hint`, `reset`, `solved`, `lost`,
`enter`. New: `combo`, `warmer`, `so_close`, `all_here`, `cool`, `love`,
`twirl`, `sprout`, `confetti`, `party`, `dance`, `stamp`, `ready`, `droop`,
`out_of_rows`, `row_back`, `post`, `snail`, `snail_hurry`. Rendered on the
fallback key (the first was out of credits); **unheard**.

## 6. Numbers

Draw-call peaks from `tests/_shot_hiddenword.gd -- d=<n> <mode> [rm]`
(810x1440, `--always-on-top`, `opengl3_angle`), one run each:

| mode | peak |
|---|---|
| rest, Easy | 134 |
| rows, Insane (envelopes, snail, sunglasses) | 125 |
| solve, Insane (party, meadow, seal) | 151 |
| out, Hard (droop, card, seven rows, shown) | 157 |
| refuse, Hard | 136 |
| restore, Insane | 129 |
| solve, Medium, reduce motion | 141 |

All far under the 855 budget. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- hiddenword`: PASS. The exit-time leak warnings the
harnesses print are the same on `main`.

## 7. Calls for the user

1. **Snail Mail on the phone**: whether the lavender envelope reads as
   "sealed, not yet" and never as a colour, and whether the snail in the side
   air is big enough to be seen.
2. **The clue rule on Hard** is the genre's known hard mode; it makes Hard
   losable in a way players recognise, but some dislike it.
3. **Out of rows on Easy and Medium** is the card too, and Reset no longer
   replays a spent word there either.
4. **Twelve cheers**: silly on purpose.
5. **Sounds are unheard.**
6. **Review findings, fixed**: the clue rule and the hint read
   `State.clue_rows()` -- rows delivered *and* on screen (`seen`, raised when
   a row's keys land) -- because a quick second Enter on Insane was refused
   by a green still sealed; the host's card is refit while a seventh row
   grows and after a restore (it only refits on spawn and resize, which
   matters where the width binds the cell); a row the snail brings reacts
   before the row that brought it; and "Second wind" follows the rows the
   solve took, not whether a row was ever bought.
