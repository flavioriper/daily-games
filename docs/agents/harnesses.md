<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## What the harnesses actually measure

**Run a render harness at `--resolution 810x1440`, never `1080x1920`**
(measured 2026-09-19). This Mac's display cannot show 1920 rows, so the
window clamps to 1080x1676, and `stretch/aspect="expand"` then keeps the
height and *widens* the canvas: `get_visible_rect()` comes back
**1237x1920**, 15% wider than the phone the game is drawn for. `810x1440`
and `720x1280` both come back exactly **1080x1920**, which is the design
space every layout in this file is written against.

Be precise about what that spoils and what it does not, because most of the
figures here were taken with the old flag:

- **Width-sensitive layout is wrong at the old flag, and measurably so.**
  The first screen's card measures **320** wide at 810x1440 and **372** at
  1080x1920 -- and 320 is the number the card-art budget, the 320 by 118
  picture box and the "about seventeen characters a line" of `short` are all
  written against. A frame shot at the old flag showed cards 16% wider than
  the phone will, with the air between them wrong to match.
- **Height-bound cells are the same either way.** Hidden Word's tile is 149
  at both, because six rows of five in a 9:16 slot are bound by the height;
  so is its 801 by 964 block. What differs is the card *around* it: 1000
  wide against 1157.
- **Draw calls did not move.** The first screen reads 311 at both flags on
  the same build (2026-09-19), so the counts recorded in this file are not
  invalidated by the width -- and the 855 budget is unaffected. Frame times
  were not compared across the two and no claim is made about them.
- **`--resolution` is a Godot *engine* flag: it has to come before
  `--script`, never after** (Mushroom Patch's spec, 2026-09-20). Written
  after the `--` it is handed to the script as a user argument instead --
  `OS.get_cmdline_user_args()` sees it and the engine never does -- and the
  run silently falls back to the default, unflagged window (1080x1676 on
  this Mac) rather than erroring. The tell was in the numbers it produced: a
  first-screen card measured 372-373 wide, the 1237-wide canvas's figure,
  not 320's. A whole round of a spec's layout numbers was retaken and
  corrected once this was found; treat any card measuring near 372 as proof
  the flag landed on the wrong side of `--script`.

What has *not* been rechecked is every older recorded layout number taken
from a frame at the old flag. Treat a pixel measurement in this file that
predates 2026-09-19 as taken on a 1237-wide canvas until it is re-shot; a
draw-call count, a budget figure or a design-space constant is fine.

## Untangle's own harness (2026-09-29)

`tests/_shot_untangle.gd` plays the ring through the board's real input path
(press, motions, release) and shoots numbered frames to its `SHOT_DIR`
(edit the constant or pass `out=<dir>`):

    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_untangle.gd -- d=0..3 <mode> [rm]

Modes: `rest hold taut carry plan back wrong answer out hint undo reset perf
idle enter restore howto toys soak`. `back` plays the answer but for its last
move, then Undo and Reset (ropes that left the ring come back). The harness
sets the board's `mouse_filter` to ignore: it feeds `_gui_input` itself, and
the real pointer hovering over the always-on-top window was carrying a held
peg off mid-run (a board whose harness calls `_gui_input` directly wants the
same). `plan` plays the dealer's answer (kitten included on
`d=3`, at 2.7 s a move, because she holds input for a second); `out` pokes the
thread to one stitch and makes one bad move; `perf` and `idle` print the mean
frame time and peak draw calls over a window with no screenshots (a
`save_png` costs tens of ms and inflates any reading taken across one).
`tests/_win.gd -- untangle` plays a move a frame and needs the board's
`settle_now()` between drags (its flights and holds are on a clock).

## The performance probe (2026-10-01)

**A harness that frees the tutorial card releases the clock**
(`_host._hold_clock(false)`, 2026-10-03): the card holds the board's clock
and only its Continue lets it go; Drumbeat pauses its song under a held
clock.

**Keep the display awake** (2026-10-02): a sleeping display freezes every
windowed harness's shots (each frame the same; ANGLE reads back zeros) and
skews its milliseconds, so wrap runs in `caffeinate -d -i -u`.

`tests/_probe_perf.gd` opens one board at one difficulty, idles, then plays
right moves through the board's own `_gui_input`, and prints each window's
frame time (mean, p95, max), the renderer's CPU share, peak draw calls,
spikes over 25 ms and any move whose script took over 4 ms:

    godot --path . --resolution 810x1440 --always-on-top \
        --rendering-driver opengl3_angle \
        --script res://tests/_probe_perf.gd -- <id> d=<0..3> [fill] [x=<exp>] [howto shot=<s>]

`fill` plays every right move but two before the idle window (a full
board); `x=board|host|hide:<Node>|nowash|faces|parts|undo|bal_warm` switches one
thing off (or times the parts) to see what it costs; `howto shot=1.5`
leaves the tutorial up and shoots each page to /tmp/probe_<id>_p<n>.png,
each page `gap=<s>` after the last (1.8 by default; a lesson's later moments
need 4-7, with `to=<s>` moving the run's end past PLAY_TO).
`fill` leaves two moves, or two whole gestures where a board's moves are a
gesture's events (`_keep`; Shikaku's drags are five each). `x=log` prints
every frame for a moment after each move; `x=confetti` fires one burst
early; `x=sk_markers|sk_numbers|sk_count` are Shikaku's; `x=tn_count` (times one
ground build) and `x=tn_trees|tn_tents|tn_chips` (hide one cast) are Tents'; `x=lu_count`
(one court build, a full rebake, the beams) and
`x=lu_lamps|lu_cats|lu_life|lu_veil` (hide one) are Light Up's; `x=ol_count`
(one figure cast, with its vertex, index and look counts) is One Line's; `x=ng_count`
(one floor build, with its vertex, index, shape and colour-cache counts) is Nonogram's; `x=hw_count` (a grid build every 2 s, with its vertices) is
Hidden Word's; `x=wt_count` (a field, slots and air build every 2 s, with
the field's vertices) is Word Trail's; `x=mp_count` (a floor and a ground build every 2 s, with
their vertices) is Mushroom Patch's; `x=sd_count` (a grid build every 2 s,
with its vertices) is Sudoku's; `x=br_count` (a board build every 1.5 s,
the runs and islets timed apart, with each mesh's vertices and the cached
run looks) is Bridges'; `x=fl_count` (a rest-mesh build, a handed-back
build, the still mesh and the lantern paint, timed every 1.5 s, with their
vertices) and `x=fl_lanterns` (every lantern hidden) are Fairy Lights'; `x=pp_count` (a field and
a still build every 1.5 s, the dots', leaves', contrails' and planes' share)
is Paper Planes'; `x=rg_count` (every station rebuilt from its look and
the ring in hand built, every 1.5 s, with their vertices) is Rings'. `x=sb_count` (the light traced and the live, air, bed and glass built every 1.5 s, once with a piece held, with their vertices), `x=sb_parts` (Sunbeam's meshes dropped one at a time, render-cpu over a second each) and `x=sb_frozen` (the board's redraw stopped) are Sunbeam's; `x=kn_count` (a ground build, a handed-back one and a pieces build every 1.5 s, with their vertices, hops and brambles) and `x=kn_relay` (the table and the still made again, as the win card's relayout did) are Knight's; `x=hh_count` (every band rebuilt, the live mesh and a whole row rustling built every 1.5 s, with their vertices, one band's puts and mesh timed apart and the looks' sizes), `x=hh_relay` (the lawn and the relayout the win card does), `x=hh_calm` (no breeze, for a shot at rest that is the same run to run) and `x=hh_hud` (the ?, Undo and Reset pressed as a player would) are Hedgehogs'; `x=mg_count` (every per-frame builder timed against the board as it stands, every half second, with vertices) and `x=mg_hud` (the ?, a shot, Undo and Reset as a player would, no moves played) are Marigold's; `x=pg_count` (the bands, live layers, head layers, table and pegs made again every half second, with their vertices), `x=pg_relay` (what the win card's relayout makes again, timed) and `x=pg_hud` (the ?, a stroke, Undo, a tap and Reset as a player would, no moves played) are Pixel Garden's; `x=tr_count` (every 1.5 s, what the board's script cost a frame -- its process with the sim's steps, a bridge build, the front layer -- with the two meshes' vertices), `x=tr_win` (every frame split into the nodes' process, the draw and the rest, printed across the solve and for any frame over 25 ms, with the board's own maxima) and `x=tr_hud` (the ?, Undo, Go, a test held under the card, Reset as a player would) are Trestle's; `x=db_count` (where the song is every two seconds, with the frame's script time, draw calls and looks made), `x=db_hud` (the ?, the settings and Reset mid-song: the song must pause, wait and go on with a tap) and `x=db_spike` (every frame over 20 ms with what was on screen) are Drumbeat's, and `song=parade|festival|gallop` plays another song than the day's; `x=cue_late` and `x=confetti_late` fire the streak's cues or a burst inside the idle window, to catch a first-time hitch. `lang=<code>` opens the board in that language (the tutorial's pages in each). `rm` turns reduce motion on as the
board opens (with `howto`, the tutorial's still pages). Each
window also prints its mean draw calls beside the peak.
Tents' moves sweep each row into cairns a run at a time, then tap the
answer's tents. Light Up's tap the answer's lamps in. One Line's draw the
planted walk as one drag (a press, a motion a post, the release; `_keep`
3). Nonogram's drag each row's runs of the picture as strokes (`_keep` 3).
Queens' drag a row of crosses across every other row (one event a step),
then tap the answer's queens in (a tap crosses a bare seat, a second seats
her). Mushroom Patch's go a row at a time, the pebble chip armed and a pebble
tapped on every bare cell, then the mushroom chip and the row's mushrooms.
Word Trail's trace every word along its path, a press, a motion a tile
and the release (`_keep` the last word's events). Sudoku's tap each empty cell in reading order and pick its answer's chip
(`pick`, `_keep` 4). Bridges' lay every plank of the answer as a drag from one islet to the
other (a press, a motion over the far islet, the release). Fairy Lights'
tap every piece round to its answer in reading order, a tap a step. Paper
Planes' tap the deal's own order, each plane on its head. Rings' play the
solver's line from the deal, a tap lifting the top ring and a tap dropping
it, up each station's column. Caterpillar's draw the answer as one drag (a press on
leaf 1, a motion a square, the release; `_keep` 3). Knight's tap the shortest line from the opening (`Gen.solve`), a hop waiting at the front while the last one still plays out. Hedgehogs' clear the lawn in reading order, a sleeping hedgehog flagged (the flag chip armed for the tap) or a bare pile raked, picked at the move (the hedgehogs walk on Sleepwalkers) and waiting while a wake or a walk holds input; the list is cut after each move to what a copy of the lawn still needs up to its last rake. Marigold's shoot a seed a move, the aim set to the angle (Sweethearts' banked proof from the opening, else the sun's own `best_angle()`, a third of a second each, the probe's cost), waiting while the shot plays. Pixel Garden's copy the picture row by row, a stroke a run of one colour (the chip picked when the colour changes, a press, a motion a peg, the release; `_keep` the last two strokes). Sunbeam's drag every piece home along its rail (a press, a motion a third of a peg, the release) on the shortest way that never lets go with the light on a sleeper (a BFS over arrangements like `Gen.dark_path`). Drumbeat's are not moves a step: a bot on the frame starts the song as the play window opens and strikes every berry on its drum as it reaches the ring, a ribbon kept, a golden bar rolled at twelve a second (`to=40` plays a song through the win). Trestle's lay the day's proof a member a move, each a drag from one end to the other (the chip tapped when the material changes), then press Go, so `to=36` plays the build, the whole test and the win; `fill` leaves only Go. With `howto` up
the probe plays no moves at all (Bridges' Easy board was solved under its
pages and the win screen took over). Hidden Word's type five wrong guesses that keep every clue (so Hard's
rule never refuses them) and then the answer, a letter a step, each commit
waiting while the row before still turns (`_keep` 6).
A board needs a `_moves_<id>` in the probe to play: each move is `{at}`
(a click in board space) or `{do}` (a Callable, for a board played
through its own methods, Code Break's `pick`/`check`); a move waits while
the board is `_busy`, and `fill` holds the clock until the board is full
or done. Untangle's moves are carries (a press, six drags over the
ropes, a release) built at play time from `state.hint_step()`, whose beam
search shows up as a 45-90 ms `hint_step` line on Insane -- the probe's
cost, not a frame of play. On this Mac render CPU
is nearly the whole frame and runs about 70 us per draw call, so draw calls
are the lever; ms readings swing about 1.5 ms run to run.

## The buzz probe (2026-10-03)

`tests/_probe_perf.gd -- <id> d=<0..3> x=buzz` sets `Haptics.trace`, runs
`_buzz_<id>` (one line per thing the player can do, with the kinds that
landed), then plays the board to its win and prints the whole trace under
`haptics:`. A board without a `_buzz_<id>` errors: write one with its
checkup row (`docs/agents/haptics.md`). `tests/_shot_sheets.gd` is stale
(it takes the last child of the menu for the host and finds a Timer).

## Mini Golf's harness (2026-10-05)

`tests/_shot_minigolf.gd` plays the course through the board's real input
path (a press, the pull back, the release) and shoots numbered frames
(`out=<dir>`):

    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_minigolf.gd -- d=0..3 <mode> [rm] [hole=<n>]

Modes: `rest aim putt hint solve out reset restore holes`. `solve` and
`out` play on by themselves: a steady putt (`Sim.best_shot`, a tenth of a
second, on the frame) whenever the ball is at rest, or on `out` a tap of a
putt that wastes a stroke. `tests/_probe_perf.gd -- minigolf` plays the same
steady putts (`to=40` reaches the win on Easy; Hard and Insane want `to=70`),
and `tests/_win.gd -- minigolf` needs the board's `settle_now()` between
putts (a roll is on a clock). `tests/_probe_minigolf_bank.gd` (headless)
re-proves `content/minigolf.json`; `tests/_gf_tut_search.gd` (headless)
prints the tutorial's putts.

## Horse Pen's harness (2026-10-08)

`tests/_shot_horse.gd` plays the board through its real input path (a touch
pressed and let go on a cell) and shoots numbered frames (`out=<dir>`):

    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_horse.gd -- d=0..3 <mode> [rm]

Modes: `rest play refuse notyet hint solve out reset restore`. `play` and
`solve` lay the bank's answer a bale at a time; `out` (Insane) lays and lifts
one bale until the moves are gone. `tests/_probe_perf.gd -- horse` lays the
answer and submits (`x=buzz` walks every knock first), `tests/_win.gd --
horse` wins through the input path with a refused Submit and a hint on the
way, and `tests/_probe_horse_bank.gd` (headless) re-proves
`content/horse.json`. `tools/mine_horse.gd -- <band> <n> <seed> show` prints
meadows as text and `... check` compares the phone's search, the miner's and
one four times as long.
The tutorial: `tests/_probe_perf.gd -- horse d=2 howto shot=2 gap=6 to=40
lang=en` (`/tmp/probe_horse_p<n>.png`). On `d=3` the run ends in a script
error at `_probe_perf.gd:140` once it reaches the shared Moves page, which
has no `_caption` for the probe to print; the seven shots are written first.
