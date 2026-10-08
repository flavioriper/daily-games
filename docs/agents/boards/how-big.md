# How Big?

- **How Big? is the thirty-second card** (2026-10-08, `puzzles/how_big2d.gd`,
  `puzzles/how_big_state.gd`, `ui/faces/how_big_art.gd`; no spec -- asked
  for and built in one sitting while the user was away). It was the game's
  one *turn*, a 3D scene on a dock (`turns/how_big.gd` in git history),
  removed with the 3D game on 2026-09-24. This is that game brought back
  **as a board**: a Puzzles-grid card with four bands, graded on the phone.
  It has no publish, no submit and no crowd, and nothing of the turn host
  came back (`docs/agents/turns-and-backend.md`). The puzzle id is
  `how_big`, as the turn's was.
- **The game it follows is Size It Up, and that name goes nowhere else**:
  not in code, comments, commits or on screen. **Its rules were checked on
  the web on 2026-10-08** (the free daily at sizeitup.games, which says it
  is its own implementation): a fixed silhouette at a known size, a second
  the player resizes, Lock in, then the true size shown over the guess with
  the measurement, how far off and a line about the thing; five rounds a
  day; the grade a ratio, so half and double score alike. Ours matches all
  of that. Kept different on purpose: no zoom (a pair is picked to fit the
  card, so an ant never stands beside a whale -- they meet through a chain
  of neighbours), every round is worth the same 100 (theirs weights the
  later rounds), and there are bands.
- **The grade** (`State.CURVE`) is theirs, anchor for anchor: within 6% is
  100, 12% off 90, a fifth 78, a third 62, double or half 45, three times
  30, five times 0, straight lines between in the log of the ratio. **The
  turn's old curve was one straight line from 1.06 to 5 and gave 59 at
  double**; this replaces it. The truth is drawn in the grade's colour:
  leaf from 78, sun from 45, berry under.
- **One move**: a finger anywhere on the card holds the white silhouette by
  the point it pressed -- pulled away from the answer's foot (its box's
  bottom right corner) it grows, pushed toward it it shrinks; a press
  within 90 px of the foot reads the finger's rise instead. Then **Lock**
  (the actions row's third button, `check_label` → `HB_LOCK`), which is
  final: the white shape stays as an outline where the guess stood, the
  thing grows or shrinks to its true size, and a card at the head of the
  stage gives the points, how far off and the thing's line. The button then
  reads **Next** (`HB_NEXT`; a tap on the card does the same). No Undo on
  any band. Reset puts the answer back where the round began and has
  nothing to give after a lock (`can_reset`). `check()` returns -1 always.
- **The bands**: five rounds on Easy, Medium and Hard, seven on Insane
  (`State.ROUNDS`); what changes is how far apart the two things are, the
  bigger box over the smaller (`State.SPREAD`: up to 2x, 1.3-3.2x,
  1.8-4.6x). **Easy reads the tape**: the answer's caption says "about
  2.3 m" as the finger moves; from Medium it is a question mark until the
  lock. The bulb says which way the truth lies (Bigger / Smaller / about
  right; three, two, one, none). **Easy to Hard cannot be lost**: the day
  ends when the last round is locked, and the points are the result.
- **Insane is the Ladder**: seven rungs climbing from something small, and
  each thing the player sizes crosses the stage to be the next ruler **at
  the size they gave it**, so the scale of every later rung is the player's
  own (the caption says "the size you gave it"). It has **two hearts**,
  spent only on a lock the player watches miss by more than double
  (`MISS_RATIO`); a rung that costs a heart is set straight before the
  next. Hearts and not a move counter, for Trestle's reason
  (`docs/agents/flat-screens.md`, "Insane counts moves"): there is one move
  a round, so a counter would count nothing. Out of hearts is the
  out-of-hearts card: Try again is the same Ladder from its first rung, the
  video gives one heart and the climb goes on from the rung that was lost.
- **The things** (`content/how_big.json`, thirty of them, 4 mm to 25 m):
  ant, ladybird, honey bee, snail, tennis ball, frog, mouse, monarch,
  football, blue crab, cat, rabbit, chicken, dog, sheep, emperor penguin,
  cow, horse, person, bicycle, door, elephant, crocodile, car, great white,
  giraffe, orca, city bus, T. rex, blue whale. Each row has the size in
  metres, the page it came from (`source`: **every size was looked up, none
  written from memory**), whether the number is a height or a length, and
  `from`/`to`: the share of the silhouette's box the number spans (a horse
  is measured at the shoulder, 0.8 of the way up its drawing; a mouse
  without its tail). The bracket is drawn over exactly that span, and
  `State.box_m` turns the number into the whole box, so the picture is to
  scale. The shoulder and body fractions were read off the drawings, good
  to about 0.03. A day is drawn from the table by the day's seed
  (`_pairs`, `_ladder`); no thing appears twice in a day outside the Ladder.
- **A silhouette is data, never an image.** `tools/build_how_big.py` (venv
  in `tools/how_big/.venv`, the pip line in its docstring) turns
  `tools/how_big/items.json` and the vector sources in `tools/how_big/src/`
  into `content/how_big.json` and `content/how_big_shapes.json` (outline
  loops and triangles in the thing's own units, 60-374 points each, 165 KB).
  **Edit `items.json`, not the outputs.** The animals are PhyloPic
  silhouettes under CC0 1.0 (the blue whale Public Domain Mark), which the
  tool asserts on every build, so the game owes no credit line;
  `tools/how_big/SOURCES.md` lists each. The six objects (the balls, the
  bicycle, the door, the car, the bus) are drawn in the tool.
  `tools/how_big/.gdignore` keeps Godot from importing the SVGs as textures.
- **Drawn as**: `_still` (the card, the sky, its clouds, the grass; a
  layout) and `_live` (both silhouettes, the brackets, the grip, and after
  a lock the outline and the truth). `Art.fill` lays a thing's triangles
  under a transform and feathers every loop at the size it is drawn
  (outward round the body, inward round a hole), so a silhouette is
  **rebuilt as it is sized, not scaled** -- `_live` is rebuilt on every
  frame the finger moves or something animates and on no other. The pills,
  the captions, the result card, the seal and the toast are a layer of
  their own. 81-118 draw calls on both drivers. No mascot: the pieces are
  marks, and the win keeps the family's sun and moon.
- **How a round is framed** (`State.frame`): pixels a metre are chosen so
  the ruler is at least 72 px and at most 58% of the stage's width and 60%
  of its height (under the result card), and the truth sits between 1/3.4
  and 1/1.9 of the most the answer can be dragged to -- where in that range
  is the day's lot, so the truth's place in the drag says nothing. The
  answer starts at the ruler's own size (or well off it, when the two are
  within a quarter of each other).
- **Motion that is this board's own**: the truth growing out of the guess
  (0.7 s, the back ease), the result card popping after it, the pair
  walking off before the next, the Ladder's thing crossing to the ruler's
  place and turning to ink on the way, and the size's own click
  (`notch`: one every 8% the answer grows or shrinks, pitched down as it
  gets bigger).
- **The backend's `how_big` game is stale.** `server/functions` still
  publishes a day from its own copy of the old table; nothing reads it. See
  `docs/agents/turns-and-backend.md`.
- **Harnesses**: `tests/_shot_how_big.gd` (rest, drag, lock, rounds, spot,
  hint, reset, out, restore; `pairs` prints a week of every band headless);
  `tests/_probe_perf.gd -- how_big`; `tests/_win.gd -- how_big`.
- **The tutorial** (`ui/hud/how_big_tutorial_diagram.gd`, four pages on
  Medium and Hard, five on Easy and Insane): the board itself on a
  hand-picked pair (`State.setup_fixed`), played through its own input path
  under a drawn finger -- sizing, the lock, the three grades, Easy's tape,
  the Ladder's crossing, a heart going, the bulb. **The page draws the
  board at 0.58**: its pills, grass and result card are fixed heights, and
  at full size a 475 px page leaves 140 px of stage. So the text inside a
  page is about 17 px, smaller than the card's own body text; it reads in
  the shots and was left. The grades page's third lock is 2.7 times too big
  and the hearts page's 2.5, since `State.frame` never lets the answer be
  dragged much past 2.8 times the truth. One `echo` buzz shows in every
  tutorial run's trace and was not chased (the page's own board is silent).
- **The win harness's two failures are not this board's.** `tests/_win.gd`
  read 30/32 on 2026-10-08: Marigold and Drumbeat fail, and fail the same
  way on the harness as it stood before this board touched it (its
  `_waiting` flag, which holds the walk while How Big?'s solver awaits).
- **A size reads "1,6 m" under English on this Mac**: `Locale.number`
  follows the machine, not the chosen language. Shared, not this board's.
- **Not seen on a phone.** Shots and probes on this Mac only: the drag was
  never felt under a thumb. The sounds are one take a cue and unheard by
  the user; the pt and es lines (thirty names and thirty facts among them)
  are unreviewed.
- **Calls made without the user** (2026-10-08): a board with bands rather
  than a turn; Lock/Next on the Check button and no Undo; the drag (any
  point, away from the foot); Easy's tape; the bulb as bigger/smaller; the
  Ladder and its two hearts as Insane; every round worth 100; PhyloPic CC0
  shapes as the source of the animals; the thirty things and the size
  picked inside each quoted range (a 1.65 m person, a 5 m giraffe, a 25 m
  blue whale, a Labrador's 56 cm under a silhouette that is only "a dog",
  a US 2.03 m door); the football drawn black with its hexagons cut out;
  the functions' build no longer copying the table.
