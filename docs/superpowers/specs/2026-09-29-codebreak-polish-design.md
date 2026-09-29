# Code Break: failing for real, the Shell Game, motion, rewards, cozy sound

2026-09-29. The user asked for the whole pass unattended ("do everything
yourself ... don't worry if you need to redo something on the logic or
design, as long as it keeps the cozy vibe"), so every section here is the
agent's own and open to review after the fact. Built on
`feat/codebreak-polish`.

## 1. Hard and Insane can be failed

Before this pass neither could, really: **Reset wiped the played rows**, so
a player who had read eight scores could clear the board and go again with
all of it in their head -- unlimited rows. And Insane still had three hints
(the 2026-09-23 commit said "no hints" but only Hidden Word's were zeroed).

| band | seats / friends | repeats | rows | hints | Reset clears |
|---|---|---|---|---|---|
| Easy (0) | 4 / 6 | no | 8 | 3 | the whole board |
| Medium (1) | 4 / 6 | yes | 8 | 3 | the whole board |
| Hard (2) | 5 / 7 | yes | **7** | **1** | **the row in hand** |
| Insane (3) | 5 / 7 | yes | 7 | **0** | **the row in hand** |

On Hard and Insane played rows are ink: Reset only sends the row being
filled back to the palette. Undo still works inside the row.

**Out of rows** (every band): the lids rattle but stay on, the row faces go
sleepy, and a card asks: **One more row** (a rewarded video, placement
`"row"`, once a board, left off when no video is ready -- videos stay for
buyers, no free path) or **Show the code** (the old ending: lids slide off,
the code stands up worried, `finish_unsolved()` so the host logs
`puzzle_complete {solved: false}`, which the old ending never did). Back
from the card's absence (the host's Back) also ends it unsolved
(`out_of_hearts == true` is the host's existing hook). There is no Try
again: eight read scores make the same code free, and a fresh code would
not be the day's.

## 2. Insane: the Shell Game

Nothing like it in the Mastermind variants we could find (cut-the-knot's
list, the query-complexity papers): **the code moves**. After every scored
row that did not crack it, two of the lids trade places in plain sight --
they lift, hop over each other like cups in a shell game, and land -- and
the friends under them go with them. The next row is scored against the
code where it now sits.

- Fair: the swap is shown, and it stays shown -- the row that was scored
  just before it wears a small swap mark on its card's hem, a curved
  double arrow between the two columns, so the record keeps every move.
  Colours never change, so a ring means what it always meant; only "right
  seat" has to be carried through the swaps in the head.
- Nearly impossible: five seats, seven friends, repeats, seven rows, no
  hints, and every exact pip read against a code that has since moved.
- The pairs are drawn from the day's rng after the code, one per row, so
  everyone plays the same shuffle and a reopened daily replays it.
- A swap of two seats holding the same friend still happens and still
  looks like a swap: the player cannot tell it changed nothing.
- `State.swaps[g]` is the pair after row g; `State.code` is always the code
  as it sits now; `State.code_at(g)` is what row g was scored against. The
  win screen and the reveal show the code as it sits at the end.

## 3. Motion

- **Flight**: a friend leans into its flight (tilted along the arc's
  tangent) and looks at its seat; the friends already seated glance at it
  as it lands (`Face.look`, 0.6 s).
- **Row fill melody**: see sound.
- **The row's answer**: after the pips, the checked row wears one
  expression (never per seat): JOY at `length - 1` in place or better,
  HAPPY for anything, PUZZLED for nothing at all.
- **Lids are alive**: every 5 to 9 s one lid lifts a little and two eyes
  blink out of the dark under it, then it drops back with a tock. Only eyes:
  no colour escapes.
- **The Shell Game swap** (Insane): the two lids rise, arc past each other
  (one over, one under), land with a squash and a puff of sawdust.
- **Out of rows**: the lids rattle, the active row's friends yawn.

## 4. Rewards, even silly

All keep the rule that **the score is a count and never a map**: a
reaction is the whole row's, never a seat's.

- **Warmer!** A row that beats the best "right seat" count so far (and is
  not the solve) pops a paper bubble by its pouch: "Warmer!", or at
  `length - 1` "So close!" with a burst of confetti.
- **Everyone's here!** Every friend in the code, some in the wrong seats
  (exact + ring = length, not solved): the row does a conga -- two hop
  waves left to right -- and the bubble says so.
- **A clean miss**: nothing scored. The row's friends put on sunglasses
  ("Cool. Five crossed off.") -- a clean miss is good news.
- **The stamp**: the solve stamps a seal on the code by the rows it took --
  1 "Mind reader", 2 "Genius", 3 "Brilliant", 4 "Sharp", 5 "Well read",
  6 "Steady", 7 "Phew!", later (a bought row) "Second wind". Gold; on
  Insane the night-blue seal with a crescent and "Shell Game" over the
  word. The share glyphs gain a line: `🏅 Genius` / `🌙 Shell Game · Genius`.
- **Party**: after the joint hop, hats pop onto the code and the row that
  cracked it, and two confetti sweeps. `win_delay()` grows to cover it.

## 5. Sound

Same family as ever (soft wood, kalimba, marimba, glockenspiel, paper; up
is good, down is not yet, never a buzzer).

- Re-prompted toward felt and kalimba: `check` (the low marimba boops read
  as a scold on Binairo, same fix), `locked` ("bonk"), `full`.
- `note`: one kalimba pluck layered under `place` at -4 dB, climbing the
  major pentatonic by the seat filled, so a row filling left to right plays
  a little tune (whatever order it fills in, it is the seat's note -- the
  guess, never the score).
- `pip`: a glass bead into a cloth pouch, one per pip as it lands, each a
  step higher; `score` is kept for a row that scored nothing.
- New: `warmer`, `so_close`, `all_here`, `cool`, `shuffle`, `peek`,
  `stamp`, `party`, `confetti`, `out_of_rows`, `row_back`.

## 6. Verification

No new permanent tests (MVP). Parse checks, the suite, the win harness,
throwaway probes: Reset on Hard keeps played rows; Insane's swaps are the
same for the same seed and a guess is scored against the moved code; out
of rows opens the card, One more row adds a row, Show the code ends it
unsolved; restore of a finished Insane daily replays the swaps. Draw calls
on `opengl3_angle` at 810x1440 under 855.
