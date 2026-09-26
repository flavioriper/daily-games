# Hedgehogs, flat: the twenty-fourth board

An autumn lawn under leaf piles, with hedgehogs asleep under some of them.
**Rake a pile** and the grass under it shows how many hedgehogs sleep in the
eight cells around it; a nought rakes its neighbours too, and the leaves blow
off in a gust. **Flag** the piles a hedgehog must be under. Rake every bare
cell and the day is done. **A wrong rake is never a loss**: the hedgehog
wakes, curls up grumpy on a rose cell, and you carry on.

**Why this is not Mushroom Patch.** The reference is the same screenshot of
another app's *Campo Minado* that Mushroom Patch was drawn from on
2026-09-20 (`docs/art/concept-hedgehogs-ref.png`, a copy of
`concept-mushroom-ref.png`). The user sent it again on 2026-09-26 as "our
next new game". Mushroom Patch took the picture's field of numbers and its
two chips and deliberately removed the rest:

- nothing is revealed by a tap;
- nothing can be lost;
- the givens are carved, and every mark is a claim that only Check judges.

This board is the part Mushroom Patch left out, which is what the picture
actually shows:

- a **dig** chip and a **flag** chip;
- a tap that **reveals**;
- a **red cell** where a dig went wrong.

It is kept cozy by making the red cell a grumpy hedgehog rather than an
ending. The two boards now split the genre cleanly:

- **Mushroom Patch** is deduction on a fixed field: you mark, and Check judges.
- **Hedgehogs** is discovery: each rake gives you new information, and a
  wrong rake is marked on your record.

The genre ships as Minesweeper, and the reference as *Campo Minado*. **It is
called Hedgehogs and nothing else**, in code, in a comment, in a commit
message and on screen, in every language (board titles stay English, by the
user's standing decision). This document names the other two once, here, in
order to forbid them, the way Word Trail's, Bridges', Paper Planes' and
Knight's specs do.

- Mock, playable, and the reference for every measure:
  `docs/brainstorm/concepts.html#hedgehogs`.
- Decided on 2026-09-26. The user asked for every recommended call while
  away ("do all recommended"), so every choice below is the recommendation,
  open to overturning:
  - the dig is a **rake**, the mine a **sleeping hedgehog**, the flag a
    **twig with a pennant**;
  - a wrong rake **wakes** the hedgehog: it becomes a known hedgehog, is
    counted as `woken`, and never ends the day;
  - the day **opens with one bare patch raked**, and every board is **proved
    by logic alone** from that opening;
  - **chord**: a raked number whose flags match it rakes its other covered
    neighbours;
  - **long press** does the unarmed chip's action;
  - flags are **not needed to win**.

---

## 1. What is built

| File | What it is |
| --- | --- |
| `puzzles/hedgehogs_gen.gd` | The day's lawn: the deal, the flood, the logic solver (`deduce`, `prove`). Scene-free. |
| `puzzles/hedgehogs_state.gd` | The rules as the board plays them: raked, flags, woken, pins, gestures, Undo, Reset, Hint, Check, solved. Scene-free. |
| `puzzles/hedgehogs2d.gd` | The board: the lawn, the piles, the gust, the numbers, the flags, the woken hedgehogs, the win wave. |
| `ui/faces/hedgehog_face.gd` | The hedgehog as a Face (asleep, curled and grumpy, awake). Seated on the board for woken hedgehogs and on the win, in the tally strip, on the win screen and on the menu card. |
| `ui/faces/leaf_pile.gd` | A cell's ground, the pile, the flag and the rake chip's picture as builder shapes, shared by the board, the tray and the menu card. |
| `ui/flat/tile_tray.gd` | A fourth chip set, `LAWN` (Rake, Flag), beside `MOSAIC`, `QUEENS` and `PATCH`. |
| `ui/flat/flat_host.gd` | `"tray": "lawn"` builds it. |
| `core/palette.gd` | The lawn's colours (`LAWN` .. `NUM_INK`). |
| `ui/registry.gd`, `locale/boards.csv`, `ui/menu/vistas.gd`, `ui/menu/card_art.gd` | The card: entry, strings (en/pt-BR/es), banner vista, picture. |
| `tools/gen_sfx.py` | The sound set's prompts. |
| `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/_probe_hedgehogs_gen.gd` | The harness hooks and the generator probe. |

## 2. The rules

- **The lawn** is `cols x rows` cells. `k` hedgehogs sleep under some of
  them, one at most per cell. A cell's **number** is how many hedgehogs sleep
  in the eight cells touching it.
- **The opening.** The day starts with one cell away from the edge already
  raked. Its 3x3 is kept clear of hedgehogs, so it is a nought and floods.
- **Rake** a covered cell:
  - **bare**: it shows its number;
  - **a nought**: its neighbours are raked too, and the flood carries on
    through every nought it reaches;
  - **a hedgehog**: it **wakes**. The cell turns rose, and the hedgehog
    curls up grumpy and stays there, known. `woken` goes up by one. The day
    goes on.
- **Flag** a covered cell: a twig with a pennant. Tap again to lift it.
  - A flag keeps the rake off: raking a flagged cell is refused with a nudge
    and a toast.
  - A flood that reaches a flagged bare cell lifts the flag and rakes the
    cell, since logic has proved it bare.
- **Chord.** Tap a raked number whose flags plus woken hedgehogs around it
  equal the number, and every other covered neighbour is raked. If one of
  those flags is wrong, that can wake a hedgehog.
  - Tapping a number with too few or too many is refused with a toast that
    says which.
  - Tapping a number with nothing covered around it does nothing.
- **Long press** (0.4 s) on a covered cell does the action of the chip that
  is *not* armed. A long press on a number chords, like a tap.
- **Done** when every non-hedgehog cell is raked. Flags are not required.
- **Undo** takes back one gesture (a whole flood, a chord, a flag laid or
  lifted). A woken hedgehog stays awake, and the `woken` count stays: undo
  does not put it back to sleep. A gesture that did nothing but wake a
  hedgehog leaves no history.
- **Reset** goes back to the opening. Woken hedgehogs and a hint's flags
  stay: they are facts, not moves.
- **Hint** plays the next thing logic can prove from what the player can
  see: raked numbers, woken hedgehogs and the hint's own flags, never the
  player's flags.
  - If it can prove a cell bare, it rakes that cell (lifting a flag first if
    there is one).
  - Otherwise it flags a cell that must be a hedgehog. That flag is
    **pinned**: it cannot be lifted, and it wears a sun dot.
  - A hedgehog the player has already flagged counts as known once logic
    proves it, and the hint moves on.
  - Hints use the full rule set (subsets and count) on every level, so a
    hint is never stuck on a board that was proved.
- **Check** turns every wrong flag's pennant rose and shivers it. The marks
  **hold until the next move** (Bridges' rule: a paid-for answer is kept),
  and a toast says how many. `checks` counts it.

**The screen.** The tray is `"lawn"`: the two chips **Rake** and **Flag**,
Mushroom Patch's shape. The actions row holds Reset and Check, and Undo and
Hint sit in the top bar. There is no tip card on any board since `1a04e0a`,
so every explanation is a toast over the foot of the card (Knight's and
Rings' toast).

## 3. The ladder

| Level | Lawn | Hedgehogs | Cell | Logic the proof may use | Opening (cells) | JS, 200 seeds |
| --- | --- | --- | --- | --- | --- | --- |
| Easy | 8x10 | 12 (15%) | 104.0 | singles + count | 12-40 (mean 28.9) | 4.5 deals mean, 25 worst; 0.37 ms mean, 2.3 worst |
| Medium | 9x11 | 17 (17%) | 94.5 | singles + count | 12-36 (mean 26.5) | 9.3 deals mean, 42 worst; 0.68 ms mean, 2.8 worst |
| Hard | 10x11 | 21 (19%) | 93.2 | + subsets, needed at least once | 9-30 (mean 20.7) | 9.4 deals mean, 64 worst; 1.0 ms mean, 6.2 worst |
| Insane | 10x11 | 24 (22%) | 93.2 | + subsets, needed at least twice | 9-28 (mean 19.3) | 26.3 deals mean, 131 worst; 2.5 ms mean, 11.6 worst |

- **The cells.** The bottom slot is Mushroom Patch's without the tip card:
  a 150 tray, a 20 gap and a 130 actions row. That leaves a 1000 by 1180
  board card. A 34 inset and a 72 tally strip leave 932 by 1040 for the lawn.
  - Every level is at Queens' and Nonogram's 103 or near it. The smallest,
    93.2, is Sudoku's 100 less seven.
  - 9x12 (86.7) was rejected for Hard. A thumb here taps one cell and
    nothing else, so unlike Paper Planes there is no larger target to fall
    back on.
- **Insane is the provisional generator row** (CLAUDE.md, "Insane is a
  fourth level"). It is the same size as Hard, three more hedgehogs, and
  must need subsets twice.
- **GDScript, measured while planning** (the port run from the scratchpad
  through `tests/_probe_hedgehogs_gen.gd`, 40 seeds a level, every lawn
  re-proved and 0 failures):

  | Level | Mean | Worst | Deals (mean, worst) | Ungraded |
  | --- | --- | --- | --- | --- |
  | Easy | 1.6 ms | 4.7 ms | 4.1, 14 | 0 |
  | Medium | 4.0 ms | 12.5 ms | 9.3, 33 | 0 |
  | Hard | 5.7 ms | 26.8 ms | 9.9, 61 | 0 |
  | Insane | 16.0 ms | 53.6 ms | 29.2, 104 | 0 |

  GDScript came in about 5x JS here, not the 20-30x feared, so Insane's
  worst is well inside the 194 ms gate and needs no mined bank. The
  `ATTEMPTS` cap and the ungraded fallback stay as the safety net.

## 4. The card

- Registry id `hedgehogs`, title `Hedgehogs`, motto `LET SLEEPING ONES LIE`
  (270 or so at 24, well inside the four-button 496).
- Strings are keys in `locale/boards.csv` (`HH_*`).
- The banner vista is `autumn`.
- The picture is a 6 by 2 strip of the lawn:
  - three raked cells with a 1 and a 2 on them;
  - two leaf piles, one with a flag;
  - one hedgehog asleep on a raked cell, drawn as a `HedgehogFace` seated
    on the strip.

  The piles, the flag and the lawn are one baked mesh through
  `ui/faces/leaf_pile.gd`, the file the board draws with.

## 5. The generator

`hedgehogs_gen.gd` is the mock's generator ported line for line
(`concepts.html`, the `hedgehogs` tab's `hedgehogBoard`, `hFlood`,
`hDeduce`, `hProve`). Cells are ints `y * cols + x` throughout.

- **`BANDS`**: per level `cols`, `rows`, `k`, `subsets`, `need_sub` and
  `open` (min, max), as in section 3.
- **`neighbours(cols, rows, c)`**: the up to eight cells round `c`, in row
  order.
- **`flood(g, open, c)`**: rakes `c` on `open` (a `PackedByteArray`,
  1 = raked). Returns `[cell, ring]` pairs in breadth-first order, `ring`
  being the distance from `c`. A nought spreads to its neighbours that are
  neither raked nor hedgehogs. A hedgehog or an already-raked cell returns
  nothing. **The board times the gust off `ring`.**
- **`deduce(g, open, known, subsets)`**: one round of logic. `known` marks
  hedgehogs known to be there (woken, pinned, or proved). It returns
  `{rule, safe, hogs}` for the first family that decides anything, else `{}`:
  1. **singles:** a raked number whose unknown neighbours are all bare
     (need 0) or all hedgehogs (need == count);
  2. **subsets**, when allowed: one number's unknown set inside another's;
     the difference is all bare or all hedgehogs;
  3. **count:** hedgehogs left 0, so every unknown is bare; or hedgehogs
     left equal the unknowns, so every unknown is a hedgehog.

  `safe` and `hogs` are sorted ascending, so a hint is deterministic.
  **The player's flags are never read.**
- **`prove(g, subsets)`**: plays the lawn out from the opening with
  `deduce`, raking every safe cell (flooding) and marking every proved
  hedgehog. Returns `{ok, rounds, sub, cnt}`, where `sub` counts the rounds
  that needed a subset.
- **The deal** (`board(rng, band)`):
  1. Pick the opening `(sx, sy)` with `1 <= sx < cols-1` and
     `1 <= sy < rows-1`.
  2. Shuffle every cell outside its 3x3 and take the first `k` as
     hedgehogs.
  3. Count every cell's number.
  4. Reject the deal if the opening flood is outside the level's `open`
     range, or if `prove` fails.
  5. If the proof has fewer subset rounds than `need_sub`, keep it as the
     **fallback** (the first such deal only) and try again.
  6. Otherwise accept the deal with `graded = true`.

  After `ATTEMPTS` 400, return the fallback with `graded = false`
  (Sudoku's flag). 0 of 800 seeds reached the fallback in JS.
- **No uniqueness is asked beyond the proof.** A board that logic plays out
  from the opening has exactly one answer consistent with what it reveals:
  every cell it decides, it decides by necessity.
- Seeded only by the `rng` handed in, so a day is the same lawn on every
  phone. The JS mock seeds a mulberry32 from `(seed, band)`; the port takes
  Godot's `RandomNumberGenerator` like every other board, so the port's
  boards differ from the mock's seed for seed. That is expected; the figures
  are the distribution's, not a seed's.

## 6. The state

`hedgehogs_state.gd` holds:

- `g`: the generated board, with `cols`, `rows`, `n`, `k`, `hog`
  (`PackedByteArray`), `num` (`PackedInt32Array`, -1 on a hedgehog),
  `start`, `graded` and `proof`;
- `open`, `flag`, `woke` and `pin`, each a `PackedByteArray` of `n`;
- `woken` (int, never decremented);
- `history`: `[{"raked": PackedInt32Array, "flags": [[cell, was]]}]`;
- `wrong`: the flags Check marked. Cleared on any move.

Its operations. Each returns a small result the board animates from and
never mutates the board's drawing state:

- **`rake(c) -> {kind, cells, rings, from}`**
  - `kind` is one of `"raked"`, `"woke"`, `"refused_flag"`,
    `"refused_pin"` or `"none"`;
  - `cells` and `rings` are the flood's cells and their rings;
  - `from` is `c`;
  - on a raked number it forwards to `chord(c)`.
- **`chord(c) -> {kind, cells, rings, woke: PackedInt32Array, from}`**
  - `kind` is `"chord"`, `"too_few"`, `"too_many"` or `"none"`;
  - `rings` count from the number, each neighbour's flood adding 1.
- **`toggle_flag(c) -> {kind}`**, `kind` being `"laid"`, `"lifted"`,
  `"refused_pin"` or `"none"`.
- **`undo() -> {raked: PackedInt32Array, flags: Array}`**, or `{}` when
  there is nothing to undo.
- **`reset_board() -> PackedInt32Array`**: the cells re-covered.
- **`hint_step() -> {kind: "rake"|"flag", cell}`**, or `{}`, and
  **`apply_hint(step) -> Dictionary`** (the rake's or the flag's result).
  The board spends the hint only when there is a step.
- **`check() -> PackedInt32Array`**: the wrong flags.
- **`is_solved()`**: every non-hedgehog cell raked.
- **`flags_left()`**: `k` minus flags minus woken, for the tally.
- **`share_glyphs()`**: a row per lawn row, 🍂 for a covered cell, 🟩 for a
  raked one and 🦔 for a woken one, then a line saying how many woke. It
  shows the shape of the day, never its answer: a hedgehog that stayed
  asleep is a 🍂 like any other pile.

## 7. The board

`hedgehogs2d.gd`, drawn off `core/motion.gd`'s readers like the other drawn
boards.

**Meshes.** The lawn is two baked meshes:

- **still:** every cell's ground, raked or covered, and every pile at rest,
  with flags and pins. It is rebuilt only when a cell changes state or the
  layout changes.
- **live:** the gust's flying leaves, piles popping back in on an Undo or a
  Reset, flags popping in or out, the check's rose pennants shivering, and
  the hint's ring. It is rebuilt only while something moves.

The numbers are drawn text, one `draw_set_transform` a cell (Nonogram's and
Mushroom Patch's precedent), so they pop in off the same readers. The
woken hedgehogs, and on the win every hedgehog, are `HedgehogFace` nodes in
slots of their own (`docs/art/flat-motion.md` rule 2), made the first time a
cell needs one and kept. At rest nothing rebuilds.

**Motion.**

- **The gust** is the signature. A raked cell's pile loses its five leaves
  when the gust reaches it:
  - at `ring * Motion.WAVE_STEP` after the rake;
  - each leaf flies `LEAF_FLY` 0.9 cells away from the raked cell (a random
    upward drift for the raked cell itself), spinning and fading over
    `LEAF_TIME` 0.45 s;
  - the number pops in (`Motion.pop_in_scale`) `NUM_LAG` 0.12 s after its
    leaves go.

  A chord's rings start at 1 (the number's own ring 0 is the number itself).
- **Woken.**
  - The cell's ground washes to `WOKE_WASH` 0.38 of `Pal.BAD` over the
    raked grass, and holds.
  - The hedgehog pops in `STRAIN` (curled) and shivers once
    (`Motion.shiver_offset`).
  - A toast says so kindly: `HH_WOKE_FIRST` the first time, then
    `HH_WOKE_AGAIN`.
- **Flag.** It pops in (`Motion.pop_in_scale`) and shrinks out over 0.2 s.
  The pile under a flag is drawn at 0.45 alpha so the pennant reads.
- **Refused** (a rake on a flag, a chord that does not match): the cell
  shivers (`Motion.shiver_offset`), with a toast.
- **Undo and Reset** re-cover cells:
  - each pile pops back in (`Motion.pop_in_scale`);
  - Undo goes in the flood's reverse order at 0.012 s a cell;
  - Reset goes out from the opening at `Motion.RESET_STAGGER` by Manhattan
    distance.
- **Check.** A wrong flag's pennant turns `Pal.BAD` and shivers, and holds.
- **Hint.** A sun ring on the cell (`Motion.RING_TIME`); a pinned flag wears
  a small `SUN` dot at its foot.
- **The win.**
  1. Every sleeper still under a pile has its leaves blown off in a wave out
     of the last cell raked, at Chebyshev distance times `2 *
     Motion.WAVE_STEP`, capped at `Motion.STAGGER_CAP`.
  2. Each hedgehog pops in `JOY` and hops once (`Motion.hop_lift`).
  3. The host's win screen follows after `WIN_WAIT` 2.2 s plus the wave. Its
     faces are three `HedgehogFace`s in `JOY`, and its subtitle is
     `HH_WIN_NONE` or `HH_WIN_WOKE_ONE` / `HH_WIN_WOKE_N`.
- **Idle.** Nothing breathes: an idle that rebuilds a mesh costs every frame
  (Caterpillar's lesson). The woken hedgehogs' own Face blink is enough life.

**Input.**

- A touch is resolved on release.
- A press held `LONG_PRESS` 0.4 s fires the other chip's action at once, and
  the release is then ignored.
- A number always chords.
- Taps are ignored only during the entrance (`_busy_until`). A tap
  **during a gust is taken**: the state changes at once and every cell
  carries its own timers, so a second rake mid-gust cannot desync the
  drawing from the state, and a fast player is never made to wait.

**Pieces.** The hedgehog (`ui/faces/hedgehog_face.gd`) is a Face with two
layers, shadow and body, and three looks keyed through `_kind()`:

- `SLEEPY`: eyes shut, drawn upright;
- `STRAIN`: curled into a ball of spines with the snout tucked in and a
  frown;
- `JOY` or `HAPPY`: up on its feet, the snout to the left.

It faces left; the board flips none of them. The pile and the flag are
builder shapes in `ui/faces/leaf_pile.gd`:

- `pile(b, centre, s, cell_id, blow, dir, alpha)`: a mound and five almond
  leaves hashed from the cell id;
- `flag(b, foot, R, wrong)`: a bark twig and a two-tone pennant;
- `grass(b, rect, raked, woke)`: a cell's ground.

**Motion constants.** The board's own are `LEAF_TIME`, `NUM_LAG`,
`LONG_PRESS`, `FLAG_OUT` 0.2, `UNDO_STEP` 0.012, `WIN_LEAD` 0.3 and
`WIN_WAIT`. The drawing's own, in `leaf_pile.gd`, are `FLY` (the spec's
`LEAF_FLY`) and `WOKE_WASH`.
Everything else is a recipe; **nothing is added to `core/motion.gd`**.

**Tally.** A 72 strip over the lawn, inside the card: a small sleeping
hedgehog and "N hedgehogs asleep", which is the count less flags and woken.
It is `Pal.BAD` when negative ("N flags too many"). It is the global count
the solver uses, given free, the way Mushroom Patch's tally is.

**Numbers.** Fredoka 700 (`CozyTheme` wordmark face) at `NUM_SIZE` 0.54 of
a cell, in `Pal.NUM_INK[n]`: 1 leaf, 2 teal, 3 brick, 4 plum, 5 bark, 6
teal, 7 and 8 ink. Noughts draw nothing.

**As built (2026-09-26).** Nothing in this section changed while the board
was built: every line of `hedgehogs2d.gd`, `hedgehogs_state.gd`,
`leaf_pile.gd` and `hedgehog_face.gd` is the plan's code as written, and the
rendered board needed no fix against the mock, which stays the reference.

**Sounds** (`tools/gen_sfx.py hedgehogs`):

| Cue | What it is |
| --- | --- |
| `rake` | dry leaves swept by a soft rake |
| `gust` | an airy leaf flurry, for a flood of more than 6 cells |
| `flag` | a small twig pushed into leaves |
| `unflag` | the twig pulled out |
| `woke` | a tiny grumpy snuffle and a soft downward two-note marimba, never a buzzer |
| `chord` | a quick double leaf sweep |
| `refuse` | a soft muffled wooden bonk |
| `check`, `check_ok` | the check's answers |
| `undo`, `hint`, `reset`, `solved`, `enter` | the family's |

## 8. Measured

Taken while planning, from the planned code assembled in the tree and
reverted: the bare board through the real host
(`tests/_shot_anim.gd -- hedgehogs empty` at `--resolution 810x1440
--always-on-top`) drew **79** draw calls at most over the idle window, with
a mean idle of 4.13 ms (one reading, first of its session, so not a figure
to quote). A headless drive of the board (wake, flag, refused rake, Check,
Undo, rake, Reset, hints to the solve, restore) passed, with `solved` firing
once.

The win screen seats up to 24 `HedgehogFace`s at two layers each, so it is
the heaviest state and the one to watch against the 855 budget.

**Measured at build (2026-09-26, Task 5).** Generator, `tests/_probe_hedgehogs_gen.gd`
headless, 40 seeds a level, GDScript on this Mac: Easy 8x10/12 mean 1.6 ms,
worst 4.6; Medium 9x11/17 mean 4.0, worst 12.5; Hard 10x11/21 mean 5.7,
worst 27.1 (subset rounds mean 2.00); Insane 10x11/24 mean 16.1, worst
**53.5 ms** (subset rounds mean 3.12) against the 194 ms gate; ungraded 0/40
on every level, PROBE PASS.

`tests/_shot_anim.gd` at `--resolution 810x1440 --always-on-top`, two
readings each one after another, the second quoted (first in brackets):

| state | draw calls | idle mean |
|---|---|---|
| bare (`empty`) | **79** (79) | 4.35 ms (4.46) |
| after a rake (default) | **80** (80) | 3.93 ms (4.57) |
| a hedgehog woken (`woke`) | **83** (83) | 3.83 ms (4.06) |
| the win, every hedgehog awake (`solve`) | **115** (115) | 4.21 ms (4.51) |
| after a rake, reduce motion (`rm`) | **80** (80) | 3.68 ms (3.90) |

Mushroom Patch, the control in the same session: **83** twice, 3.47 ms
(3.34). The win's 115 is the heaviest state and far inside the 855 budget.
ANGLE (`--rendering-driver opengl3_angle`, after a rake): **80** twice (idle
9.23 ms, 7.28, not comparable across drivers); the settled frame against the
default driver's differs on 219,714 of 1,166,400 pixels by **at most 1/255**.
The reduce-motion pair 1.5 s apart is pixel-identical (0 of 1,166,400), in
both runs. `tests/_win.gd` solves it through touch (9x11 lawn, 17 hedgehogs,
woken 0, one hint, one Check that found nothing, board fit and HUD true),
24/24 winnable.

The card (Task 6): `tests/_shot_menu.gd -- page3` at `--resolution 810x1440
--always-on-top`, two readings, page three at **175** draw calls both times
(idle 8.14 ms, 8.36 first -- the 120 Hz vsync ceiling, not a measurement),
page one 254; Hedgehogs is the eighth card of page three, beside Knight.

## 9. Open

- **Is it different enough from Mushroom Patch?** The user plays one of each
  back to back and says whether both stay.
- **The hedgehog** is the cast's first new animal since the bee. The user
  judges its three looks on the mock.
- **The long press.** If it misfires on a phone, drop it: the chips are
  enough.
- **The lawn's busyness** under 110 piles on Hard: the pile may want fewer
  leaves.
- **Numbers in colour** is a proposal. The family's other numbered boards
  (Mushroom Patch, Sudoku) keep ink.

## 10. Amendments, as built (2026-09-26)

- **The win strip's tally runs ahead of the wave.** On the solve the tally
  reads all awake (`HH_TALLY_DONE`, "Every hedgehog is awake") a moment
  before the win wave has reached the last sleepers: the text is set from
  the state at once, while the drawing waits out the win delay. Recorded,
  not fixed.
