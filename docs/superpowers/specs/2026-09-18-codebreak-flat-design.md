# Code Break, flat: the second screen on trial — design

Status: built 2026-09-18, branch `feat/codebreak-flat`.
Concept: `docs/brainstorm/concepts.html#codebreak` (2026-09-18) — the mock is
the design, and every number below is its number.
Sibling: `docs/superpowers/specs/2026-09-18-binairo-flat-design.md`, whose
chrome this screen shares row for row.

## 0. The question this answers

Binairo went flat on trial. This asks the same question of a second, very
different board: Code Break is deduction with a memory, so it lives on a
column of history that the island's perspective actively hurts. Both cards
stay on the menu, seeded from the same day, so the two can be played and
judged on the phone.

## 1. Decisions taken with the user (2026-09-18)

- **Both boards stay on the menu.** The flat board takes the `mastermind`
  id; a second entry, `mastermind_island`, keeps `puzzles/codebreak3d.gd`
  reachable and `seed_as: "mastermind"` hides the same code in both.
- **Eight rows can still run out.** Row eight ends the day whether or not
  the code was cracked. The alternative on the concept page — let the ninth
  guess simply be allowed and score the day by rows used — was rejected for
  now: identical rules on both boards are what make the trial a comparison
  of screens rather than of games.

Taken from the mock, marked *decided* there with the user:

- The six code pieces are **six friends with faces**, one silhouette each.
- The eight rows are a **compact history with the active row at full size**.
- **Nothing on the screen may suggest which seat a pip came from** — not the
  pips' arrangement, not their colour, not a face, not the order things
  animate in.

## 2. The rules: `puzzles/codebreak_state.gd`

A scene-free `RefCounted`, the counterpart of `binairo_state.gd`. It holds
the code, the rows played and their scores, the row in hand, which seats a
hint has locked, and the undo history; `puzzles/codebreak2d.gd` only draws
it. The island script keeps its own copy of the same rules until the trial
is decided; whichever board survives, this is the one truth to keep.

The rules are the island's move for move:

| | |
|---|---|
| Difficulty | 0: four of six, no repeats · 1: four of six, repeats · 2: five of seven, repeats |
| Rows | eight; `commit()` sets `lost` when row eight scores short |
| Scoring | `mastermind_gen.score()` — exact, then colour, each code peg consumed once |
| Hint | three, leftmost unlocked seat, takes the code's own friend and locks it; costs no move, not refunded by reset |
| Undo | one place or pop in the row in hand; played rows stay, because their feedback is already known |
| Reset | clears the **whole board** — the island's reset, and every other board's |

`_score()` also returns `kinds`, what each seat was worth. The pouch never
reads it; only a finished game may, once the code is on the table.

## 3. What is on the screen

The chrome is the flat Binairo's, row for row, so the two read as one
family: the same top bar (back, the wordmark in ink with its leaf, undo,
hint with its count, settings), the same day card, the same action row
(Reset in paper, Check in sun), the same tip card with the sprout, and the
same win screen shape. Two rows differ.

**The palette** (`ui/flat/friend_tray.gd`, 150 tall). One chip per friend,
six across the column and seven on the hard difficulty. A chip is a **direct
action, not a brush**: tap it and the friend runs into the first free seat,
which is what the island's tray does. Nothing is ever armed, so nothing is
ever lit; the chips dim together when the row is full or the game is over.
The chips are built on the first `refresh()`, not in `_build()`: how many
there are is the puzzle's difficulty, and the host lays out its rows before
it has a puzzle to ask. The registry names which tray a flat entry wants
(`"tray": "friends"`) for the same reason.

**The tip card** speaks the board's own line. `ui/flat/tip_card.gd` now asks
a puzzle for `tip_line() -> {"text", "mood"}` and only says it; a board
without one keeps Binairo's cycle of rules. Code Break reads its score out
in words after every Check — *"Three sat in the right seat, and one more
belongs somewhere else."* — which no cycle of rules could do. Like the pips,
the sentence never names a seat.

**The six friends** (`ui/faces/`, one Control each, and `friends.gd` as the
one list): sun (amber), moon (periwinkle), leaf (green), berry (rose), cloud
(pale blue) and acorn (tan), with a pink flower joining on the hard
difficulty. One shape per colour replaces the island board's seven carved
pip marks: colour never stands alone and nobody has to learn a legend. The
sun and the moon are Binairo's own faces; `Friends.make()` gives every
friend the mock's R-to-seat ratio so the six sit at comparable weights in
one seat rather than each filling it.

Two things were added to `ui/faces/face.gd` for this:

- `radius_ratio`, so an owner can fix R as a fraction of the rect.
- `plain`, the whole drawing without eyes, mouth or cheeks. The compact
  history draws its friends this way — 62 units is 22 pixels on a phone and
  a face there is a smudge. This is the one place the design knowingly
  departs from "faces on all six everywhere".

The mesh cache is now keyed on R rather than on the rect, since the two no
longer imply each other, and on `plain`.

## 4. The board: one column, one big row

Drawn in the game's own design space. The column is **1000 units wide** (the
screen's 1080 less the host's two 40 margins) and `_column` carries one
uniform scale, so every number here is the mock's own number.

| | |
|---|---|
| Row card | x 28, 944 wide, corner 28, cream on the card's parchment |
| Row number | x 64, 30 compact to 40 at full size |
| Seats | the span x 120 to 810, whatever the length; pitch = 690 / length |
| Piece | `min(150, pitch − 22)`; compact is 0.41 of it |
| Pouch | centred on x 897, 118 × 74 |
| Row height | 82 compact, 190 at full size |
| Code row | label at y 16, lids at y 36, dotted rule 13 under them, rows 26 under that |
| Column height | `36 + piece + 26 + 82 × 7 + 190` — constant, whatever the board does |

**Committing a row slides the board.** Check does not scroll or re-lay the
column: the row just played shrinks from 190 to 82 while the next grows from
82 to 190, the same ease over the same 0.35 s, so the sum is unchanged and
every row between them simply slides. The big row walks down the board as
the game goes on, which is the progress bar.

**Four seats, one x.** Every row — compact, active, and the code under its
lids — puts its pieces on the same seat centres, so the eye reads four
vertical columns of friends. That is what makes a guess comparable to the
one above it at a glance, and it is the thing the island's perspective can
never quite give.

**A seat is one Control** at the full piece size, carrying the socket, its
dotted ring and the friend, and the row's growth is that Control's `scale`.
So a friend's mesh is built once and never rebuilt as its row grows, and the
dotted ring needs one size.

**The score is a count, and nothing about it may read as a map.** The pouch
holds a filled slate pip per friend in the right seat and a hollow ring per
right friend in the wrong seat, piled loose — two bands from two pips up,
centred on however many there are, each jittered a few units. No pip carries
a friend's colour, and no socket is left for a miss: a register of four
sitting at the end of a row of four seats is exactly the thing an eye lays
one over the other, and a filled first slot would then read as "seat one is
right", which it never is. A row that scored nothing shows a dash, because
that is a count too. The pips are also the one thing on this screen that
must not look like a character.

**The row reacts as one, never seat by seat.** A checked row's friends keep
one expression while the game runs. A per-seat expression would name the
seats outright, and even a staggered change is a map. Once the game is over
and the code is on the table, the friends may own their own faces again.

**The code row** is four wooden lids with a carved `?` and a screw, under a
`THE CODE` label. The friends are already sitting under them: they peek when
a Check scores two or more in place, and the lids slide off to the right and
drop away when the game ends.

## 5. Motion

| Moment | What happens |
|---|---|
| Entrance | the chrome slides in row by row as the HUD does; the board's rows fade in from the top down (0.2 s, 0.05 apart), the lids land last with a back ease (0.55 s, 0.06 apart) |
| Place | the friend runs from the palette up to the seat along a low arc in 0.34 s, growing from 0.78; the seats either side nudge 7 away from the impact after 0.24 s |
| Row full | a chip on a full row hops the seated friends instead of placing |
| Send back | a tap hops the friend 34, turns them a quarter and shrinks them out over 0.26 s; the dotted ring comes back under them |
| Hinted seat | a tap only shivers it, and the sprout says so |
| Hint | a ring pulses out of the seat, the friend drops 70 with a back ease, four sparkles rise, the seat takes the sun rim |
| Check | the row dips 8 over 0.4 s; the pips drop one per 0.09 s from +0.35, filled before rings, in the pile's order and not the seats'; the sentence lands at +0.45; the slide runs at +0.78 |
| Peek | two or more in place and the code stirs 10 under its lids at +0.5 |
| Cracked | at +1.05 the lids slide 170 and fall 520 turning, one per 0.12 s; the code pops up beaming with sparkles; the win screen follows at +1.9 (`win_delay()`) |
| Out of tries | the same at +1.1, without the sparkles and with plain smiles; the board goes quiet |
| Reset | the friends shrink out in a wave from the last row back, the pouches empty, the lids drop home |

Everything goes through `core/motion.gd`, so reduce-motion stills the
decoration and keeps the change of state. Verified: a reduce-motion win
lands on the same screen.

## 6. Well done

The flat Binairo's win screen, with one difference: Code Break's answer *is*
a row of four, so showing it is both the celebration and the answer.
`ui/flat/well_done.gd` gained `set_cast(faces, subtitle)` — a board hands it
the characters of its answer and they lay across the art at the board's own
pitch (150 wide, 40 apart), in place of the sun and the moon. The decorative
leaves and stars move out to the edges when a cast is present, since the
middle is no longer empty. Under the board the day card returns with the
time, the rows used and the hints; then a full-width Back to camp. No Next
Level; it is a daily.

## 7. Departures from the mock, and why

- **Reset clears the whole board**, not just the row in hand. The mock's
  reset is kinder, but the island's Reset clears the board and so does every
  other board in the game; identical rules are the point of the trial.
- **No "Try again" pill.** The mock re-deals on a loss. In the game a lost
  day is a lost day: the Check pill dims like every other finished board,
  the code stays on the table, and a fresh code comes from the settings
  sheet's New puzzle. The board reports `is_done()` on a loss, so the whole
  HUD reads it as over.
- **A friend flies in from below the board**, at the fraction across the
  column its chip stands at, rather than from the chip's own rect. The
  chips span the same column the board does, so the run keeps the mock's
  sideways sweep without the board reaching into the host's tray.

## 8. Architecture

| File | What it is |
|---|---|
| `puzzles/codebreak_state.gd` | the rules, scene-free (new) |
| `puzzles/codebreak2d.gd` | the flat board (new) |
| `ui/faces/friends.gd` | the seven friends as one list (new) |
| `ui/faces/{leaf,berry,cloud,acorn,flower}_face.gd` | five new faces (new) |
| `ui/faces/face.gd` | `radius_ratio`, `plain`, cache keyed on R; `Builder.bezier2/3`, `round_rect` |
| `ui/flat/friend_tray.gd` | the palette of friend chips (new) |
| `ui/flat/tip_card.gd` | speaks a board's own `tip_line()` when it has one |
| `ui/flat/well_done.gd` | `set_cast()`, and art that moves aside for it |
| `ui/flat/flat_host.gd` | picks the tray from the registry, asks for `win_delay()` and `flat_win()` |
| `ui/registry.gd` | `mastermind` flat + `mastermind_island` beside it |
| `core/palette.gd` | the friends' colours and chip fills |
| `tests/_win.gd` | its Code Break solver presses whichever tray the shell built |

What the flat chrome asks a board for, all optional and all defaulted:
`palette()` (with a `friend` index), `tip_line()`, `flat_win()`,
`win_delay()`. A board without them gets Binairo's behaviour.

## 9. Performance

Measured on this Mac at 1080 × 1920, four rows played, against the flat
Binairo on the same run and the 855-call budget:

| | draw calls | objects | vertices |
|---|---|---|---|
| Code Break, flat | 252 | 754 | 77,040 |
| Binairo, flat | 378 | 947 | 110,038 |

Frame time is vsync-capped on both (8.33 ms at 120 Hz), so it is not the
binding number here; draw calls are, and both sit well inside the budget.
Two things keep it there, and neither may be undone casually:

- **A dotted ring and the rule under the code are meshes, not draw calls.**
  gl_compatibility pays per draw command (see CLAUDE.md); a dashed circle
  drawn as twelve arcs, on up to forty seats, is four hundred commands.
  `_dash_cache` builds each shape once with `Face.Builder` and draws it as
  one `draw_mesh`.
- **A friend's mesh is built once.** The row's growth is the seat Control's
  `scale`, so no mesh is rebuilt while a row grows.

## 10. Verification (2026-09-18)

- Suite: 2086 passed, 0 failed.
- `tests/_win.gd` windowed: **15/15 winnable**, including `mastermind` on
  the flat shell and `mastermind_island` on the island, both with the camera
  fit check passing.
- Throwaway probes, screenshot each: the entrance, a mid-game column with
  played rows and a hint, the hard difficulty (five seats, seven chips), the
  cracked reveal, the win screen, out of tries, a reset after a loss, and a
  reduce-motion win.
- Two bugs the shots caught and fixed: the paper wash `CozyTheme.dress()`
  hands every Panel had to be dropped **after** `add_child`, not before, or
  the row cards and sockets wear a stain; and a finished game keeps its last
  row in `state.row`, which drew a ghost row under the winning one.

## 11. Amendment: the polish of 2026-09-18

The user brought a re-render of the built screen and asked for it to be
smoother and more elegant, with its animations on Binairo's pattern and that
pattern recorded so the other boards can take it. Four decisions were put to
them and taken as recommended:

- **The walk-down stays.** The re-render draws eight equal rows; the big
  active row that slides down the column keeps its faces legible and is the
  progress bar, so it stays, and every row takes the re-render's dressing
  instead: a card from the first frame (white at full size, parchment warmed
  0.45 toward white in the history, blended continuously on the row's
  bigness), its sockets and dotted rings dimmed rather than hidden, its
  number darkening as it grows.
- **The pouch is on every row from the start, empty.** The re-render's four
  dots in a line are the arrangement section 4 rules out. The pale pill waits
  at each row's right; a score drops into it as the loose pile it always was,
  and the pouch gives a beat as the first pip lands. A full unscored row's
  "?" now sits inside its pouch. An unscored pouch dims with its row; a scored
  one is the record and never does.
- **The chip is still a direct action.** The re-render's bordered sun chip is
  read as feedback, not a mode: a tapped chip takes its friend's colour all
  round for 0.35 s and its friend hops 8 as their twin flies, then both
  settle. Nothing is ever armed.
- **Straight to Godot**, since the screen already had its concept tab and the
  board was built; this amendment and `docs/art/flat-motion.md` are the
  record. No hearts on the day card: on a board they read as tries left.

**The vocabulary** (`core/motion.gd`, "the flat boards' vocabulary";
`docs/art/flat-motion.md`) was lifted from Binairo's inline tweens and both
boards now call it: `press`, `pop_in`, `pop_out`, `drop_in`, `nudge`, and
`Fx2D.ring` in place of the ring class each board carried. What changed on
this screen, moment by moment:

| Moment | Now |
|---|---|
| Entrance | rows pop in top-down from 0.86 with the back ease (0.25, staggered 0.03) instead of fading; the lids land with the squash; two amber sparks come up beside them at 0.9 |
| Seat under the finger | sinks to 0.94 in 0.08, springs back in 0.25 |
| Place | the flight lands with a squash of 0.12 and a puff of five stars in the friend's colour |
| Send back | the pop-out (0.12, a quarter turn, rising 24); the dotted ring pops back in 0.18 |
| Incomplete Check | the empty seats wobble and their sockets flash toward `BAD_TILE` (0.15 in, 0.45 out) |
| Check | the pouch bumps 0.12 as the first pip lands; the played row's card fades to the history tone as it shrinks, for free, since its dressing is a blend on bigness |
| Peek, reveal | the sparks swell and brighten with the stir, and again when the code comes out |
| Cracked | the winning row hops in a wave (-10 over 0.4, staggered 0.04 after 0.25) and beams before the lids go |
| Reduce-motion | the check's beats shorten to 0.15 (`_beat`), so the code is on the table before the win screen rather than after it |

**Measured** on this Mac at 1080 x 1920, through `tests/_shot_anim.gd`
(whose Code Break fill now plays one press a frame through the flat tray,
since a scored row takes about a second to slide): the fullest board, seven
rows scored and the eighth full, **234 draw calls** against the 855 budget
(252 was the figure for four rows before the history wore cards) and an idle
mean of 3.8 ms. `tests/_win.gd` windowed: 9/9 winnable, Code Break cracked
through the HUD. Suite: 2086 passed, 0 failed. Throwaway probes shot the
entrance, a flight with its lit chip, a seated row, the incomplete-check
flash, the hint's drop and ring, a score, the slide, a send-back, the solve
wave, the lids falling, the code out, the win screen, a full row's "?", a
zero score's dash, and a reduce-motion crack landing on the win screen.

## 12. Amendment: the polish of 2026-09-25

Three defects found on the first frames of the day, and four passes the user
picked in chat (no plan document; a bounded polish).

**Defects.**

- **A flight ran under the rows below it.** Each row is added to the column
  after the one above, so a friend running up from the tray to row 3 passed
  *under* the cards of rows 4 to 8. The seat now flies at `z_index` 1 and
  lands back at 0; a lid thrown or dropped at the end rides at 2 for the same
  reason.
- **The pouch overhung a compact row.** At 74 tall in a 72-tall card it ran
  over the card's hem and read as a doubled pill. It now fits to the row's
  bigness like the seats do (`POUCH_SMALL` 0.74, pips, dash and rim with it).
- **The lid's one screw sat on the "?"** and read as the dot of an i.
  The lid is now a plank: a short lit top edge, broken grain kept clear of
  the mark, and a slotted screw in each top corner, all one cached mesh a
  size, so a lid still costs one command over its panel and its mark.
- Found while building: a Check pressed while the last friend was still in
  the air stranded that seat, because the solve hop animates only y and
  stopped the flight that owned x. `_land_seat` stands a seat at rest before
  anything that moves one axis takes it. And the row's arrival bump, stopped
  by the dip that shares its tween slot, left the row at 1.03; the dip resets
  the scale.

**What changed, moment by moment.**

| Moment | Now |
|---|---|
| A seated friend | the socket takes the friend's own chip tint, deepened 0.14 toward its colour (`SEAT_TINT`), with a rim of that colour at 0.45 (`SEAT_RIM`), in the active row and the history alike. The history now reads by colour at a glance. It shows the guess and never the score, so the count-not-map rule is untouched |
| Check | every face in the row squashes at once (0.14 over 0.28): the same beat whatever the score, and with no order to it, so it says "counting" and never "this seat". It is on the faces, not the seats, because a quick Check can land while a seat's flight still owns it |
| The pips | each falls 26 into the pouch, accelerating and fading up over the first 60% of its slice, then lands in a squash that springs back round; the pouch's bump waits for the first landing |
| The next row | gives a 0.035 bump as it finishes growing |
| Peek | the lids rattle as they lift, three swings of 0.07 rad dying out |
| Cracked | the lids are tossed, 0.08 apart: each jumps, spins 1.1 turns outward (the left pair left, the right pair right), drifts 110, falls and fades, with a puff of `WOOD` where it lifted. The code pops beaming, and at 0.8 it and the cracked row hop together seat by seat (-16, 0.08 apart) |
| Out of rows | the lids slide off and fall over 0.85 instead of 0.55, and the code comes out `WORRIED` rather than `HAPPY` |

`WIN_DELAY` goes from 1.9 to **2.5** for the joint hop to land before the
win screen (reveal 1.05 + 0.8 + three staggers + a 0.4 hop). Paper Planes'
2.7 is still the longest.

**Measured** with `tests/_shot_anim.gd -- mastermind` at `--resolution
810x1440`, two readings a state, against the pre-change build shot the same
hour: fullest board **232** draw calls before and after (3.16 ms before;
3.21 and 3.15 ms after), bare board **179** before and after (3.03, 2.92
before; 3.02, 3.07 after), reduce motion 228. The draw count does not move
because every new line of wood is inside the lid's one mesh and the tint is
the socket's own stylebox. Suite 122,583 passed, 0 failed; `tests/_win.gd`
windowed 21/21. A throwaway copy of the harness played a win and a loss and
shot the reveal every 0.2 s: the pips' fall, the toss, the joint hop, the
slow slide and the worried code all read on the frames.
