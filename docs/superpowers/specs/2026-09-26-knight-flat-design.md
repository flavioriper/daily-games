# Knight, flat: the twenty-third board

A paper chessboard on a garden table. **Your cream knight hops in Ls; take
the rose king to win.** The king never moves, but one to three rose knights
stand guard, and **every rose knight answers every move you make**, hopping
toward you. Land where one can reach and it takes you: the board shakes and
slides back one move, and nothing is ever lost.

The reference is a screenshot the user supplied of a Portuguese app's
*Cavalo*. **It is called Knight** in code, in a comment and on screen, in
every language (board titles stay English, by the user's standing decision).

- Mock, playable, and the reference for every measure:
  `docs/brainstorm/concepts.html#knight`.
- Decided with the user on 2026-09-26, before a line was written:
  - the rose knights **chase**: they move after you;
  - their rule is **greedy and fixed** (section 2), so every day can be
    searched and proved;
  - being caught **rewinds one move**; nothing is lost for good;
  - the king **stands still**, and there is **no move limit** below Insane;
  - the dressing is **cozy chess**;
  - you may **take a rose knight** by landing on it (proposed in the design,
    approved with "build it").

---

## 1. What is built

| File | What it is |
| --- | --- |
| `puzzles/knight_gen.gd` | The day's board: the deal, the rose rule (`step`), the breadth-first proof, the naive-line filter. Scene-free. |
| `puzzles/knight_state.gd` | The rules as the board plays them: position, history, Undo, Reset, hint, the Insane budget, solved. Scene-free. |
| `puzzles/knight2d.gd` | The board: meshes, the tap, the hop, the answer, the catch and rewind, the topple. |
| `ui/faces/chess_piece.gd` | The drawing: the carved knight (either side, facing either way) and the rose king. Builder shapes, shared with the menu card. |
| `core/palette.gd` | The table's colours (`CHESS_LIGHT` .. `CROWN_DEEP`). |
| `ui/registry.gd`, `locale/boards.csv`, `ui/menu/vistas.gd`, `ui/menu/card_art.gd` | The card: entry, strings (en/pt-BR/es), banner vista, picture. |
| `tools/gen_sfx.py` | The sound set's prompts. |
| `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/_probe_knight_gen.gd` | The harness hooks and the generator probe. |

## 2. The rules

- **Your move** is one knight hop to any square on the board. Landing on the
  king **wins at once**, before anything answers.
- **Taking.** Land on a rose knight and it leaves the board.
- **The answer.** Then the rose knights move, one at a time in a fixed
  order (their index in the deal). Each one:
  1. takes you if it can reach your square;
  2. otherwise jumps to the square nearest you in knight moves on the empty
     board, ties going to the first L clockwise from up-right
     (`(1,-2), (2,-1), (2,1), (1,2), (-1,2), (-2,1), (-2,-1), (-1,-2)`);
  3. never lands on its king or on another rose knight;
  4. stands still if it has nowhere to go.

  A later knight sees the earlier ones' new squares.
- **Caught.** The rose knight hops onto you, the board shakes, a beat
  passes, and everything slides back to the position before your move. The
  move is not counted and not kept in history.
- **Insane only:** a budget of the shortest line plus `SLACK` 2 moves,
  drawn as "N moves left" centred under the board, Rings' way (the day card
  is the host's). Undo gives a move back.
  With none left, a tap is refused with a tip saying to undo or reset.
- **What the board shows.** Your legal squares carry a sage dot.
  - Every square a rose knight reaches *right now* carries four rose corner
    ticks. Those are exactly the squares where you would be caught.
  - A legal square that is also in reach shows a rose ring instead of the
    dot. It stays tappable: the board teaches by answering, not by refusing.
  - A legal square holding a rose knight or the king gets a sage ring round
    the piece.
- **A hidden structure.** A knight always changes square colour, so both
  sides flip every turn.
  - A rose knight on your colour at the start of your turn can reach you,
    and you can never take it.
  - One on the other colour can never reach you, and you can take it.
  - Only a boxed-in knight that stands still changes sides.

  Nothing on screen explains this; the corners make it visible.

Nothing wrong can sit on the board, since a catch is undone as it happens,
so there is **no Check**. The screen is Pinwheel's shape: `"tray": "none"`,
`"actions": false`, with Undo, Reset and Hint in the top bar and the tip
card alone at 140.

## 3. The ladder

| Level | Board | Rose knights | Start distance | Shortest line | JS, 40 seeds |
| --- | --- | --- | --- | --- | --- |
| Easy | 5x5 | 1 | >= 3 Ls | 4-6 | 0.3 ms mean, 2.1 worst |
| Medium | 6x6 | 2 | >= 3 | 6-9 | 0.5 ms mean, 2.3 worst |
| Hard | 7x7 | 2-3 | >= 4 | 8-12 | 1.4 ms mean, 4.6 worst |
| Insane | 8x8 | 3 | >= 4 | 10-16, budget +2 | 3.4 ms mean, 9.9 worst |

All 160 deals measured landed in range, with no fallback taken. Insane
needs no mined bank: generation is cheap. GDScript runs roughly 20-30 times
slower than JS here, which still leaves about 300 ms of worst case against
the 194 ms gate. **This is the one figure to check first in the port.** If
it misses, lower the attempt cap or mine Insane like Rings.

## 4. The card

- Registry id `knight`, title `Knight`, motto `TAKE THE KING`.
- Strings are keys in `locale/boards.csv` (`KN_*`).
- The banner vista is `meadow`.
- The picture is the cream knight mid-hop over two squares toward the
  crowned rose king, with one rose knight beside him. It is one baked mesh,
  drawn through `chess_piece.gd`.

## 5. The generator

`knight_gen.gd` is the mock's generator ported line for line
(`concepts.html`, the `knight` tab's `knightBoard`).

- **`dist`**: the knight-move distance between every pair of squares, by BFS
  on the empty board, built once per size.
- **`step(you, foes, to)`**: section 2's turn. It returns the new position
  and `won`, `took` (a foe index or -1), `caught` (a foe index or -1), and
  each foe's `[from, to]` for the board to animate. **It is the single rule
  both the state and the proof call.**
- **`solve(you, foes, cap)`**: a breadth-first search over positions keyed
  `you|foe,foe,...` (a taken foe is -1). Moves that get you caught are
  pruned. It returns the shortest winning line as the squares you land on,
  or none within `cap`.
- **The deal.**
  1. Shuffle the squares with the day's seeded RNG.
  2. The first square is the king.
  3. The rose knights take the first squares within two Ls of the king.
  4. You take the first square at least `far` Ls from the king.
  5. Reject the deal if:
     - you start inside a rose knight's reach;
     - **the naive line wins**: hop to the square nearest the king (ties by
       L order) forever, and see if it takes the king within 40 moves
       without being caught or repeating a position;
     - `solve` finds no line within the level's `max`.
  6. Accept the deal if the line is at least `min`.

  After 1,500 attempts, return the longest line found. No run of 160 needed
  that fallback.
- **No uniqueness.** This is a route puzzle, like Rings: any winning line
  counts.

## 6. The state

`knight_state.gd` holds:

- the deal: `size`, `king`, the opening `you` and `foes`, and `opt` (the
  shortest line's length);
- the live position;
- a history of positions;
- `moves`, `hints_left` (3) and `budget` (Insane: `opt + SLACK`, else 0).

Its operations:

- **`play(to)`** checks the move is legal and within budget, runs
  `Gen.step`, and returns the step's result.
  - If `caught`, the position is **not** committed; the board animates the
    catch and then asks the state for nothing.
  - Otherwise it pushes history and commits.
- **`undo()`** pops history. **`reset_board()`** returns to the opening and
  clears history.
- **`hint()`** runs `solve` from the live position and plays its first move.
  With no line, the tip says to undo or start again. A hint costs a move like
  any other.
- **`reach()`** is the set of squares in any rose knight's reach, for the
  corners. **`legal()`** is your moves.

## 7. The board

`knight2d.gd`, drawn off `core/motion.gd`'s readers like the other drawn
boards.

**Meshes.** The field is two baked meshes:

- **still:** the frame, the squares and their bottom shades. Rebuilt on a
  relayout only.
- **live:** the trail, the corners, the dots, and every piece. Rebuilt only
  while something moves.

At rest nothing rebuilds. The dots' gentle pulse is dropped in the port
rather than paid for every frame (Caterpillar's lesson).

**Motion.**

- **Your hop.** The knight travels along the L, eased by `sineIO`, and rises
  on an arc of `HOP_ARC` 0.55 cells at mid-flight. It lands with a squash
  (`LAND_TIME` 0.2, `LAND_SQUASH` 0.14, the mock's own), a shadow shrinks
  under it in the air, and a piece in the air draws over everything.
- **The answer.** The rose knights hop the same way.
  - The first starts `ANSWER_GAP` 0.08 s after you land.
  - The rest follow at `ANSWER_STEP` 0.09.
  - Each faces you.
- **A take.** The taken rose knight squashes flat and fades in 0.25 s under
  a rose puff (`Fx2D`).
- **A catch.**
  1. The rose knight hops onto you, and your knight shows as a faded ghost
     under it.
  2. The board shivers (`Motion.shiver_offset` at triple amplitude).
  3. It holds for `CAUGHT_HOLD` 0.55 s.
  4. Everything slides back in `SLIDE_BACK` 0.32 s, and a taken knight pops
     back in.
- **Undo and Reset** play the same slide back, with Reset staggered at
  `RESET_STAGGER`.
- **Input.** Taps are ignored while the board is moving.
- **The win.** The king tips over (`backOut` to 1.2 rad about his foot), a
  gold ring and two sparkle bursts rise, and `WIN_WAIT` 2.2 s later the
  host's win screen, with the subtitle KN_WIN.
- **The trail.** A faint dashed line joins the squares you have landed on.

**Pieces.** A piece's drawing is `PIECE` 1.25 cells of its own unit,
standing 0.04 cells above centre so the ear rises into the square behind.

- The knight is one soft outline: head, ear and muzzle on a plinth, with
  three mane strokes, an eye with a glint, a nostril and a blush.
- The king is a rounded body under a gold three-point crown with a sleepy
  face. His eyes are crosses once he has fallen.

**Motion constants.** The board's own are `PIECE`, `HOP_ARC`, `JUMP_TIME`
0.3, `ANSWER_GAP`, `ANSWER_STEP`, `CAUGHT_HOLD`, `SLIDE_BACK`, `WIN_WAIT`,
`LAND_TIME`, `LAND_SQUASH`, `TAKE_TIME`, `MARK_FADE`, `TOPPLE` and
`TOPPLE_TIME`. Everything else is a recipe; **nothing is added to
`core/motion.gd`**.

**Tips.** These are keys, and each board state speaks one:

- the opening's rotation: tap a dot, take the king, they answer, the
  corners, taking;
- "Caught! ..." on a catch;
- "Taken. ..." on a take;
- the hint's line;
- "No moves left ..." once the Insane budget is spent;
- "A knight moves in an L ..." on an illegal tap, with your knight
  shivering.

**Sounds** (`tools/gen_sfx.py knight`): `hop` (soft wood tap), `answer`
(lower, felt), `take` (bright wood knock), `caught` (a soft down-step, never
a buzzer), `slide` (paper), `hint`, `reset`, `solved` (marimba run and a
toppling clack), and `enter`.

## 8. Measured

**Generator, GDScript on this Mac** (`tests/_probe_knight_gen.gd`, 40 seeds a
level, second reading): Easy 0.8 ms worst, Medium 11.4 ms, Hard 40.1 ms,
Insane 120.0 ms (mean 32.3 ms) -- comfortably under the 194 ms gate, once
`hop_table` caches the knight-move table per board size (section 10, item 7
below; the first reading, before that cache, put Insane at roughly 230 ms).
Shortest
lines measured 4-6 / 6-8 / 8-12 / 10-16, matching section 3's table, all 160
boards verified.

**Draw calls** (`tests/_shot_anim.gd -- knight` at `--resolution 810x1440
--always-on-top`, second of two readings a mode):

| Mode | Draw calls | Idle |
| --- | --- | --- |
| bare | 67 | 2.78 ms |
| played | 66 | 3.45 ms |
| caught | 66 | 4.79 ms |
| solve | 71 | 3.50 ms |
| ANGLE, played | 66 | 5.07 ms |

All well inside the 855 budget. ANGLE's 66 matches the default driver's
`played` reading exactly. The Pinwheel control run in the same session read
67 dc / 3.39 ms idle: the shared chrome has grown since Pinwheel's own
recorded 56 bare / 57 played (2026-09-26's polish pass), so boards are only
comparable within a session, not against another board's own spec figure.

A reduce-motion pair was not taken this pass.

**Win harness**: `tests/_win.gd` reports `PASS knight ... hud=true`,
`winnable=23/23` (see section 10, item 4 for the entrance-lock race the
harness had to be adapted around to get there).

## 9. Open

- **Is it a puzzle?** With the corners showing, you are caught only by
  choosing to be. The user plays the mock and says whether the corners stay
  on every level.
- The dot pulse is dropped in the port (section 7). If the user misses it,
  it goes in a small third mesh.

## 10. Amendments, as built (2026-09-26)

Everything above is what was agreed; these are the places the build changed
the design, and why. They are the record now.

1. **Insane's moves-left line moved off the day card** (section 2): it is
   drawn centred under the board itself, Rings' way, rather than shown on the
   day card, because the day card belongs to the host and the board has no
   door into it.
2. **The win screen is the host's** (section 7): Knight ends on the shared
   win screen with the subtitle `KN_WIN`, the same screen every other board
   uses, rather than a bespoke small-board-and-route picture of its own.
3. **The landing squash is the board's own** (section 7): `LAND_TIME` 0.2 and
   `LAND_SQUASH` 0.14 (the mock's own numbers), not `Motion.bump_scale`. The
   board's own constants grew past section 7's original list to include
   `TAKE_TIME`, `MARK_FADE`, `TOPPLE` and `TOPPLE_TIME`.
4. **The whole entrance is locked, not just the marks' fade-in.** For about
   0.8 s after `build()` (`Motion.ENTER_DELAY + 0.2 +
   Motion.stagger(foes.size() + 1, 0.07) + Motion.POP_IN`), the corner marks
   stay hidden and both a tap and Hint are refused (`_busy_until`), so nobody
   can act before the opening deal has finished popping in. This raced
   `tests/_win.gd`'s fixed seven-frame gap from opening a board to driving
   its first scripted hint press, which landed inside the lock and silently
   no-opped (`hints_used` stayed 0, so the harness's own `hud` check failed).
   The ruling kept the board's lock and adapted the harness instead: fix
   round 1 clears `_puzzle._busy_until` immediately before `_solve_knight`'s
   opening hint press, the same way the loop already clears it before its own
   taps -- see the win-harness line in section 8.
5. **A hint counts as a move.** `hint()` plays the shortest line's next hop
   through the same `_play()` a tap uses, so `moves` increments and, on
   Insane, the hint spends from the same budget as any other hop -- there is
   no free look.
6. **A Reset or Undo cancels the turn's pending timers.** Every animated
   sequence (a hop, an answer, a catch's shake-and-slide) captures the
   board's `_turn` counter when it starts and checks it again before acting;
   `_slide_to_state()`, called by both `undo()` and `reset_board()`, bumps
   `_turn` first. A catch or an answer already in flight when the player
   resets or undoes therefore finds its captured turn stale and does nothing,
   rather than playing out on a board that has already moved on.
7. **The generator's numbers moved from the brief** (section 5, section 8).
   `solve` takes an optional `max_nodes` (`NODE_CAP` 1500, bounding
   generation's own search only -- a live hint's `solve` call is unbounded);
   the knight-move table (`hop_table`) is now cached once per board size
   rather than rebuilt on every call, which is what brought Insane's worst
   case down from roughly 230 ms to 120.0 ms, comfortably under the 194 ms
   gate; and `ATTEMPTS` is 600, not the 1,500 this spec named above.
