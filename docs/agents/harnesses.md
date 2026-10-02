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

Modes: `rest hold taut plan wrong answer out hint undo reset perf idle enter
restore howto toys`. `plan` plays the dealer's answer (kitten included on
`d=3`, at 2.7 s a move, because she holds input for a second); `out` pokes the
thread to one stitch and makes one bad move; `perf` and `idle` print the mean
frame time and peak draw calls over a window with no screenshots (a
`save_png` costs tens of ms and inflates any reading taken across one).
`tests/_win.gd -- untangle` plays a move a frame and needs the board's
`settle_now()` between drags (its flights and holds are on a clock).

## The performance probe (2026-10-01)

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
their vertices) is Mushroom Patch's. `rm` turns reduce motion on as the
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
and the release (`_keep` the last word's events). Hidden Word's type five wrong guesses that keep every clue (so Hard's
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
