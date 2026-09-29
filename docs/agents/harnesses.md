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
